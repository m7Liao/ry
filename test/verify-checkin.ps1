param(
    [string]$BaseUrl = 'http://127.0.0.1/dev-api',
    [string]$AdminUser = 'admin',
    [string]$AdminPassword = 'admin123',
    [string]$RedisCli = 'D:/redis/Redis-x64-5.0.14.1/redis-cli.exe',
    [string]$MySqlCli = 'D:/MySQL/MySQL Server 8.0/bin/mysql.exe'
)
$ErrorActionPreference = 'Stop'
# 仅用于本地开发库；创建带随机前缀的隔离数据，finally 中清理。
$prefix = 'ck_' + [Guid]::NewGuid().ToString('N').Substring(0, 10)
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
    $result = Invoke-RestMethod @argsMap
    if (!$AllowFailure -and $result.code -ne 200) { throw "$Method $Path failed: $($result.code) $($result.msg)" }
    return $result
}
function Login([string]$Username, [string]$Password) {
    $captcha = Invoke-RestMethod "$BaseUrl/captchaImage" -TimeoutSec 15
    $json = & $RedisCli --raw GET ('captcha_codes:' + $captcha.uuid)
    if ($LASTEXITCODE -ne 0 -or !$json) { throw 'Cannot read local test captcha.' }
    $code = $json | ConvertFrom-Json
    $result = Api 'Post' '/login' @{ username=$Username; password=$Password; code=[string]$code; uuid=$captcha.uuid }
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
function Qr-Key([string]$Ticket) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return 'attendance:qr:ticket:' + ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($Ticket)))).Replace('-','').ToLowerInvariant() }
    finally { $sha.Dispose() }
}
function Concurrent-Submit([string]$Ticket, $Headers) {
    Add-Type -AssemblyName System.Net.Http
    $client = [Net.Http.HttpClient]::new()
    $requests = @(); $tasks = @()
    try {
        foreach ($i in 1..2) {
            $request = [Net.Http.HttpRequestMessage]::new([Net.Http.HttpMethod]::Post, "$BaseUrl/attendance/checkin/submit")
            $request.Headers.TryAddWithoutValidation('Authorization',$Headers.Authorization) | Out-Null
            $request.Content = [Net.Http.StringContent]::new((@{ ticket=$Ticket } | ConvertTo-Json -Compress),[Text.Encoding]::UTF8,'application/json')
            $requests += $request
            $tasks += $client.SendAsync($request)
        }
        [Threading.Tasks.Task]::WaitAll([Threading.Tasks.Task[]]$tasks)
        foreach ($task in $tasks) { $task.Result.Content.ReadAsStringAsync().GetAwaiter().GetResult() | ConvertFrom-Json }
    } finally { foreach ($r in $requests) { $r.Dispose() }; $client.Dispose() }
}

try {
    $null = Test-Sql 'SELECT 1'
    $adminHeaders = Login $AdminUser $AdminPassword
    $menus = (Api 'Get' '/system/menu/list').data
    $allMenus = @($menus | Where-Object { $_.path -eq 'attendance' -or $_.perms -like 'attendance:*' } | ForEach-Object menuId)
    $staffMenus = @($menus | Where-Object { $_.path -eq 'attendance' -or $_.perms -eq 'attendance:checkin:submit' } | ForEach-Object menuId)
    $role = Add-Role ($prefix+'_manager') $allMenus
    $staffRole = Add-Role ($prefix+'_staff') $staffMenus
    $deptA = Add-Department ($prefix+'_A'); $deptB = Add-Department ($prefix+'_B')
    $userA = Add-User ($prefix+'_a') $deptA @($role)
    $userB = Add-User ($prefix+'_b') $deptA @($staffRole)
    $userOther = Add-User ($prefix+'_other') $deptB @($role)
    $userMissing = Add-User ($prefix+'_new') $deptA @($staffRole)
    $userNoPerm = Add-User ($prefix+'_no') $deptA @()
    $siteA = Add-Site ($prefix+'_A') $deptA; $siteB = Add-Site ($prefix+'_B') $deptB
    $employeeA = Add-Employee ($prefix+'_A') $userA $siteA.siteId
    $employeeB = Add-Employee ($prefix+'_B') $userB $siteA.siteId
    $employeeOther = Add-Employee ($prefix+'_other') $userOther $siteB.siteId
    $headerA = Login ($prefix+'_a') $password
    $headerB = Login ($prefix+'_b') $password
    $headerOther = Login ($prefix+'_other') $password
    $headerMissing = Login ($prefix+'_new') $password
    $headerNoPerm = Login ($prefix+'_no') $password
    $sessionA = Add-Session $siteA.siteId ($prefix+'_A') $headerA
    $sessionB = Add-Session $siteB.siteId ($prefix+'_B') $headerOther
    Assert-True ($sessionA.deptId -eq $deptA) 'Session ownership is not derived from the site.'
    Assert-True ((Api 'Post' '/attendance/session' @{siteId=$siteA.siteId;title='invalid';durationMinutes=0} -AllowFailure).code -ne 200) 'Invalid duration accepted.'
    $qr = (Api 'Post' "/attendance/session/$($sessionA.sessionId)/qrcode" -Headers $headerA).data
    Assert-True ($qr.ticket -match '^[0-9a-f]{64}$' -and ($qr.expiresAt-$qr.serverTime) -le 60000) 'QR credential format or lifetime is incorrect.'
    $ttl = & $RedisCli TTL (Qr-Key $qr.ticket)
    Assert-True ([int]$ttl -ge 1 -and [int]$ttl -le 60) 'QR credential is not expiring in Redis.'
    Write-Host 'PASS: scoped session creation, random QR and Redis TTL'

    Assert-True ((Api 'Post' '/attendance/checkin/submit' @{ticket=$qr.ticket} -Headers @{} -AllowFailure).code -eq 401) 'Anonymous checkin accepted.'
    Assert-True ((Api 'Post' '/attendance/checkin/preview' @{ticket=$qr.ticket} -Headers $headerNoPerm -AllowFailure).code -eq 403) 'Unprivileged employee can preview.'
    Assert-True ((Api 'Post' '/attendance/checkin/preview' @{ticket=$qr.ticket} -Headers $headerMissing -AllowFailure).code -ne 200) 'Account without employee profile can check in.'
    Assert-True ((Api 'Post' '/attendance/checkin/submit' @{ticket=$qr.ticket} -Headers $headerOther -AllowFailure).code -ne 200) 'Wrong site binding accepted.'
    $preview = (Api 'Post' '/attendance/checkin/preview' @{ticket=$qr.ticket} -Headers $headerB).data
    Assert-True ($preview.employeeNo -eq $employeeB.employeeNo) 'Preview identity is incorrect.'
    $signedA = (Api 'Post' '/attendance/checkin/submit' @{ ticket=$qr.ticket; userId=$userOther; employeeId=$employeeOther.employeeId; siteId=$siteB.siteId; checkinTime='2099-01-01 00:00:00' } -Headers $headerA).data
    $signedB = (Api 'Post' '/attendance/checkin/submit' @{ticket=$qr.ticket} -Headers $headerB).data
    Assert-True ($signedA.recordId -ne $signedB.recordId) 'Shared QR was consumed by the first employee.'
    $recordA = (Api 'Get' "/attendance/record/$($signedA.recordId)").data
    Assert-True ($recordA.userId -eq $userA -and $recordA.siteId -eq $siteA.siteId -and $recordA.employeeId -eq $employeeA.employeeId -and $recordA.checkinTime -notlike '2099*') 'Client spoofed identity, site or time.'
    $qr2 = (Api 'Post' "/attendance/session/$($sessionA.sessionId)/qrcode" -Headers $headerA).data
    $again = (Api 'Post' '/attendance/checkin/submit' @{ticket=$qr2.ticket} -Headers $headerA).data
    Assert-True ($again.repeated -and $again.recordId -eq $signedA.recordId) 'QR refresh bypassed session deduplication.'
    $employeeNew = Add-Employee ($prefix+'_new') $userMissing $siteA.siteId
    $parallel = @(Concurrent-Submit $qr2.ticket $headerMissing)
    Assert-True ($parallel.Count -eq 2 -and @($parallel | Where-Object code -ne 200).Count -eq 0 -and $parallel[0].data.recordId -eq $parallel[1].data.recordId) 'Concurrent duplicate submission created multiple records or failed.'
    $recordsA = Api 'Get' "/attendance/record/list?sessionId=$($sessionA.sessionId)"
    Assert-True ($recordsA.total -eq 3) 'Unexpected successful checkin count.'
    Write-Host 'PASS: authentication, employee binding, server identity/time, shared QR and concurrent idempotency'

    $mine = Api 'Get' "/attendance/checkin/records?userId=$userA&pageNum=1&pageSize=1" -Headers $headerB
    Assert-True ($mine.total -eq 1 -and @($mine.rows).Count -eq 1 -and $mine.rows[0].userId -eq $userB) 'My records can be impersonated or pagination is incorrect.'
    $qrOther = (Api 'Post' "/attendance/session/$($sessionB.sessionId)/qrcode" -Headers $headerOther).data
    $signedOther = (Api 'Post' '/attendance/checkin/submit' @{ticket=$qrOther.ticket} -Headers $headerOther).data
    Assert-True ((Api 'Get' "/attendance/record/$($signedOther.recordId)" -Headers $headerA -AllowFailure).code -eq 403) 'Cross department record detail allowed.'
    Assert-True ((Api 'Post' "/attendance/session/$($sessionB.sessionId)/qrcode" -Headers $headerA -AllowFailure).code -eq 403) 'Cross department QR issuance allowed.'
    Assert-True ((Api 'Put' "/attendance/session/$($sessionB.sessionId)/close" -Headers $headerA -AllowFailure).code -eq 403) 'Cross department session close allowed.'
    Assert-True ((Api 'Get' '/attendance/record/list' -Headers $headerB -AllowFailure).code -eq 403) 'Mobile-only role can list management records.'
    $scoped = Api 'Get' '/attendance/record/list?params[dataScope]=OR%201=1' -Headers $headerA
    Assert-True (@($scoped.rows | Where-Object deptId -ne $deptA).Count -eq 0) 'Record data scope was bypassed.'
    Assert-True ((Api 'Get' '/attendance/record/list?beginDate=2026-02-30' -AllowFailure).code -ne 200) 'Invalid calendar date accepted.'
    Assert-True ((Api 'Get' '/attendance/record/list?beginDate=2026-02-01&endDate=2026-01-01' -AllowFailure).code -ne 200) 'Reversed date range accepted.'
    Write-Host 'PASS: own-record pagination, management RBAC, scoped QR and record queries'

    $employeeA = (Api 'Get' "/attendance/employee/$($employeeA.employeeId)").data
    $employeeA.employeeName = $prefix+'_renamed'
    $null = Api 'Put' '/attendance/employee' $employeeA
    $siteA = (Api 'Get' "/attendance/site/$($siteA.siteId)").data
    $siteA.siteName = $prefix+'_renamed_site'
    $null = Api 'Put' '/attendance/site' $siteA
    $snapshot = (Api 'Get' "/attendance/record/$($signedA.recordId)").data
    Assert-True ($snapshot.employeeName -eq $recordA.employeeName -and $snapshot.siteName -eq $recordA.siteName) 'Historical snapshots changed with master data.'
    Assert-True ((Api 'Delete' "/attendance/employee/$($employeeA.employeeId)" -AllowFailure).code -ne 200) 'Employee with records was deleted.'
    $employeeB = (Api 'Get' "/attendance/employee/$($employeeB.employeeId)").data
    $employeeB.status='1'; $employeeB.leaveDate='2021-01-01'; $null=Api 'Put' '/attendance/employee' $employeeB
    Assert-True ((Api 'Post' '/attendance/checkin/submit' @{ticket=$qr2.ticket} -Headers $headerB -AllowFailure).code -ne 200) 'Left employee can submit.'
    $employeeB.status='0'; $employeeB.leaveDate=$null; $null=Api 'Put' '/attendance/employee' $employeeB
    $null=Api 'Put' '/system/user/changeStatus' @{userId=$userB;status='1'}
    Assert-True ((Api 'Post' '/attendance/checkin/submit' @{ticket=$qr2.ticket} -Headers $headerB -AllowFailure).code -eq 403) 'Cached token bypassed disabled account.'
    $null=Api 'Put' '/system/user/changeStatus' @{userId=$userB;status='0'}
    $siteA.status='1'; $null=Api 'Put' '/attendance/site' $siteA
    Assert-True ((Api 'Post' '/attendance/checkin/submit' @{ticket=$qr2.ticket} -Headers $headerB -AllowFailure).code -ne 200) 'Disabled site accepted checkin.'
    Assert-True ((Api 'Post' "/attendance/session/$($sessionA.sessionId)/qrcode" -Headers $headerA -AllowFailure).code -ne 200) 'Disabled site can issue QR.'
    $siteA.status='0'; $null=Api 'Put' '/attendance/site' $siteA
    Write-Host 'PASS: immutable record snapshots, history deletion guards and live account/site/employee state'

    $expiring=(Api 'Post' "/attendance/session/$($sessionA.sessionId)/qrcode" -Headers $headerA).data
    $null=& $RedisCli PEXPIRE (Qr-Key $expiring.ticket) 100
    Start-Sleep -Milliseconds 150
    Assert-True ((Api 'Post' '/attendance/checkin/submit' @{ticket=$expiring.ticket} -Headers $headerB -AllowFailure).code -ne 200) 'Expired Redis credential accepted.'
    Assert-True ((Api 'Post' '/attendance/checkin/submit' @{ticket=('0'*64)} -Headers $headerB -AllowFailure).code -ne 200) 'Forged credential accepted.'
    Assert-True ((Api 'Post' '/attendance/checkin/submit' @{ticket='invalid'} -Headers $headerB -AllowFailure).code -ne 200) 'Malformed credential accepted.'
    $null=Api 'Put' "/attendance/session/$($sessionA.sessionId)/close" -Headers $headerA
    Assert-True ((Api 'Post' '/attendance/checkin/submit' @{ticket=$qr2.ticket} -Headers $headerB -AllowFailure).code -ne 200) 'Closed session accepted old credential.'
    Assert-True ((Api 'Post' "/attendance/session/$($sessionA.sessionId)/qrcode" -Headers $headerA -AllowFailure).code -ne 200) 'Closed session issued QR.'
    $expiredSession=Add-Session $siteA.siteId ($prefix+'_expired')
    $expiryQr=(Api 'Post' "/attendance/session/$($expiredSession.sessionId)/qrcode").data
    $null=Test-Sql "UPDATE att_checkin_session SET start_time=DATE_SUB(NOW(),INTERVAL 10 MINUTE),end_time=DATE_SUB(NOW(),INTERVAL 5 MINUTE) WHERE session_id=$($expiredSession.sessionId) AND title LIKE '$prefix%';"
    Assert-True ((Api 'Post' '/attendance/checkin/submit' @{ticket=$expiryQr.ticket} -Headers $headerB -AllowFailure).code -ne 200) 'Expired session accepted valid ticket.'
    Write-Host 'PASS: expired/forged tickets and closed/expired sessions'
    foreach ($path in @('/src/views/attendance/session/index.vue','/src/views/attendance/record/index.vue','/src/views/attendance/mobile/login.vue','/src/views/attendance/mobile/index.vue','/src/views/attendance/mobile/records.vue')) {
        $module=Invoke-WebRequest -UseBasicParsing ('http://127.0.0.1'+$path) -TimeoutSec 30
        Assert-True ($module.StatusCode -eq 200 -and $module.Content -match 'defineComponent') 'Vue page module compilation failed.'
    }
    Write-Host 'PASS: management and H5 page modules compile through Vite'
} finally {
    # 原始记录没有业务删除接口，仅在本地测试库删除此脚本创建的、前缀和ID均匹配的数据。
    if ($checkinSessionIds.Count) {
        $ids=$checkinSessionIds -join ','
        try { $null=Test-Sql "START TRANSACTION; DELETE FROM att_checkin_record WHERE session_id IN ($ids) AND employee_no LIKE '$prefix%'; DELETE FROM att_checkin_session WHERE session_id IN ($ids) AND title LIKE '$prefix%'; COMMIT;" }
        catch { $cleanupErrors.Add($_.Exception.Message) }
    }
    foreach ($headers in $sessions) {
        if ($adminHeaders -and $headers.Authorization -eq $adminHeaders.Authorization) { continue }
        try { $null=Api 'Post' '/logout' -Headers $headers } catch { $cleanupErrors.Add($_.Exception.Message) }
    }
    foreach ($entry in @(@{path='/attendance/employee/';ids=$employeeIds},@{path='/attendance/site/';ids=$siteIds},@{path='/system/user/';ids=$userIds},@{path='/system/dept/';ids=$departmentIds},@{path='/system/role/';ids=$roleIds})) {
        foreach ($id in $entry.ids) { try { $null=Api 'Delete' ($entry.path+$id) } catch { $cleanupErrors.Add($_.Exception.Message) } }
    }
    if ($adminHeaders) { try { $null=Api 'Post' '/logout' } catch { $cleanupErrors.Add($_.Exception.Message) } }
    if ($cleanupErrors.Count) { Write-Warning ("Cleanup requires attention ($prefix): "+($cleanupErrors -join '; ')) }
    else { Write-Host 'PASS: temporary checkin fixtures and sessions cleaned up' }
}
if ($cleanupErrors.Count) { throw 'Cleanup failed; inspect warnings.' }
Write-Host 'Checkin verification completed.'

