param(
    [string]$BaseUrl = 'http://127.0.0.1/dev-api',
    [string]$AdminUser = 'admin',
    [string]$AdminPassword = 'admin123',
    [string]$RedisCli = 'D:/redis/Redis-x64-5.0.14.1/redis-cli.exe',
    [string]$MySqlCli = 'D:/MySQL/MySQL Server 8.0/bin/mysql.exe'
)
$ErrorActionPreference = 'Stop'
# 仅用于本地开发库；创建带随机前缀的隔离数据，finally 中清理。
$prefix = 'mo_' + [Guid]::NewGuid().ToString('N').Substring(0, 10)
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
function Add-Role([string]$Key, $Menus, [string]$Scope='3') {
    $null = Api 'Post' '/system/role' @{ roleName=$Key; roleKey=$Key; roleSort=9; dataScope=$Scope; status='0'; menuIds=@($Menus); menuCheckStrictly=$true; deptCheckStrictly=$true }
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

function Metrics($Value, $Expected, [string]$Message) {
    foreach ($key in $Expected.Keys) { Assert-True ($Value.($key) -eq $Expected[$key]) ("${Message}: $key expected $($Expected[$key]), got $($Value.($key))") }
}

$month=([TimeZoneInfo]::ConvertTimeBySystemTimeZoneId([DateTime]::UtcNow,'China Standard Time').AddMonths(-1)).ToString('yyyy-MM')
$days=1..5 | ForEach-Object { $month+'-'+$_.ToString('00') }
function Month($Headers=$null,[string]$Extra='') { return Api 'Get' ("/attendance/monthly/list?month=$month$Extra") -Headers $Headers }
function Seed-Month($Employee,[string]$Day,[string]$Status,[int]$Late=0,[int]$Early=0,[int]$MissingIn=0,[int]$MissingOut=0) {
    $id=[long]$Employee.employeeId
    $minutes=if ($Status -eq 'PENDING' -or $MissingIn -or $MissingOut) { 'NULL' } elseif ($Status -eq 'REST') { '0' } else { '481' }
    $null=Test-Sql "UPDATE att_daily_result SET result_status='$Status',work_day=IF('$Status'='REST',0,1),planned_work_minutes=IF('$Status'='REST',0,480),late_minutes=$Late,early_minutes=$Early,missing_in=$MissingIn,missing_out=$MissingOut,work_minutes=$minutes WHERE employee_id=$id AND attendance_date='$Day' AND employee_no LIKE '$prefix%';"
}
try {
    $null=Test-Sql 'SELECT 1'
    $adminHeaders=Login $AdminUser $AdminPassword
    $menus=(Api 'Get' '/system/menu/list').data
    $root=$menus | Where-Object { $_.path -eq 'attendance' -and $_.parentId -eq 0 } | Select-Object -First 1
    $monthly=$menus | Where-Object perms -eq 'attendance:monthly:list' | Select-Object -First 1
    $checkin=$menus | Where-Object perms -eq 'attendance:checkin:submit' | Select-Object -First 1
    Assert-True ([bool]$monthly.menuId -and [bool]$checkin.menuId) 'Monthly/check-in menus missing.'
    $viewMenus=@($root.menuId,$monthly.menuId)
    $analystRole=Add-Role ($prefix+'_dept') $viewMenus
    $selfRole=Add-Role ($prefix+'_self') @($root.menuId,$monthly.menuId,$checkin.menuId) '5'
    $deptA=Add-Department ($prefix+'_A'); $deptB=Add-Department ($prefix+'_B')
    $analyst=Add-User ($prefix+'_anal') $deptA @($analystRole)
    $userA0=Add-User ($prefix+'_a0') $deptA @($selfRole)
    $userA1=Add-User ($prefix+'_a1') $deptA @()
    $userB=Add-User ($prefix+'_b') $deptB @($analystRole)
    $siteA=Add-Site ($prefix+'_A') $deptA; $siteB=Add-Site ($prefix+'_B') $deptB
    $a0=Add-Employee ($prefix+'_a0') $userA0 $siteA.siteId
    $a1=Add-Employee ($prefix+'_a1') $userA1 $siteA.siteId
    $b=Add-Employee ($prefix+'_b') $userB $siteB.siteId
    $null=Add-Rule (Rule-Body $siteA.siteId ($prefix+'_A')); $null=Add-Rule (Rule-Body $siteB.siteId ($prefix+'_B'))
    foreach ($day in $days) {
        foreach ($site in @($siteA,$siteB)) { $null=Api 'Post' '/attendance/daily/calculate' @{siteId=$site.siteId; attendanceDate=$day} }
        Seed-Month $a1 $day 'NORMAL'; Seed-Month $b $day 'NORMAL'
    }
    Seed-Month $a0 $days[0] 'NORMAL'
    Seed-Month $a0 $days[1] 'ABNORMAL' 10 5
    Seed-Month $a0 $days[2] 'ABNORMAL' 0 0 1 1
    Seed-Month $a0 $days[3] 'PENDING' 9 9 1 0
    Seed-Month $a0 $days[4] 'REST'
    $ha=Login ($prefix+'_anal') $password; $hs=Login ($prefix+'_a0') $password
    $hb=Login ($prefix+'_b') $password; $hn=Login ($prefix+'_a1') $password
    $report=Month $ha
    Assert-True ($report.total -eq 2) 'Department A monthly total incorrect.'
    $row=$report.rows | Where-Object employeeId -eq $a0.employeeId
    Metrics $row @{generatedDays=5; workDays=4; settledDays=3; attendedDays=2; normalDays=1; abnormalDays=2; pendingDays=1; restDays=1; missingDays=1; lateDays=1; earlyDays=1; lateMinutes=10; earlyMinutes=5; plannedWorkMinutes=1920; settledPlannedMinutes=960; workMinutes=962; unknownWorkDays=2} 'Monthly aggregation'
    Assert-True ((Month $ha '&pageNum=1&pageSize=1').rows.Count -eq 1 -and (Month $ha '&pageNum=1&pageSize=1').total -eq 2) 'Grouped pagination incorrect.'
    $firstPage=Month $ha '&pageNum=1&pageSize=1'; $secondPage=Month $ha '&pageNum=2&pageSize=1'
    Assert-True ($secondPage.rows.Count -eq 1 -and $firstPage.rows[0].employeeId -ne $secondPage.rows[0].employeeId) 'Grouped pages repeat employees.'
    Assert-True ((Month $ha ("&siteId="+$siteB.siteId)).total -eq 0) 'Site filter bypassed department scope.'
    Assert-True ((Month $hb).total -eq 1 -and (Month $hs).total -eq 1) 'B/self data scopes incorrect.'
    Assert-True ((Month $ha '&params[dataScope]=%20OR%201=1&userId=1').total -eq 2) 'Forged scope expanded data.'
    Assert-True ((Month $ha '&beginDate=1900-01-01&endDate=2099-01-01').rows[0].generatedDays -eq 5) 'Client date boundaries were trusted.'
    Assert-True ((Api 'Get' '/attendance/monthly/list' -Headers $hn -AllowFailure).code -eq 403) 'Unprivileged monthly access accepted.'
    Assert-True ((Api 'Get' '/attendance/monthly/list' -Headers @{} -AllowFailure).code -eq 401) 'Anonymous monthly access accepted.'
    $own=(Api 'Get' ("/attendance/checkin/monthly?month=$month&userId=$userB&deptId=$deptB&pageNum=1&pageSize=1&params[dataScope]=%20OR%201=1") -Headers $hs).data
    Assert-True ($own.Count -eq 1 -and $own[0].employeeId -eq $a0.employeeId -and $own[0].workMinutes -eq 962) 'Own monthly identity isolation failed.'
    $encoded=$own | ConvertTo-Json -Depth 10
    Assert-True ($encoded -notmatch 'ruleSnapshot|userId|calculatedBy|params') 'Monthly response exposes internal fields.'
    $null=Test-Sql ("UPDATE att_daily_result SET dept_id=$deptB WHERE employee_id="+$a0.employeeId+" AND attendance_date='"+$days[0]+"' AND employee_no LIKE '$prefix%';")
    $scoped=(Month $ha).rows | Where-Object employeeId -eq $a0.employeeId
    Assert-True ($scoped.generatedDays -eq 4) 'Historical snapshot department scope ignored.'
    Assert-True ((Api 'Get' ("/attendance/checkin/monthly?month=$month") -Headers $hs).data[0].generatedDays -eq 5) 'Own history disappeared after snapshot department change.'
    foreach ($value in @('2099-01','2026-13','0999-12','2026-1','oops')) {
        Assert-True ((Api 'Get' ("/attendance/monthly/list?month=$value") -Headers $ha -AllowFailure).code -ne 200) ('Invalid month accepted: '+$value)
    }
    Assert-True ((Api 'Get' ("/attendance/monthly/list?month=$month&siteId=0") -Headers $ha -AllowFailure).code -ne 200) 'Non-positive site filter accepted.'
    $null=Test-Sql "UPDATE sys_user SET status='1' WHERE user_id=$userA0 AND user_name LIKE '$prefix%';"
    Assert-True ((Api 'Get' ("/attendance/checkin/monthly?month=$month") -Headers $hs -AllowFailure).code -ne 200) 'Disabled account retained own monthly access.'
    foreach ($module in @('src/views/attendance/monthly/index.vue','src/views/attendance/mobile/monthly.vue')) {
        $compiled=Invoke-WebRequest ('http://127.0.0.1/'+$module) -UseBasicParsing -TimeoutSec 20
        Assert-True ($compiled.StatusCode -eq 200 -and $compiled.Content.Contains('_sfc_main')) ('Vue compilation failed: '+$module)
    }
    Write-Host 'PASS: monthly aggregation, missing/pending hour isolation, pagination, department/self scopes, forged identity, invalid dates, disabled account and Vue modules'
} finally {
    if ($siteIds.Count -gt 0 -and $env:ATTENDANCE_TEST_MYSQL_PASSWORD) {
        $ids=$siteIds -join ','
        try { $null=Test-Sql "DELETE FROM att_daily_result WHERE site_id IN ($ids) AND employee_no LIKE '$prefix%';" } catch { $cleanupErrors.Add($_.Exception.Message) }
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
    else { Write-Host 'PASS: temporary monthly snapshots and basic-data fixtures cleaned up' }
}
if ($cleanupErrors.Count) { throw 'Monthly cleanup failed; inspect warnings.' }
Write-Host 'Monthly verification completed.'
