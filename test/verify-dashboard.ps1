param(
    [string]$BaseUrl = 'http://127.0.0.1/dev-api',
    [string]$AdminUser = 'admin',
    [string]$AdminPassword = 'admin123',
    [string]$RedisCli = 'D:/redis/Redis-x64-5.0.14.1/redis-cli.exe',
    [string]$MySqlCli = 'D:/MySQL/MySQL Server 8.0/bin/mysql.exe'
)
$ErrorActionPreference = 'Stop'
# 仅用于本地开发库；创建带随机前缀的隔离数据，finally 中清理。
$prefix = 'db_' + [Guid]::NewGuid().ToString('N').Substring(0, 10)
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
function Board($Headers=$null, [string]$Extra='') { return (Api 'Get' "/attendance/dashboard?beginDate=2026-10-19&endDate=2026-10-22$Extra" -Headers $Headers).data }
function Seed($Employee,[string]$Day,[string]$Status,[int]$Late=0,[int]$Early=0,[int]$MissingIn=0,[int]$MissingOut=0) {
    $id=[long]$Employee.employeeId
    $hours=if ($Status -eq 'PENDING' -or $MissingIn -or $MissingOut) { 'NULL' } elseif ($Status -eq 'REST') { '0' } else { '480' }
    $null=Test-Sql "UPDATE att_daily_result SET result_status='$Status',work_day=IF('$Status'='REST',0,1),late_minutes=$Late,early_minutes=$Early,missing_in=$MissingIn,missing_out=$MissingOut,work_minutes=$hours,calculated_time='2026-10-22 12:00:00' WHERE employee_id=$id AND attendance_date='$Day' AND employee_no LIKE '$prefix%';"
}

try {
    $null=Test-Sql 'SELECT 1'
    $adminHeaders=Login $AdminUser $AdminPassword
    Assert-True (((Api 'Get' '/getRouters').data | ConvertTo-Json -Depth 30) -match 'attendance/dashboard/index') 'Dashboard route missing.'
    $menus=(Api 'Get' '/system/menu/list').data
    $boardMenus=@($menus | Where-Object { $_.path -eq 'attendance' -or $_.perms -eq 'attendance:dashboard:view' } | ForEach-Object menuId)
    $analysisMenus=@($menus | Where-Object { $_.path -eq 'attendance' -or $_.perms -in @('attendance:dashboard:view','attendance:daily:list') } | ForEach-Object menuId)
    $boardRole=Add-Role ($prefix+'_board') $boardMenus
    $analysisRole=Add-Role ($prefix+'_anal') $analysisMenus
    $selfRole=Add-Role ($prefix+'_self') $analysisMenus '5'
    $deptA=Add-Department ($prefix+'_A'); $deptB=Add-Department ($prefix+'_B')
    $analyst=Add-User ($prefix+'_anal') $deptA @($analysisRole)
    $viewer=Add-User ($prefix+'_view') $deptA @($boardRole)
    $userA0=Add-User ($prefix+'_a0') $deptA @($selfRole)
    $userA1=Add-User ($prefix+'_a1') $deptA @()
    $userA2=Add-User ($prefix+'_a2') $deptA @()
    $userB=Add-User ($prefix+'_b') $deptB @($boardRole)
    $userCross=Add-User ($prefix+'_cross') $deptA @()
    $siteA=Add-Site ($prefix+'_A') $deptA; $siteB=Add-Site ($prefix+'_B') $deptB
    $a0=Add-Employee ($prefix+'_a0') $userA0 $siteA.siteId
    $a1=Add-Employee ($prefix+'_a1') $userA1 $siteA.siteId
    $a2=Add-Employee ($prefix+'_a2') $userA2 $siteA.siteId
    $b=Add-Employee ($prefix+'_b') $userB $siteB.siteId
    $cross=Add-Employee ($prefix+'_cross') $userCross $siteB.siteId
    $null=Add-Rule (Rule-Body $siteA.siteId ($prefix+'_A'))
    $null=Add-Rule (Rule-Body $siteB.siteId ($prefix+'_B'))
    foreach ($day in @('2026-10-19','2026-10-20','2026-10-21')) {
        foreach ($site in @($siteA,$siteB)) { $null=Api 'Post' '/attendance/daily/calculate' @{ siteId=$site.siteId; attendanceDate=$day } }
    }
    Seed $a0 '2026-10-19' 'NORMAL'; Seed $a1 '2026-10-19' 'ABNORMAL' 10 5; Seed $a2 '2026-10-19' 'ABNORMAL' 0 0 1 1
    Seed $cross '2026-10-19' 'PENDING' 9 0 1 0; Seed $b '2026-10-19' 'NORMAL'
    Seed $a0 '2026-10-20' 'ABNORMAL' 7 0 0 1; Seed $a1 '2026-10-20' 'NORMAL'; Seed $a2 '2026-10-20' 'REST'
    Seed $cross '2026-10-20' 'NORMAL'; Seed $b '2026-10-20' 'ABNORMAL' 0 0 1 0
    Seed $a0 '2026-10-21' 'NORMAL'; Seed $a1 '2026-10-21' 'REST'; Seed $a2 '2026-10-21' 'PENDING'
    Seed $cross '2026-10-21' 'ABNORMAL' 0 5; Seed $b '2026-10-21' 'PENDING'
    $aSiteId=[long]$siteA.siteId; $aEmployeeId=[long]$a2.employeeId
    $null=Test-Sql "UPDATE att_daily_result SET site_name='${prefix}_A_new' WHERE site_id=$aSiteId AND employee_id=$aEmployeeId AND attendance_date='2026-10-21' AND employee_no LIKE '$prefix%';"
    $ha=Login ($prefix+'_anal') $password; $hv=Login ($prefix+'_view') $password; $hb=Login ($prefix+'_b') $password
    $hs=Login ($prefix+'_a0') $password; $hn=Login ($prefix+'_a2') $password
    $view=Board $ha
    Metrics $view.summary @{ totalCount=12; employeeCount=4; settledCount=8; normalCount=4; abnormalCount=4; missingCount=2; pendingCount=2; restCount=2; lateCount=2; earlyCount=2; missingInCount=1; missingOutCount=2 } 'A aggregate'
    Assert-True ($view.summary.lastCalculatedTime -eq '2026-10-22 12:00:00') 'Scoped latest calculation time missing.'
    Assert-True ($view.trend.Count -eq 4 -and $view.trend[3].attendanceDate -eq '2026-10-22' -and $view.trend[3].totalCount -eq 0) 'Missing dates not filled with zero.'
    Metrics $view.trend[0] @{ totalCount=4; normalCount=1; abnormalCount=2; pendingCount=1; restCount=0 } 'Daily trend'
    foreach ($key in @('totalCount','settledCount','normalCount','abnormalCount','missingCount','pendingCount','restCount')) {
        Assert-True (($view.trend | Measure-Object -Property $key -Sum).Sum -eq $view.summary.($key)) ('Trend/summary mismatch: '+$key)
        Assert-True (($view.sites | Measure-Object -Property $key -Sum).Sum -eq $view.summary.($key)) ('Sites/summary mismatch: '+$key)
    }
    Assert-True ($view.sites.Count -eq 2 -and $view.siteOptions.Count -eq 2) 'Cross-management-site employee data hidden or sites split by rename.'
    $aSite=$view.sites | Where-Object siteId -eq $siteA.siteId
    Assert-True ($aSite.siteName -eq ($prefix+'_A_new') -and $aSite.totalCount -eq 9) 'Site snapshot display name or grouping incorrect.'
    Write-Host 'PASS: deduplicated person-days, pending/rest isolation, all aggregates, trend zero-fill and snapshot site grouping'

    $filtered=Board $ha ("&siteId="+$siteB.siteId)
    Metrics $filtered.summary @{ totalCount=3; employeeCount=1; normalCount=1; abnormalCount=1; pendingCount=1; missingCount=0 } 'Scoped B-site filter'
    Assert-True ($filtered.sites.Count -eq 1 -and $filtered.siteOptions.Count -eq 2) 'Site filtering discarded selectable authorized sites.'
    Metrics (Board $hb).summary @{ totalCount=3; employeeCount=1; settledCount=2; normalCount=1; abnormalCount=1; missingCount=1; pendingCount=1 } 'B scope'
    Metrics (Board $hs).summary @{ totalCount=3; employeeCount=1; settledCount=3; normalCount=2; abnormalCount=1; missingCount=1; pendingCount=0; restCount=0 } 'Self scope'
    Metrics (Board $ha '&params[dataScope]= OR 1=1&pageNum=1&pageSize=1').summary @{ totalCount=12; employeeCount=4; abnormalCount=4 } 'Untrusted scope or pagination'
    Metrics (Board $ha '&siteId=9223372036854775806').summary @{ totalCount=0; settledCount=0; missingCount=0 } 'Unknown site'
    Assert-True ((Api 'Get' '/attendance/dashboard' -Headers $hn -AllowFailure).code -eq 403) 'Unprivileged dashboard accepted.'
    Assert-True ((Api 'Get' '/attendance/dashboard' -Headers @{} -AllowFailure).code -eq 401) 'Anonymous dashboard accepted.'
    Metrics (Board $hv).summary @{ totalCount=12 } 'Dashboard-only account'
    Assert-True ((Api 'Get' '/attendance/daily/list' -Headers $hv -AllowFailure).code -eq 403) 'Dashboard-only account gained daily detail access.'
    $viewerRoutes=(Api 'Get' '/getRouters' -Headers $hv).data | ConvertTo-Json -Depth 30
    Assert-True ($viewerRoutes -match 'attendance/dashboard/index' -and $viewerRoutes -notmatch 'attendance/daily/index') 'Dashboard-only menus expanded daily access.'
    Write-Host 'PASS: department/self scopes, scoped site filter/options, forged scope, anonymous and dashboard-only permission isolation'

    foreach ($item in @(@{ filter='resultGroup=SETTLED'; count=8 },@{ filter='resultStatus=NORMAL'; count=4 },@{ filter='resultStatus=ABNORMAL'; count=4 },@{ filter='resultGroup=MISSING'; count=2 },@{ filter='resultStatus=PENDING'; count=2 },@{ filter='resultGroup=SETTLED&abnormalType=LATE'; count=2 },@{ filter='resultGroup=SETTLED&abnormalType=MISSING_IN'; count=1 })) {
        $rows=Api 'Get' ('/attendance/daily/list?beginDate=2026-10-19&endDate=2026-10-22&'+$item.filter) -Headers $ha
        Assert-True ($rows.total -eq $item.count) ('Drill-down count mismatch: '+$item.filter)
    }
    $rows=Api 'Get' ("/attendance/daily/list?beginDate=2026-10-19&endDate=2026-10-22&siteId="+$siteB.siteId+'&resultGroup=SETTLED') -Headers $ha
    Assert-True ($rows.total -eq 2) 'Site drill-down mismatch.'
    foreach ($path in @('/attendance/dashboard?beginDate=2026-10-22&endDate=2026-10-19','/attendance/dashboard?beginDate=2026-10-19','/attendance/dashboard?beginDate=2026-09-01&endDate=2026-10-19','/attendance/dashboard?beginDate=2026-02-30&endDate=2026-03-01','/attendance/dashboard?siteId=0')) {
        Assert-True ((Api 'Get' $path -Headers $ha -AllowFailure).code -ne 200) ('Invalid filter accepted: '+$path)
    }
    $default=(Api 'Get' '/attendance/dashboard' -Headers $ha).data
    Assert-True ($default.trend.Count -eq 7) 'Default period is not seven days.'
    $empty=(Api 'Get' '/attendance/dashboard?beginDate=2026-10-22&endDate=2026-10-22' -Headers $ha).data
    Metrics $empty.summary @{ totalCount=0; missingCount=0; employeeCount=0 } 'Uncalculated day'
    $id=[long]$a0.employeeId
    $null=Test-Sql "UPDATE att_daily_result SET result_status='ABNORMAL',late_minutes=9 WHERE employee_id=$id AND attendance_date='2026-10-21' AND employee_no LIKE '$prefix%';"
    Metrics (Board $ha).summary @{ normalCount=3; abnormalCount=5; lateCount=3 } 'Fresh database aggregation'
    foreach ($module in @('src/views/attendance/dashboard/index.vue','src/views/attendance/dashboard/DashboardChart.vue','src/views/attendance/daily/index.vue')) {
        $compiled=Invoke-WebRequest ('http://127.0.0.1/'+$module) -UseBasicParsing -TimeoutSec 20
        Assert-True ($compiled.StatusCode -eq 200 -and $compiled.Content.Contains('_sfc_main')) ('Vue compilation failed: '+$module)
    }
    Write-Host 'PASS: drill-down totals, date/input validation, default/empty periods, uncached refresh and Vue modules'
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
    else { Write-Host 'PASS: temporary dashboard snapshots and basic-data fixtures cleaned up' }
}
if ($cleanupErrors.Count) { throw 'Dashboard cleanup failed; inspect warnings.' }
Write-Host 'Dashboard verification completed.'
