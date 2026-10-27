param(
    [string]$BaseUrl = 'http://127.0.0.1/dev-api',
    [string]$AdminUser = 'admin',
    [string]$AdminPassword = 'admin123',
    [string]$RedisCli = 'D:/redis/Redis-x64-5.0.14.1/redis-cli.exe',
    [string]$MySqlCli = 'D:/MySQL/MySQL Server 8.0/bin/mysql.exe'
)
$ErrorActionPreference = 'Stop'
# 仅用于本地开发库；创建带随机前缀的隔离数据，finally 中清理。
$prefix = 'au_' + [Guid]::NewGuid().ToString('N').Substring(0, 10)
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
$jobIds=[System.Collections.Generic.List[long]]::new()
function Logs([string]$Name) { return @((Api 'Get' ("/monitor/jobLog/list?jobName=$Name&pageSize=100")).rows | Where-Object jobName -eq $Name) }
function Wait-Log([string]$Name,[long]$After) {
    for ($i=0; $i -lt 60; $i++) {
        $found=Logs $Name | Where-Object jobLogId -gt $After | Sort-Object jobLogId -Descending | Select-Object -First 1
        if ($found) { return $found }
        Start-Sleep -Milliseconds 300
    }
    throw "Quartz log timeout: $Name"
}
function Run-Job($Job) {
    $old=(Logs $Job.jobName | Measure-Object -Property jobLogId -Maximum).Maximum
    $null=Api 'Put' '/monitor/job/run' @{ jobId=$Job.jobId; jobGroup=$Job.jobGroup }
    return Wait-Log $Job.jobName ([long]$old)
}
function Daily([long]$Site,[string]$Date) { return @((Api 'Get' "/attendance/daily/list?siteId=$Site&attendanceDate=$Date&pageSize=100").rows) }
try {
    $null=Test-Sql 'SELECT 1'
    $adminHeaders=Login $AdminUser $AdminPassword
    $template=(Api 'Get' '/monitor/job/list?invokeTarget=attendanceDailyTask.settle').rows
    foreach ($emptyTemplate in @($template | Where-Object invokeTarget -eq "attendanceDailyTask.settle('')")) {
        Assert-True ($emptyTemplate.status -eq '1') 'An unconfigured task template should remain paused.'
    }
    $menus=(Api 'Get' '/system/menu/list').data
    $mobileMenus=@($menus | Where-Object { $_.path -eq 'attendance' -or $_.perms -eq 'attendance:checkin:submit' } | ForEach-Object menuId)
    $role=Add-Role ($prefix+'_mobile') $mobileMenus
    $deptA=Add-Department ($prefix+'_A'); $deptB=Add-Department ($prefix+'_B')
    $userA=Add-User ($prefix+'_a') $deptA @($role); $userB=Add-User ($prefix+'_b') $deptB @($role)
    $userC=Add-User ($prefix+'_none') $deptA @()
    $siteA=Add-Site ($prefix+'_A') $deptA; $siteB=Add-Site ($prefix+'_B') $deptB
    $a=Add-Employee ($prefix+'_a') $userA $siteA.siteId
    $c=Add-Employee ($prefix+'_c') $userC $siteA.siteId
    $b=Add-Employee ($prefix+'_b') $userB $siteB.siteId
    $dayBody=Rule-Body $siteA.siteId ($prefix+'_day'); $dayBody.workDays='1,2,3,4,5,6,7'
    $ruleA=Add-Rule $dayBody
    $nightBody=Rule-Body $siteB.siteId ($prefix+'_night'); $nightBody.workDays='1,2,3,4,5,6,7'; $nightBody.startTime='22:00'; $nightBody.endTime='06:00'; $nightBody.endNextDay='1'; $nightBody.restMinutes=30
    $ruleB=Add-Rule $nightBody
    $zone=[TimeZoneInfo]::FindSystemTimeZoneById('China Standard Time')
    $today=[TimeZoneInfo]::ConvertTimeFromUtc([DateTime]::UtcNow,$zone).Date
    $target=$today.AddDays(-2).ToString('yyyy-MM-dd'); $next=$today.AddDays(-1).ToString('yyyy-MM-dd'); $current=$today.ToString('yyyy-MM-dd')
    Add-Punch $a $siteA "$target 09:00:00"; Add-Punch $a $siteA "$target 18:00:00"
    Add-Punch $b $siteB "$target 22:00:00"; Add-Punch $b $siteB "$next 06:00:00"
    $null=Api 'Post' '/attendance/daily/calculate' @{ siteId=$siteA.siteId; attendanceDate=$target }
    $before=Daily $siteA.siteId $target
    $pending=$before | Where-Object employeeId -eq $a.employeeId
    $finished=$before | Where-Object employeeId -eq $c.employeeId
    $resultId=[long]$pending.resultId
    $null=Test-Sql "UPDATE att_daily_result SET result_status='PENDING' WHERE result_id=$resultId AND employee_no LIKE '$prefix%';"
    # 修改当前规则为夜班，历史待结算仍必须使用09:00的原快照。
    $ruleA.startTime='22:00'; $ruleA.endTime='06:00'; $ruleA.endNextDay='1'; $ruleA.restMinutes=30
    $null=Api 'Put' '/attendance/rule' $ruleA
    $userD=Add-User ($prefix+'_new') $deptA @()
    $d=Add-Employee ($prefix+'_new') $userD $siteA.siteId
    $jobName=$prefix+'_settle'
    $body=@{ jobName=$jobName; jobGroup='DEFAULT'; invokeTarget="attendanceDailyTask.settle('$($siteA.siteId),9223372036854775806')"; cronExpression='0/2 * * * * ?'; misfirePolicy='3'; concurrent='1'; status='1' }
    $null=Api 'Post' '/monitor/job' $body
    $job=(Api 'Get' "/monitor/job/list?jobName=$jobName").rows | Where-Object jobName -eq $jobName
    Assert-True ([bool]$job.jobId -and $job.status -eq '1') 'New task should start paused.'
    $jobIds.Add([long]$job.jobId)
    $first=Run-Job $job
    Assert-True ($first.status -eq '1' -and $first.jobMessage -match '失败1' -and $first.jobMessage -match '结算1') 'Partial failure was not logged with settlement summary.'
    $rows=Daily $siteA.siteId $target
    $after=$rows | Where-Object employeeId -eq $a.employeeId
    $untouched=$rows | Where-Object employeeId -eq $c.employeeId
    $created=$rows | Where-Object employeeId -eq $d.employeeId
    Assert-True ($after.resultStatus -eq 'NORMAL' -and $after.workMinutes -eq 480 -and $after.calculationCount -eq 2 -and $after.calculatedBy -eq 'attendanceDailyTask' -and $after.scheduledStart -eq "$target 09:00:00") 'Pending result used current rule or login context.'
    Assert-True ($untouched.calculationCount -eq $finished.calculationCount -and $untouched.calculatedBy -eq $finished.calculatedBy) 'Settled result was automatically rewritten.'
    Assert-True ($created.ruleVersion -eq 1 -and $created.scheduledEnd -eq "$next 06:00:00" -and $created.calculatedBy -eq 'attendanceDailyTask') 'Missing row not generated from current enabled night rule.'
    Assert-True ((Daily $siteB.siteId $target).Count -eq 0) 'Task processed an unconfigured site.'
    Assert-True ((Daily $siteA.siteId $current).Count -eq 0) 'Open night window generated premature result.'
    $job.invokeTarget="attendanceDailyTask.settle('$($siteA.siteId)')"; $null=Api 'Put' '/monitor/job' $job
    $second=Run-Job $job
    Assert-True ($second.status -eq '0') 'Next execution did not recover after correcting scope.'
    $stable=(Daily $siteA.siteId $target) | Where-Object employeeId -eq $a.employeeId
    Assert-True ($stable.calculationCount -eq 2) 'Repeated task rewrote settled result.'
    Write-Host 'PASS: real Quartz execution, explicit scope, partial failure reporting, snapshot settlement, completed-row protection and idempotency'

    $job.invokeTarget="attendanceDailyTask.settle('*')"; $null=Api 'Put' '/monitor/job' $job
    $invalid=Run-Job $job
    Assert-True ($invalid.status -eq '1' -and $invalid.exceptionInfo -match '正整数') 'Invalid all-sites scope accepted or error cause hidden.'
    $job.invokeTarget="attendanceDailyTask.settle('$($siteB.siteId)')"; $null=Api 'Put' '/monitor/job' $job
    $bLog=Run-Job $job
    Assert-True ($bLog.status -eq '0') 'Configured B site did not execute.'
    $night=(Daily $siteB.siteId $target) | Where-Object employeeId -eq $b.employeeId
    Assert-True ($night.resultStatus -eq 'NORMAL' -and $night.workMinutes -eq 450 -and $night.attendanceDate -eq $target) 'Automatic night hours/date incorrect.'
    $previous=(Logs $job.jobName | Measure-Object -Property jobLogId -Maximum).Maximum
    $null=Api 'Put' '/monitor/job/changeStatus' @{ jobId=$job.jobId; jobGroup=$job.jobGroup; status='0' }
    $scheduled=Wait-Log $job.jobName ([long]$previous)
    Assert-True ($scheduled.status -eq '0') 'Enabled Quartz cron did not trigger successfully.'
    $null=Api 'Put' '/monitor/job/changeStatus' @{ jobId=$job.jobId; jobGroup=$job.jobGroup; status='1' }
    Assert-True (((Api 'Get' "/monitor/job/$($job.jobId)").data.status) -eq '1') 'Pause did not persist.'
    Write-Host 'PASS: invalid-scope refusal, root error logs, cross-day hours, real periodic triggering and pause'

    $ha=Login ($prefix+'_a') $password; $hb=Login ($prefix+'_b') $password; $hc=Login ($prefix+'_none') $password
    $expected=(Api 'Get' "/attendance/daily/list?beginDate=$target&endDate=$current&employeeId=$($a.employeeId)").total
    $mine=Api 'Get' "/attendance/checkin/daily?beginDate=$target&endDate=$current&pageNum=1&pageSize=1&userId=$userB&employeeId=$($b.employeeId)&params[dataScope]= OR 1=1" -Headers $ha
    Assert-True ($mine.total -eq $expected -and $mine.rows.Count -eq 1) 'Own-result pagination or spoofed identity handling failed.'
    foreach ($field in @('userId','employeeId','deptId','ruleConfig','ruleSnapshot','calculatedBy')) { Assert-True (!$mine.rows[0].PSObject.Properties[$field]) ('Employee result exposes '+$field) }
    Assert-True ($mine.rows[0].siteName -eq $siteA.siteName) 'Employee query returned another site identity.'
    $bMine=Api 'Get' "/attendance/checkin/daily?beginDate=$target&endDate=$current" -Headers $hb
    Assert-True ($bMine.total -ge 1 -and @($bMine.rows | Where-Object siteName -ne $siteB.siteName).Count -eq 0) 'Employee B can see A results.'
    Assert-True ((Api 'Get' '/attendance/daily/list' -Headers $ha -AllowFailure).code -eq 403) 'Employee gained manager daily access.'
    Assert-True ((Api 'Get' '/attendance/checkin/daily' -Headers $hc -AllowFailure).code -eq 403) 'No-permission employee access allowed.'
    Assert-True ((Api 'Get' '/attendance/checkin/daily' -Headers @{} -AllowFailure).code -eq 401) 'Anonymous employee result access allowed.'
    Assert-True ((Api 'Get' "/attendance/checkin/daily?beginDate=$current&endDate=$target" -Headers $ha -AllowFailure).code -ne 200) 'Reversed employee dates accepted.'
    Assert-True ((Api 'Get' '/attendance/checkin/daily?beginDate=2026-01-01&endDate=2026-10-01' -Headers $ha -AllowFailure).code -ne 200) 'Unbounded employee range accepted.'
    $null=Api 'Put' '/system/user/changeStatus' @{ userId=$userA; status='1' }
    Assert-True ((Api 'Get' '/attendance/checkin/daily' -Headers $ha -AllowFailure).code -ne 200) 'Cached token bypassed live disabled account check.'
    $null=Api 'Put' '/system/user/changeStatus' @{ userId=$userA; status='0' }
    $module=Invoke-WebRequest 'http://127.0.0.1/src/views/attendance/mobile/daily.vue' -UseBasicParsing -TimeoutSec 20
    Assert-True ($module.StatusCode -eq 200 -and $module.Content.Contains('_sfc_main')) 'H5 daily page did not compile.'
    Write-Host 'PASS: mobile-only role, own-result isolation, pagination, minimal fields, live account checks and H5 module compilation'
} finally {
    foreach ($id in $jobIds) {
        try { $null=Api 'Put' '/monitor/job/changeStatus' @{ jobId=$id; jobGroup='DEFAULT'; status='1' }; $null=Api 'Delete' "/monitor/job/$id" } catch { $cleanupErrors.Add($_.Exception.Message) }
    }
    if ($jobIds.Count) { Start-Sleep -Milliseconds 1000 }
    if ($siteIds.Count -gt 0 -and $env:ATTENDANCE_TEST_MYSQL_PASSWORD) {
        $ids=$siteIds -join ','
        try { $null=Test-Sql "DELETE FROM att_daily_result WHERE site_id IN ($ids) AND employee_no LIKE '$prefix%'; DELETE FROM sys_job_log WHERE job_name LIKE '$prefix%';" } catch { $cleanupErrors.Add($_.Exception.Message) }
    }
    if ($checkinSessionIds.Count -gt 0 -and $env:ATTENDANCE_TEST_MYSQL_PASSWORD) {
        $ids=$checkinSessionIds -join ','
        try { $null=Test-Sql "START TRANSACTION; DELETE FROM att_checkin_record WHERE session_id IN ($ids) AND employee_no LIKE '$prefix%'; DELETE FROM att_checkin_session WHERE session_id IN ($ids) AND title LIKE '$prefix%'; COMMIT;" } catch { $cleanupErrors.Add($_.Exception.Message) }
    }
    foreach ($headers in $sessions) {
        if ($adminHeaders -and $headers.Authorization -eq $adminHeaders.Authorization) { continue }
        try { $null=Api 'Post' '/logout' -Headers $headers } catch { $cleanupErrors.Add($_.Exception.Message) }
    }
    foreach ($entry in @(@{ path='/attendance/rule/'; ids=$ruleIds },@{ path='/attendance/employee/'; ids=$employeeIds },@{ path='/attendance/site/'; ids=$siteIds },@{ path='/system/user/'; ids=$userIds },@{ path='/system/dept/'; ids=$departmentIds },@{ path='/system/role/'; ids=$roleIds })) {
        foreach ($id in $entry.ids) { try { $null=Api 'Delete' ($entry.path+$id) } catch { $cleanupErrors.Add($_.Exception.Message) } }
    }
    if ($adminHeaders) { try { $null=Api 'Post' '/logout' } catch { $cleanupErrors.Add($_.Exception.Message) } }
    if ($cleanupErrors.Count) { Write-Warning ("Cleanup requires attention ($prefix): "+($cleanupErrors -join '; ')) }
    else { Write-Host 'PASS: temporary task, task logs, daily results, records and base fixtures cleaned up' }
}
if ($cleanupErrors.Count) { throw 'Automatic-settlement cleanup failed; inspect warnings.' }
Write-Host 'Automatic settlement verification completed.'
