param(
    [string]$BaseUrl = 'http://127.0.0.1/dev-api',
    [string]$AdminUser = 'admin',
    [string]$AdminPassword = 'admin123',
    [string]$RedisCli = 'D:/redis/Redis-x64-5.0.14.1/redis-cli.exe',
    [string]$MySqlCli = 'D:/MySQL/MySQL Server 8.0/bin/mysql.exe',
    [string]$PortraitPath='',
    [string]$DifferentPortraitPath='',
    [string]$MultiplePortraitPath='',
    [string]$NoFacePath=''
)
$ErrorActionPreference = 'Stop'
# 仅用于本地开发库；创建带随机前缀的隔离数据，finally 中清理。
$prefix = 'fc_' + [Guid]::NewGuid().ToString('N').Substring(0, 10)
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

$fixtureDir=Join-Path (Split-Path -Parent $PSScriptRoot) '.runtime/face-fixtures'
$portrait=if ($PortraitPath) { $PortraitPath } else { Join-Path $fixtureDir 'course-demo-004.png' }
$differentPortrait=if ($DifferentPortraitPath) { $DifferentPortraitPath } else { Join-Path $fixtureDir 'different-face.png' }
$multiplePortrait=if ($MultiplePortraitPath) { $MultiplePortraitPath } else { Join-Path $fixtureDir 'multiple-faces.png' }
$noFace=if ($NoFacePath) { $NoFacePath } else { Join-Path $fixtureDir 'no-face.png' }
if (!(Test-Path -LiteralPath $portrait)) { throw 'Provide a local permitted face image as the portrait fixture.' }
function Multipart([string]$Path,$Fields,[string]$ImagePath,$Headers=$null) {
    if ($null -eq $Headers) { $Headers=$script:adminHeaders }
    Add-Type -AssemblyName System.Net.Http
    $client=New-Object System.Net.Http.HttpClient
    $form=New-Object System.Net.Http.MultipartFormDataContent
    try {
        $client.DefaultRequestHeaders.Add('Authorization',$Headers.Authorization)
        foreach ($key in $Fields.Keys) { $part=New-Object System.Net.Http.StringContent([string]$Fields[$key]); $form.Add($part,[string]$key) }
        if ($ImagePath) {
            $image=New-Object System.Net.Http.ByteArrayContent(,[IO.File]::ReadAllBytes($ImagePath))
            $image.Headers.ContentType=New-Object System.Net.Http.Headers.MediaTypeHeaderValue('image/png')
            $form.Add($image,'image','face.png')
        }
        $r=$client.PostAsync($BaseUrl+$Path,$form).GetAwaiter().GetResult()
        $text=$r.Content.ReadAsStringAsync().GetAwaiter().GetResult()
        return $text | ConvertFrom-Json
    } finally { $form.Dispose(); $client.Dispose() }
}
try {
    $null=Test-Sql 'SELECT 1'
    $adminHeaders=Login $AdminUser $AdminPassword
    $menus=(Api 'Get' '/system/menu/list').data
    $root=$menus | Where-Object { $_.path -eq 'attendance' -and $_.parentId -eq 0 } | Select-Object -First 1
    $faceMenus=@($root.menuId)+@($menus | Where-Object { $_.perms -like 'attendance:face:*' } | ForEach-Object menuId)
    $checkin=$menus | Where-Object perms -eq 'attendance:checkin:submit' | Select-Object -First 1
    Assert-True ($faceMenus.Count -eq 4) 'Face permission migration missing.'
    $managerRole=Add-Role ($prefix+'_manage') $faceMenus
    $employeeRole=Add-Role ($prefix+'_worker') @($root.menuId,$checkin.menuId) '5'
    $deptA=Add-Department ($prefix+'_A'); $deptB=Add-Department ($prefix+'_B')
    $manager=Add-User ($prefix+'_mgr') $deptA @($managerRole)
    $userA=Add-User ($prefix+'_a') $deptA @($employeeRole)
    $userB=Add-User ($prefix+'_b') $deptB @($employeeRole)
    $siteA=Add-Site ($prefix+'_A') $deptA; $siteB=Add-Site ($prefix+'_B') $deptB
    $a=Add-Employee ($prefix+'_a') $userA $siteA.siteId
    $b=Add-Employee ($prefix+'_b') $userB $siteB.siteId
    $hm=Login ($prefix+'_mgr') $password; $ha=Login ($prefix+'_a') $password; $hb=Login ($prefix+'_b') $password
    $status=(Api 'Get' ('/attendance/face/'+$a.employeeId) -Headers $hm).data
    Assert-True ($status.required -and $status.ready -and !$status.enrolled) ('Real engine not ready: '+$status.message)
    Assert-True ((Api 'Get' ('/attendance/face/'+$b.employeeId) -Headers $hm -AllowFailure).code -eq 403) 'Manager read outside department.'
    Assert-True ((Multipart ('/attendance/face/'+$b.employeeId) @{consent='true'} $portrait $hm).code -eq 403) 'Manager enrolled outside department.'
    Assert-True ((Multipart ('/attendance/face/'+$a.employeeId) @{consent='true'} $portrait $ha).code -eq 403) 'Employee self-enrolled without management permission.'
    Assert-True ((Multipart ('/attendance/face/'+$a.employeeId) @{consent='false'} $portrait $hm).code -ne 200) 'Enrollment without consent accepted.'
    $r=Multipart ('/attendance/face/'+$a.employeeId) @{consent='true'} $portrait $hm
    Assert-True ($r.code -eq 200) ('Real enrollment failed: '+$r.msg)
    $status=(Api 'Get' ('/attendance/face/'+$a.employeeId) -Headers $hm).data
    Assert-True ($status.enrolled -and $status.version -eq 1) 'Enrollment metadata missing.'
    foreach ($invalid in @($noFace,$multiplePortrait)) {
        Assert-True ((Multipart ('/attendance/face/'+$a.employeeId) @{consent='true'} $invalid $hm).code -ne 200) 'Invalid enrollment photo accepted.'
    }
    Assert-True ((Api 'Get' ('/attendance/face/'+$a.employeeId) -Headers $hm).data.version -eq 1) 'Failed enrollment changed active template.'
    Assert-True (($status | ConvertTo-Json -Depth 10) -notmatch 'encryptedFeature|featureData|sdkKey|appId') 'Face status leaked feature/credentials.'
    $id=[long]$a.employeeId
    Assert-True (([int](Test-Sql "SELECT length(encrypted_feature)>1032 FROM att_employee_face WHERE employee_id=$id")) -eq 1) 'Feature ciphertext was not stored.'
    $session=Add-Session $siteA.siteId ($prefix+'_face')
    $ticket=(Api 'Post' ('/attendance/session/'+$session.sessionId+'/qrcode')).data.ticket
    Assert-True ((Api 'Post' '/attendance/checkin/submit' @{ticket=$ticket} -Headers $ha -AllowFailure).code -ne 200) 'Plain QR bypassed face requirement.'
    Assert-True ((Multipart '/attendance/checkin/face-submit' @{ticket=('0'*64)} $portrait $ha).code -ne 200) 'Forged ticket accepted.'
    Assert-True ((Multipart '/attendance/checkin/face-submit' @{ticket=$ticket;employeeId=$a.employeeId} $portrait $hb).code -ne 200) 'Another employee used A ticket/binding.'
    Assert-True ((Multipart '/attendance/checkin/face-submit' @{ticket=$ticket} '' $ha).code -ne 200) 'Face check-in accepted missing photo.'
    $mismatch=Multipart '/attendance/checkin/face-submit' @{ticket=$ticket} $differentPortrait $ha
    Assert-True ($mismatch.code -ne 200 -and $mismatch.msg -match '不匹配') 'Different real face was not rejected by comparison.'
    foreach ($invalid in @($noFace,$multiplePortrait)) { Assert-True ((Multipart '/attendance/checkin/face-submit' @{ticket=$ticket} $invalid $ha).code -ne 200) 'No-face/multiple-face check-in accepted.' }
    Assert-True (([int](Test-Sql ('SELECT count(*) FROM att_checkin_record WHERE session_id='+$session.sessionId))) -eq 0) 'Failed verification wrote attendance.'
    $r=Multipart '/attendance/checkin/face-submit' @{ticket=$ticket} $portrait $ha
    Assert-True ($r.code -eq 200 -and !$r.data.repeated) ('Real face check-in failed: '+$r.msg)
    $recordId=[long]$r.data.recordId
    $record=(Api 'Get' ('/attendance/record/'+$recordId)).data
    Assert-True ($record.checkinMethod -eq 'QR_FACE') 'Face verification not marked in raw record.'
    $audit=(Api 'Get' ('/attendance/face/record/'+$recordId)).data
    Assert-True ($audit.score -ge $audit.threshold -and $audit.profileVersion -eq 1 -and $audit.model -eq 'ARCSOFT_3_0') 'Real verification audit missing.'
    Assert-True ((Api 'Get' ('/attendance/face/record/'+$recordId) -Headers $ha -AllowFailure).code -eq 403) 'Employee accessed management audit without permission.'
    $r=Multipart '/attendance/checkin/face-submit' @{ticket=$ticket} $portrait $ha
    Assert-True ($r.code -eq 200 -and $r.data.repeated) 'Repeated face check-in not idempotent.'
    Assert-True (([int](Test-Sql "SELECT count(*) FROM att_face_verification WHERE record_id=$recordId")) -eq 1) 'Duplicate audit created.'
    $null=Api 'Delete' ('/attendance/face/'+$a.employeeId) -Headers $hm
    Assert-True (!(Api 'Get' ('/attendance/face/'+$a.employeeId) -Headers $hm).data.enrolled) 'Revoke retained active feature.'
    $second=Add-Session $siteA.siteId ($prefix+'_missing')
    $ticket2=(Api 'Post' ('/attendance/session/'+$second.sessionId+'/qrcode')).data.ticket
    Assert-True ((Multipart '/attendance/checkin/face-submit' @{ticket=$ticket2} $portrait $ha).code -ne 200) 'Revoked employee continued face check-in.'
    Assert-True (([int](Test-Sql ('SELECT count(*) FROM att_checkin_record WHERE session_id='+$second.sessionId))) -eq 0) 'Failed verification wrote attendance.'
    Assert-True ((Api 'Get' ('/attendance/face/record/'+$recordId)).data.profileVersion -eq 1) 'Revoking erased historical verification.'
    foreach ($module in @('src/components/FaceCapture/index.vue','src/views/attendance/employee/FaceDialog.vue','src/views/attendance/mobile/index.vue')) {
        $compiled=Invoke-WebRequest ('http://127.0.0.1/'+$module) -UseBasicParsing -TimeoutSec 20
        Assert-True ($compiled.StatusCode -eq 200 -and $compiled.Content.Contains('_sfc_main')) ('Vue compilation failed: '+$module)
    }
    Write-Host 'PASS: real ArcSoft enrollment/check-in, encrypted storage, no QR bypass, department permissions, identity binding, audit, idempotency and revoke'
} finally {
    if ($siteIds.Count -gt 0 -and $env:ATTENDANCE_TEST_MYSQL_PASSWORD) {
        $ids=$siteIds -join ','
        try { $null=Test-Sql "DELETE v FROM att_face_verification v JOIN att_checkin_record r ON r.record_id=v.record_id WHERE r.site_id IN ($ids) AND r.employee_no LIKE '$prefix%';" } catch { $cleanupErrors.Add($_.Exception.Message) }
    }
    if ($siteIds.Count -gt 0 -and $env:ATTENDANCE_TEST_MYSQL_PASSWORD) {
        $ids=$siteIds -join ','
        try { $null=Test-Sql "DELETE FROM att_checkin_record WHERE site_id IN ($ids) AND employee_no LIKE '$prefix%'; DELETE FROM att_checkin_session WHERE site_id IN ($ids) AND title LIKE '$prefix%';" } catch { $cleanupErrors.Add($_.Exception.Message) }
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
    else { Write-Host 'PASS: temporary face snapshots and basic-data fixtures cleaned up' }
}
if ($cleanupErrors.Count) { throw 'Face cleanup failed; inspect warnings.' }
Write-Host 'Face verification completed.'
