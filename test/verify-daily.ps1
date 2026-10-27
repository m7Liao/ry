param(
    [string]$BaseUrl = 'http://127.0.0.1/dev-api',
    [string]$AdminUser = 'admin',
    [string]$AdminPassword = 'admin123',
    [string]$RedisCli = 'D:/redis/Redis-x64-5.0.14.1/redis-cli.exe',
    [string]$MySqlCli = 'D:/MySQL/MySQL Server 8.0/bin/mysql.exe'
)
$ErrorActionPreference = 'Stop'
# 仅用于本地开发库；创建带随机前缀的隔离数据，finally 中清理。
$prefix = 'dy_' + [Guid]::NewGuid().ToString('N').Substring(0, 10)
$password = 'Test_' + [Guid]::NewGuid().ToString('N').Substring(0, 10)
$employeeIds = [System.Collections.Generic.List[long]]::new()
$siteIds = [System.Collections.Generic.List[long]]::new()
$userIds = [System.Collections.Generic.List[long]]::new()
$departmentIds = [System.Collections.Generic.List[long]]::new()
$roleIds = [System.Collections.Generic.List[long]]::new()
$sessions = [System.Collections.Generic.List[hashtable]]::new()
$adminHeaders = $null
$cleanupErrors = [System.Collections.Generic.List[string]]::new()

function Assert-True($Condition, [string]$Message) { if (!$Condition) { throw $Message } }
function Api([string]$Method, [string]$Path, $Body = $null, $Headers = $null, [switch]$AllowFailure) {
    if ($null -eq $Headers) { $Headers = $script:adminHeaders }
    $argsMap = @{ Uri = "$BaseUrl$Path"; Method = $Method; Headers = $Headers; TimeoutSec = 30 }
    if ($null -ne $Body) {
        $argsMap.ContentType = 'application/json; charset=utf-8'
        $argsMap.Body = [Text.Encoding]::UTF8.GetBytes(($Body | ConvertTo-Json -Depth 20 -Compress))
    }
    $response = Invoke-WebRequest @argsMap -UseBasicParsing
    $result = [Text.Encoding]::UTF8.GetString($response.RawContentStream.ToArray()) | ConvertFrom-Json
    if (!$AllowFailure -and $result.code -ne 200) { throw "$Method $Path failed: $($result.code) $($result.msg)" }
    return $result
}
function Login([string]$Username, [string]$Password) {
    $captcha = Invoke-RestMethod "$BaseUrl/captchaImage" -TimeoutSec 15
    $json = & $RedisCli --raw GET ('captcha_codes:' + $captcha.uuid)
    if ($LASTEXITCODE -ne 0 -or !$json) { throw 'Cannot read local test captcha.' }
    $code = $json | ConvertFrom-Json
    try { $result = Api 'Post' '/login' @{ username=$Username; password=$Password; code=[string]$code; uuid=$captcha.uuid } }
    catch { throw "Test login failed for '$Username': $($_.Exception.Message)" }
    Assert-True ([bool]$result.token) 'Login returned no token.'
    $headers = @{ Authorization = 'Bearer ' + $result.token }
    $script:sessions.Add($headers)
    return $headers
}
function Copy-Body($Value) { return ($Value | ConvertTo-Json -Depth 15 | ConvertFrom-Json) }
function Add-Department([string]$Name) {
    $null = Api 'Post' '/system/dept' @{ parentId=100; deptName=$Name; orderNum=1; status='0' }
    $dept = (Api 'Get' '/system/dept/list').data | Where-Object deptName -eq $Name
    Assert-True ([bool]$dept.deptId) 'Cannot find created department.'
    $script:departmentIds.Add([long]$dept.deptId)
    return [long]$dept.deptId
}
function Add-Role([string]$Key, $Menus) {
    $null = Api 'Post' '/system/role' @{ roleName=$Key; roleKey=$Key; roleSort=9; dataScope='3'; status='0'; menuIds=@($Menus); menuCheckStrictly=$true; deptCheckStrictly=$true }
    $role = (Api 'Get' "/system/role/list?roleKey=$Key").rows | Where-Object roleKey -eq $Key
    Assert-True ([bool]$role.roleId) 'Cannot find created role.'
    $script:roleIds.Add([long]$role.roleId)
    return [long]$role.roleId
}
function Add-User([string]$Name, [long]$Department, $Roles) {
    $null = Api 'Post' '/system/user' @{ userName=$Name; nickName=$Name; password=$script:password; deptId=$Department; status='0'; sex='2'; roleIds=@($Roles); postIds=@() }
    $user = (Api 'Get' "/system/user/list?userName=$Name").rows | Where-Object userName -eq $Name
    Assert-True ([bool]$user.userId) 'Cannot find created user.'
    $script:userIds.Add([long]$user.userId)
    return [long]$user.userId
}
function Add-Site([string]$Code, [long]$Department) {
    $body = @{ siteCode=$Code; siteName=$Code; deptId=$Department; address='Integration test address'; longitude=116.397; latitude=39.908; coordinateSystem='GCJ02'; status='0' }
    $null = Api 'Post' '/attendance/site' $body
    $site = (Api 'Get' "/attendance/site/list?siteCode=$Code").rows | Where-Object siteCode -eq $Code
    Assert-True ([bool]$site.siteId) 'Cannot find created site.'
    $script:siteIds.Add([long]$site.siteId)
    return $site
}
function Add-Employee([string]$Number, [long]$User, [long]$Site) {
    $null = Api 'Post' '/attendance/employee' @{ employeeNo=$Number; employeeName=$Number; userId=$User; siteId=$Site; hireDate='2020-01-01'; status='0' }
    $employee = (Api 'Get' "/attendance/employee/list?employeeNo=$Number").rows | Where-Object employeeNo -eq $Number
    Assert-True ([bool]$employee.employeeId) 'Cannot find created employee.'
    $script:employeeIds.Add([long]$employee.employeeId)
    return $employee
}

$checkinSessionIds = [System.Collections.Generic.List[long]]::new()
function Test-Sql([string]$Sql) {
    if (!$env:ATTENDANCE_TEST_MYSQL_PASSWORD) { throw 'Set ATTENDANCE_TEST_MYSQL_PASSWORD for the local test database.' }
    $previousPassword = $env:MYSQL_PWD
    try {
        $env:MYSQL_PWD = $env:ATTENDANCE_TEST_MYSQL_PASSWORD
        $output = & $MySqlCli --protocol=TCP --host=127.0.0.1 --user=root --default-character-set=utf8mb4 '--database=ry-vue' --connect-timeout=5 -N -e $Sql
        if ($LASTEXITCODE -ne 0) { throw 'Local test SQL failed.' }
        return $output
    } finally {
        if ($null -eq $previousPassword) { Remove-Item Env:MYSQL_PWD -ErrorAction SilentlyContinue } else { $env:MYSQL_PWD = $previousPassword }
    }
}
function Add-Session([long]$Site, [string]$Title, $Headers=$null) {
    $r = Api 'Post' '/attendance/session' @{ siteId=$Site; title=$Title; durationMinutes=30 } -Headers $Headers
    $script:checkinSessionIds.Add([long]$r.data.sessionId)
    return $r.data
}
$ruleIds = [System.Collections.Generic.List[long]]::new()
function Rule-Body([long]$Site, [string]$Name) {
    return @{ siteId=$Site; ruleName=$Name; workDays='5,3,1,2,4'; startTime='09:00'; endTime='18:00'; endNextDay='0'; lateGraceMinutes=5; earlyGraceMinutes=0; startBeforeMinutes=60; startAfterMinutes=60; endBeforeMinutes=60; endAfterMinutes=120; restMinutes=60; status='0'; remark='' }
}
function Add-Rule($Body, $Headers=$null) {
    $null=Api 'Post' '/attendance/rule' $Body -Headers $Headers
    $rule=(Api 'Get' ("/attendance/rule/list?siteId="+$Body.siteId)).rows | Select-Object -First 1
    Assert-True ([bool]$rule.ruleId) 'Created rule was not returned.'
    $script:ruleIds.Add([long]$rule.ruleId)
    return $rule
}

function Add-Punch($Employee, $Site, [string]$Time) {
    $session=Add-Session $Site.siteId ($prefix+'_p'+$checkinSessionIds.Count)
    $employeeId=[long]$Employee.employeeId; $siteId=[long]$Site.siteId; $sessionId=[long]$session.sessionId
    $null=Test-Sql "INSERT INTO att_checkin_record(session_id,employee_id,user_id,dept_id,site_id,employee_no,employee_name,user_name,dept_name,site_name,session_title,checkin_time,checkin_method) SELECT $sessionId,e.employee_id,e.user_id,u.dept_id,$siteId,e.employee_no,e.employee_name,u.user_name,d.dept_name,s.site_name,c.title,'$Time','QR' FROM att_employee e JOIN sys_user u ON u.user_id=e.user_id JOIN sys_dept d ON d.dept_id=u.dept_id JOIN att_site s ON s.site_id=$siteId JOIN att_checkin_session c ON c.session_id=$sessionId WHERE e.employee_id=$employeeId AND e.employee_no LIKE '$prefix%';"
}
function Results([long]$Site, [string]$Date, $Headers=$null) { return @( (Api 'Get' "/attendance/daily/list?siteId=$Site&attendanceDate=$Date&pageSize=1000" -Headers $Headers).rows ) }
function Concurrent-Calculate($Body, $Headers) {
    Add-Type -AssemblyName System.Net.Http
    $client=[Net.Http.HttpClient]::new(); $requests=@(); $tasks=@()
    try {
        foreach ($i in 1..2) {
            $r=[Net.Http.HttpRequestMessage]::new([Net.Http.HttpMethod]::Post,"$BaseUrl/attendance/daily/calculate")
            $null=$r.Headers.TryAddWithoutValidation('Authorization',$Headers.Authorization)
            $r.Content=[Net.Http.StringContent]::new(($Body | ConvertTo-Json -Compress),[Text.Encoding]::UTF8,'application/json')
            $requests+=$r; $tasks+=$client.SendAsync($r)
        }
        [Threading.Tasks.Task]::WaitAll([Threading.Tasks.Task[]]$tasks)
        foreach ($t in $tasks) { $t.Result.Content.ReadAsStringAsync().GetAwaiter().GetResult() | ConvertFrom-Json }
    } finally { foreach ($r in $requests) { $r.Dispose() }; $client.Dispose() }
}

try {
    $null=Test-Sql 'SELECT 1'
    $adminHeaders=Login $AdminUser $AdminPassword
    Assert-True (((Api 'Get' '/getRouters').data | ConvertTo-Json -Depth 30) -match 'attendance/daily/index') 'Daily menu missing.'
    $menus=(Api 'Get' '/system/menu/list').data
    $dailyMenus=@($menus | Where-Object { $_.path -eq 'attendance' -or $_.perms -like 'attendance:daily:*' } | ForEach-Object menuId)
    $readMenus=@($menus | Where-Object { $_.path -eq 'attendance' -or $_.perms -in @('attendance:daily:list','attendance:daily:query') } | ForEach-Object menuId)
    $role=Add-Role ($prefix+'_full') $dailyMenus; $readRole=Add-Role ($prefix+'_read') $readMenus
    $deptA=Add-Department ($prefix+'_A'); $deptB=Add-Department ($prefix+'_B')
    $managerUser=Add-User ($prefix+'_mgr') $deptA @($role)
    $readerUser=Add-User ($prefix+'_reader') $deptB @($readRole)
    $noneUser=Add-User ($prefix+'_noauth') $deptA @()
    $siteA=Add-Site ($prefix+'_A') $deptA; $siteB=Add-Site ($prefix+'_B') $deptB; $siteC=Add-Site ($prefix+'_C') $deptA
    $people=@{}
    foreach ($key in @('normal','late','inonly','empty','wrong','hired','left')) {
        $user=Add-User ($prefix+'_'+$key) $deptA @()
        $people[$key]=Add-Employee ($prefix+'_'+$key) $user $siteA.siteId
    }
    $people['night']=Add-Employee ($prefix+'_night') $readerUser $siteB.siteId
    $crossUser=Add-User ($prefix+'_cross') $deptB @()
    $people['cross']=Add-Employee ($prefix+'_cross') $crossUser $siteA.siteId
    $people['hired'].hireDate='2026-10-20'; $null=Api 'Put' '/attendance/employee' $people['hired']
    $people['left'].status='1'; $people['left'].leaveDate='2026-10-18'; $null=Api 'Put' '/attendance/employee' $people['left']
    $dayBody=Rule-Body $siteA.siteId ($prefix+'_day'); $dayBody.earlyGraceMinutes=5
    $dayRule=Add-Rule $dayBody
    $nightBody=Rule-Body $siteB.siteId ($prefix+'_night'); $nightBody.startTime='22:00'; $nightBody.endTime='06:00'; $nightBody.endNextDay='1'; $nightBody.restMinutes=30; $nightBody.workDays='1,2,3,4,5,6,7'
    $nightRule=Add-Rule $nightBody
    $manager=Login ($prefix+'_mgr') $password; $reader=Login ($prefix+'_reader') $password; $noAuth=Login ($prefix+'_noauth') $password
    Add-Punch $people['normal'] $siteA '2026-10-19 08:59:00'
    Add-Punch $people['normal'] $siteA '2026-10-19 09:10:00'
    Add-Punch $people['normal'] $siteA '2026-10-19 17:50:00'
    Add-Punch $people['normal'] $siteA '2026-10-19 18:10:00'
    Add-Punch $people['late'] $siteA '2026-10-19 09:06:00'
    Add-Punch $people['late'] $siteA '2026-10-19 17:54:00'
    Add-Punch $people['inonly'] $siteA '2026-10-19 09:00:00'
    Add-Punch $people['wrong'] $siteB '2026-10-19 09:00:00'
    Add-Punch $people['wrong'] $siteB '2026-10-19 18:00:00'
    Add-Punch $people['night'] $siteB '2026-10-19 22:10:00'
    Add-Punch $people['night'] $siteB '2026-10-20 05:58:00'
    $body=@{ siteId=$siteA.siteId; attendanceDate='2026-10-19' }
    $first=Api 'Post' '/attendance/daily/calculate' $body -Headers $manager
    Assert-True ($first.data.created -eq 5 -and $first.data.candidates -eq 5) 'Scoped eligible roster includes wrong department or employment dates.'
    $rows=Results $siteA.siteId '2026-10-19' $manager
    $normal=$rows | Where-Object employeeId -eq $people['normal'].employeeId
    $late=$rows | Where-Object employeeId -eq $people['late'].employeeId
    $empty=$rows | Where-Object employeeId -eq $people['empty'].employeeId
    $single=$rows | Where-Object employeeId -eq $people['inonly'].employeeId
    $wrong=$rows | Where-Object employeeId -eq $people['wrong'].employeeId
    Assert-True ($normal.resultStatus -eq 'NORMAL' -and $normal.workMinutes -eq 491 -and $normal.inTime -eq '2026-10-19 08:59:00' -and $normal.outTime -eq '2026-10-19 18:10:00') 'Earliest/latest or work minutes incorrect.'
    Assert-True ($late.resultStatus -eq 'ABNORMAL' -and $late.lateMinutes -eq 6 -and $late.earlyMinutes -eq 6 -and $late.workMinutes -eq 468) 'Late/early minutes incorrect.'
    Assert-True ($empty.missingIn -and $empty.missingOut -and $null -eq $empty.workMinutes) 'Double missing or unknown hours incorrect.'
    Assert-True (!$single.missingIn -and $single.missingOut -and $null -eq $single.workMinutes) 'Single missing hours incorrect.'
    Assert-True ($wrong.missingIn -and $wrong.missingOut) 'Wrong-site punches used.'
    $again=Api 'Post' '/attendance/daily/calculate' $body -Headers $manager
    Assert-True ($again.data.created -eq 0 -and $again.data.skipped -eq 5) 'Repeat initial calculation overwrote results.'
    Write-Host 'PASS: scoped roster, employment dates, first/last matching, late/early, missing, wrong-site filtering and repeat calculation'

    $null=Api 'Post' '/attendance/daily/calculate' @{ siteId=$siteB.siteId; attendanceDate='2026-10-19' }
    $night=(Results $siteB.siteId '2026-10-19')[0]
    Assert-True ($night.attendanceDate -eq '2026-10-19' -and $night.scheduledEnd -eq '2026-10-20 06:00:00' -and $night.workMinutes -eq 438 -and $night.lateMinutes -eq 10 -and $night.earlyMinutes -eq 2) 'Overnight result incorrect.'
    $null=Api 'Post' '/attendance/daily/calculate' @{ siteId=$siteA.siteId; attendanceDate='2026-10-18' } -Headers $manager
    $rest=(Results $siteA.siteId '2026-10-18' $manager)[0]
    Assert-True ($rest.resultStatus -eq 'REST' -and $rest.workMinutes -eq 0 -and !$rest.missingIn -and !$rest.missingOut) 'Nonworking day incorrectly marked missing.'
    $zone=[TimeZoneInfo]::FindSystemTimeZoneById('China Standard Time')
    $today=[TimeZoneInfo]::ConvertTimeFromUtc([DateTime]::UtcNow,$zone).ToString('yyyy-MM-dd')
    $null=Api 'Post' '/attendance/daily/calculate' @{ siteId=$siteB.siteId; attendanceDate=$today }
    $pending=(Results $siteB.siteId $today)[0]
    Assert-True ($pending.resultStatus -eq 'PENDING' -and !$pending.missingOut -and $null -eq $pending.workMinutes) 'Open overnight window prematurely settled.'
    Write-Host 'PASS: overnight attribution, rest days, open windows and pending hours'

    $page=Api 'Get' "/attendance/daily/list?siteId=$($siteA.siteId)&beginDate=2026-10-19&endDate=2026-10-19&pageNum=1&pageSize=1&params[dataScope]= OR 1=1" -Headers $manager
    Assert-True ($page.total -eq 5 -and $page.rows.Count -eq 1) 'Date filtering, pagination or scope-input isolation failed.'
    Assert-True ((Api 'Get' "/attendance/daily/list?siteId=$($siteA.siteId)&attendanceDate=2026-10-19&abnormalType=LATE" -Headers $manager).total -eq 1) 'Abnormal filter incorrect.'
    Assert-True ((Api 'Get' "/attendance/daily/$($night.resultId)" -Headers $manager -AllowFailure).code -eq 403) 'Cross-department detail allowed.'
    Assert-True ((Api 'Post' '/attendance/daily/recalculate' @{ resultIds=@($normal.resultId,$night.resultId) } -Headers $manager -AllowFailure).code -eq 403) 'Cross-department batch recalculate allowed.'
    Assert-True (((Api 'Get' "/attendance/daily/$($normal.resultId)").data.calculationCount) -eq 1) 'Failed batch did not roll back earlier update.'
    Assert-True ((Api 'Post' '/attendance/daily/calculate' @{ siteId=$siteB.siteId; attendanceDate='2026-10-19' } -Headers $manager -AllowFailure).code -eq 403) 'Cross-department calculate allowed.'
    Assert-True ((Api 'Post' '/attendance/daily/recalculate' @{ resultIds=@($night.resultId) } -Headers $reader -AllowFailure).code -eq 403) 'Read-only recalculation allowed.'
    Assert-True ((Api 'Get' '/attendance/daily/list' -Headers $noAuth -AllowFailure).code -eq 403) 'Unprivileged list allowed.'
    Assert-True ((Api 'Get' '/attendance/daily/list' -Headers @{} -AllowFailure).code -eq 401) 'Anonymous list allowed.'
    Assert-True ((Api 'Post' '/attendance/daily/calculate' @{ siteId=$siteC.siteId; attendanceDate='2026-10-19' } -AllowFailure).code -ne 200) 'Missing rule accepted.'
    $tomorrow=[TimeZoneInfo]::ConvertTimeFromUtc([DateTime]::UtcNow,$zone).AddDays(1).ToString('yyyy-MM-dd')
    Assert-True ((Api 'Post' '/attendance/daily/calculate' @{ siteId=$siteA.siteId; attendanceDate=$tomorrow } -AllowFailure).code -ne 200) 'Future date accepted.'
    Assert-True ((Api 'Get' '/attendance/daily/list?beginDate=2026-10-20&endDate=2026-10-19' -AllowFailure).code -ne 200) 'Reversed dates accepted.'
    Assert-True ((Api 'Post' '/attendance/daily/recalculate' @{ resultIds=@() } -AllowFailure).code -ne 200) 'Empty batch accepted.'
    $responses=@(Concurrent-Calculate @{ siteId=$siteA.siteId; attendanceDate='2026-10-20' } $manager)
    Assert-True (@($responses | Where-Object code -eq 200).Count -eq 2) 'Concurrent initial calculation failed.'
    Assert-True (($responses | ForEach-Object { $_.data.created } | Measure-Object -Sum).Sum -eq 6) 'Concurrent initial calculation duplicated or lost results.'
    Write-Host 'PASS: queries, RBAC, direct-ID scope, batch rollback, validation and concurrent initial idempotency'

    $detail=(Api 'Get' "/attendance/daily/$($normal.resultId)").data
    Assert-True ($detail.ruleConfig.algorithm -eq 'FIXED_V1' -and $detail.ruleConfig.startTime -eq '09:00' -and !$detail.PSObject.Properties['ruleSnapshot']) 'Snapshot return fields incorrect.'
    $dayRule.startTime='08:30'; $dayRule.restMinutes=30; $dayRule.ruleName=$prefix+'_changed'; $dayRule.status='1'
    $null=Api 'Put' '/attendance/rule' $dayRule
    $people['normal'].employeeName=$prefix+'_renamed'; $null=Api 'Put' '/attendance/employee' $people['normal']
    $siteA.siteName=$prefix+'_renamedsite'; $null=Api 'Put' '/attendance/site' $siteA
    $null=Api 'Post' '/attendance/daily/recalculate' @{ resultIds=@($normal.resultId) } -Headers $manager
    $after=(Api 'Get' "/attendance/daily/$($normal.resultId)").data
    Assert-True ($after.ruleConfig.startTime -eq '09:00' -and $after.ruleConfig.restMinutes -eq 60 -and $after.ruleVersion -eq 0 -and $after.workMinutes -eq 491 -and $after.employeeName -eq $normal.employeeName -and $after.siteName -eq $normal.siteName -and $after.calculationCount -eq 2) 'Recalculation used live config or changed immutable identity snapshot.'
    Assert-True ((Api 'Delete' "/attendance/rule/$($dayRule.ruleId)" -AllowFailure).code -ne 200) 'Historical rule deletion allowed.'
    Assert-True ((Api 'Delete' "/attendance/employee/$($people['empty'].employeeId)" -AllowFailure).code -ne 200) 'Employee with result but no punches can be deleted.'
    $newRule=Add-Rule (Rule-Body $siteC.siteId ($prefix+'_newsite'))
    $people['empty'].siteId=$siteC.siteId; $null=Api 'Put' '/attendance/employee' $people['empty']
    $moved=Api 'Post' '/attendance/daily/calculate' @{ siteId=$siteC.siteId; attendanceDate='2026-10-19' }
    Assert-True ($moved.data.created -eq 0 -and $moved.data.skipped -eq 1) 'Rebinding duplicated or moved historical daily result.'
    # 把次日规则改成早班，前一夜班已占用的05:58记录不能再次当作早班上班卡。
    $nightRule.startTime='06:00'; $nightRule.endTime='14:00'; $nightRule.endNextDay='0'
    $null=Api 'Put' '/attendance/rule' $nightRule
    $null=Api 'Post' '/attendance/daily/calculate' @{ siteId=$siteB.siteId; attendanceDate='2026-10-20' }
    $nextDay=(Results $siteB.siteId '2026-10-20')[0]
    Assert-True ($nextDay.missingIn -and $null -eq $nextDay.inRecordId) 'A punch was reused by a second attendance date after rule change.'
    $null=Api 'Post' '/attendance/daily/recalculate' @{ resultIds=@($night.resultId) }
    Assert-True (((Api 'Get' "/attendance/daily/$($night.resultId)").data.outRecordId) -eq $night.outRecordId) 'Original night result lost its own allocated punch during recalculate.'
    $module=Invoke-WebRequest 'http://127.0.0.1/src/views/attendance/daily/index.vue' -UseBasicParsing -TimeoutSec 20
    Assert-True ($module.StatusCode -eq 200 -and $module.Content.Contains('_sfc_main')) 'Daily Vue page did not compile.'
    Write-Host 'PASS: immutable snapshots, disabled-rule recalculation, historical guards, rebinding, cross-date punch allocation and Vue compilation'
} finally {
    if ($siteIds.Count -gt 0 -and $env:ATTENDANCE_TEST_MYSQL_PASSWORD) {
        $ids=$siteIds -join ','
        try { $null=Test-Sql "DELETE FROM att_daily_result WHERE site_id IN ($ids) AND employee_no LIKE '$prefix%';" } catch { $cleanupErrors.Add($_.Exception.Message) }
    }
    if ($checkinSessionIds.Count -gt 0 -and $env:ATTENDANCE_TEST_MYSQL_PASSWORD) {
        $ids=$checkinSessionIds -join ','
        try { $null=Test-Sql "START TRANSACTION; DELETE FROM att_checkin_record WHERE session_id IN ($ids) AND employee_no LIKE '$prefix%'; DELETE FROM att_checkin_session WHERE session_id IN ($ids) AND title LIKE '$prefix%'; COMMIT;" } catch { $cleanupErrors.Add($_.Exception.Message) }
    }
    foreach ($headers in $sessions) {
        if ($adminHeaders -and $headers.Authorization -eq $adminHeaders.Authorization) { continue }
        try { $null=Api 'Post' '/logout' -Headers $headers } catch { $cleanupErrors.Add($_.Exception.Message) }
    }
    foreach ($entry in @(
        @{ path='/attendance/rule/'; ids=$ruleIds },
        @{ path='/attendance/employee/'; ids=$employeeIds },
        @{ path='/attendance/site/'; ids=$siteIds },
        @{ path='/system/user/'; ids=$userIds },
        @{ path='/system/dept/'; ids=$departmentIds },
        @{ path='/system/role/'; ids=$roleIds }
    )) { foreach ($id in $entry.ids) { try { $null=Api 'Delete' ($entry.path+$id) } catch { $cleanupErrors.Add($_.Exception.Message) } } }
    if ($adminHeaders) { try { $null=Api 'Post' '/logout' } catch { $cleanupErrors.Add($_.Exception.Message) } }
    if ($cleanupErrors.Count) { Write-Warning ("Cleanup requires attention ($prefix): "+($cleanupErrors -join '; ')) }
    else { Write-Host 'PASS: temporary daily, record, session and basic-data fixtures cleaned up' }
}
if ($cleanupErrors.Count) { throw 'Daily cleanup failed; inspect warnings.' }
Write-Host 'Daily verification completed.'
