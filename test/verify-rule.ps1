param(
    [string]$BaseUrl = 'http://127.0.0.1/dev-api',
    [string]$AdminUser = 'admin',
    [string]$AdminPassword = 'admin123',
    [string]$RedisCli = 'D:/redis/Redis-x64-5.0.14.1/redis-cli.exe'
)
$ErrorActionPreference = 'Stop'
# 仅用于本地开发库；创建带随机前缀的隔离数据，finally 中清理。
$prefix = 'rl_' + [Guid]::NewGuid().ToString('N').Substring(0, 10)
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
    # Windows PowerShell 5 对未声明 charset 的 JSON 可能按西欧编码解码。
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
function Concurrent-Update($Body, $Headers) {
    Add-Type -AssemblyName System.Net.Http
    $client=[Net.Http.HttpClient]::new(); $requests=@(); $tasks=@()
    try {
        foreach ($i in 1..2) {
            $value=Copy-Body $Body; $value.remark="Concurrent update $i"
            $request=[Net.Http.HttpRequestMessage]::new([Net.Http.HttpMethod]::Put,"$BaseUrl/attendance/rule")
            $null=$request.Headers.TryAddWithoutValidation('Authorization',$Headers.Authorization)
            $request.Content=[Net.Http.StringContent]::new(($value | ConvertTo-Json -Depth 20 -Compress),[Text.Encoding]::UTF8,'application/json')
            $requests+=$request; $tasks+=$client.SendAsync($request)
        }
        [Threading.Tasks.Task]::WaitAll([Threading.Tasks.Task[]]$tasks)
        foreach ($task in $tasks) { $task.Result.Content.ReadAsStringAsync().GetAwaiter().GetResult() | ConvertFrom-Json }
    } finally { foreach ($r in $requests) { $r.Dispose() }; $client.Dispose() }
}

try {
    $adminHeaders=Login $AdminUser $AdminPassword
    Assert-True (((Api 'Get' '/getRouters').data | ConvertTo-Json -Depth 30) -match 'attendance/rule/index') 'Rule menu missing.'
    $menus=(Api 'Get' '/system/menu/list').data
    $fullMenus=@($menus | Where-Object { $_.path -eq 'attendance' -or $_.perms -like 'attendance:rule:*' } | ForEach-Object menuId)
    $readMenus=@($menus | Where-Object { $_.path -eq 'attendance' -or $_.perms -in @('attendance:rule:list','attendance:rule:query') } | ForEach-Object menuId)
    $role=Add-Role ($prefix+'_full') $fullMenus
    $readRole=Add-Role ($prefix+'_read') $readMenus
    $deptA=Add-Department ($prefix+'_A'); $deptB=Add-Department ($prefix+'_B')
    $userA=Add-User ($prefix+'_a') $deptA @($role)
    $userB=Add-User ($prefix+'_b') $deptB @($readRole)
    $userC=Add-User ($prefix+'_c') $deptA @()
    $siteA=Add-Site ($prefix+'_A') $deptA
    $siteB=Add-Site ($prefix+'_B') $deptB
    $siteC=Add-Site ($prefix+'_C') $deptA
    $manager=Login ($prefix+'_a') $password
    $reader=Login ($prefix+'_b') $password
    $noPermission=Login ($prefix+'_c') $password
    $ruleA=Add-Rule (Rule-Body $siteA.siteId ($prefix+'_day')) $manager
    $night=Rule-Body $siteB.siteId ($prefix+'_night'); $night.startTime='22:00'; $night.endTime='06:00'; $night.endNextDay='1'; $night.restMinutes=30
    $ruleB=Add-Rule $night
    Assert-True ($ruleA.workDays -eq '1,2,3,4,5' -and $ruleA.plannedWorkMinutes -eq 480 -and $ruleA.version -eq 0) 'Day rule fields, work-day normalization or planned duration incorrect.'
    Assert-True ($ruleA.startWindow -eq '当日 08:00 ～ 当日 10:00' -and $ruleA.endWindow -eq '当日 17:00 ～ 当日 20:00') ("Day windows incorrect: "+$ruleA.startWindow+' / '+$ruleA.endWindow)
    Assert-True ($ruleB.plannedWorkMinutes -eq 450 -and $ruleB.endWindow -eq '次日 05:00 ～ 次日 08:00') 'Overnight duration or window incorrect.'
    $duplicate=Rule-Body $siteA.siteId ($prefix+'_duplicate')
    Assert-True ((Api 'Post' '/attendance/rule' $duplicate -AllowFailure).code -ne 200) 'Two rules accepted for one site.'
    Write-Host 'PASS: fixed shift creation, canonical work days, day/overnight windows and unique site rule'

    $invalidChanges=@(
        @{ key='workDays'; value='' }, @{ key='workDays'; value='1,1' }, @{ key='workDays'; value='0,1' },
        @{ key='startTime'; value='24:00' }, @{ key='endTime'; value='18:60' },
        @{ key='endTime'; value='09:00' }, @{ key='endTime'; value='08:00' },
        @{ key='endNextDay'; value='1' }, @{ key='restMinutes'; value=540 }, @{ key='restMinutes'; value=-1 },
        @{ key='startAfterMinutes'; value=480 }, @{ key='startAfterMinutes'; value=360 },
        @{ key='lateGraceMinutes'; value=61 }, @{ key='earlyGraceMinutes'; value=61 },
        @{ key='lateGraceMinutes'; value=181 }, @{ key='endBeforeMinutes'; value=$null },
        @{ key='status'; value='2' }, @{ key='ruleName'; value=' ' }
    )
    # 让两个窗口在15:00相接，单项分钟数均合法，应由业务校验拒绝。
    $bad=Copy-Body $ruleA; $bad.startAfterMinutes=360; $bad.endBeforeMinutes=180
    Assert-True ((Api 'Put' '/attendance/rule' $bad -AllowFailure).code -ne 200) 'Touching windows accepted.'
    foreach ($change in $invalidChanges) {
        $bad=Copy-Body $ruleA; $bad.($change.key)=$change.value
        # 上班后360分钟本身合法；与下班前180分钟组合才构成窗口相接。
        if ($change.key -eq 'startAfterMinutes' -and $change.value -eq 360) { $bad.endBeforeMinutes=181 }
        Assert-True ((Api 'Put' '/attendance/rule' $bad -AllowFailure).code -ne 200) ("Invalid rule accepted: "+$change.key+'='+$change.value)
    }
    $short=Copy-Body $ruleA; $short.startTime='12:00'; $short.endTime='12:01'; $short.restMinutes=0; $short.startBeforeMinutes=0; $short.startAfterMinutes=0; $short.endBeforeMinutes=0; $short.endAfterMinutes=0; $short.lateGraceMinutes=0
    $null=Api 'Put' '/attendance/rule' $short
    Assert-True (((Api 'Get' "/attendance/rule/$($ruleA.ruleId)").data.plannedWorkMinutes) -eq 1) 'Valid shortest shift rejected.'
    $ruleA.version=(Api 'Get' "/attendance/rule/$($ruleA.ruleId)").data.version
    $null=Api 'Put' '/attendance/rule' $ruleA
    $ruleA=(Api 'Get' "/attendance/rule/$($ruleA.ruleId)").data
    Write-Host 'PASS: time, working-day, window, grace and rest validation including one-minute boundary'

    $scoped=Api 'Get' '/attendance/rule/list?pageNum=1&pageSize=1&params[dataScope]= OR 1=1' -Headers $manager
    Assert-True ($scoped.total -eq 1 -and $scoped.rows.Count -eq 1 -and $scoped.rows[0].siteId -eq $siteA.siteId) 'Scoped pagination or scope-input isolation failed.'
    $options=(Api 'Get' '/attendance/site/options' -Headers $manager).data
    Assert-True (@($options | Where-Object id -eq $siteA.siteId).Count -eq 1 -and @($options | Where-Object id -eq $siteB.siteId).Count -eq 0) 'Rule-only manager site options require extra permission or leak other departments.'
    Assert-True ((Api 'Get' "/attendance/rule/$($ruleB.ruleId)" -Headers $manager -AllowFailure).code -eq 403) 'Cross-department detail accepted.'
    Assert-True ((Api 'Put' '/attendance/rule' $ruleB -Headers $manager -AllowFailure).code -eq 403) 'Cross-department edit accepted.'
    Assert-True ((Api 'Delete' "/attendance/rule/$($ruleB.ruleId)" -Headers $manager -AllowFailure).code -eq 403) 'Cross-department delete accepted.'
    Assert-True ((Api 'Post' '/attendance/rule' (Rule-Body $siteB.siteId 'Out of scope') -Headers $manager -AllowFailure).code -eq 403) 'Cross-department create accepted.'
    Assert-True ((Api 'Get' '/attendance/rule/list' -Headers $reader).total -eq 1) 'Read-only scoped list failed.'
    Assert-True ((Api 'Put' '/attendance/rule' $ruleB -Headers $reader -AllowFailure).code -eq 403) 'Read-only edit accepted.'
    Assert-True ((Api 'Get' '/attendance/rule/list' -Headers $noPermission -AllowFailure).code -eq 403) 'Unprivileged list accepted.'
    Assert-True ((Api 'Get' '/attendance/rule/list' -Headers @{} -AllowFailure).code -eq 401) 'Anonymous list accepted.'
    $changedSite=Copy-Body $ruleA; $changedSite.siteId=$siteC.siteId
    Assert-True ((Api 'Put' '/attendance/rule' $changedSite -AllowFailure).code -ne 200) 'Existing rule can change site.'
    Write-Host 'PASS: RBAC, direct ID and write scope checks, safe options and pagination'

    $stale=Copy-Body $ruleA; $ruleA.ruleName=$prefix+'_updated'; $ruleA.status='1'
    $null=Api 'Put' '/attendance/rule' $ruleA -Headers $manager
    $saved=(Api 'Get' "/attendance/rule/$($ruleA.ruleId)" -Headers $manager).data
    Assert-True ($saved.status -eq '1' -and $saved.ruleName -eq $ruleA.ruleName -and $saved.version -eq ($ruleA.version+1)) 'Rule update, disable or version failed.'
    Assert-True ((Api 'Put' '/attendance/rule' $stale -AllowFailure).code -ne 200) 'Stale version overwrote newer data.'
    $responses=@(Concurrent-Update $saved $manager)
    Assert-True (@($responses | Where-Object code -eq 200).Count -eq 1 -and @($responses | Where-Object code -ne 200).Count -eq 1) 'Concurrent updates did not preserve one version winner.'
    Assert-True ((Api 'Delete' "/attendance/site/$($siteA.siteId)" -AllowFailure).code -ne 200) 'Site with rule can be deleted.'
    $siteC.status='1'; $null=Api 'Put' '/attendance/site' $siteC
    Assert-True ((Api 'Post' '/attendance/rule' (Rule-Body $siteC.siteId 'Disabled site') -AllowFailure).code -ne 200) 'New rule accepted for disabled site.'
    $module=Invoke-WebRequest 'http://127.0.0.1/src/views/attendance/rule/index.vue' -UseBasicParsing -TimeoutSec 20
    Assert-True ($module.StatusCode -eq 200 -and $module.Content.Contains('_sfc_main')) 'Rule Vue page did not compile.'
    Write-Host 'PASS: updates, disable, stale/concurrent edit protection, site deletion guard and Vue compilation'
} finally {
    foreach ($headers in $sessions) {
        if ($adminHeaders -and $headers.Authorization -eq $adminHeaders.Authorization) { continue }
        try { $null=Api 'Post' '/logout' -Headers $headers } catch { $cleanupErrors.Add($_.Exception.Message) }
    }
    foreach ($entry in @(
        @{ path='/attendance/rule/'; ids=$ruleIds },
        @{ path='/attendance/site/'; ids=$siteIds },
        @{ path='/system/user/'; ids=$userIds },
        @{ path='/system/dept/'; ids=$departmentIds },
        @{ path='/system/role/'; ids=$roleIds }
    )) {
        foreach ($id in $entry.ids) { try { $null=Api 'Delete' ($entry.path+$id) } catch { $cleanupErrors.Add($_.Exception.Message) } }
    }
    if ($adminHeaders) { try { $null=Api 'Post' '/logout' } catch { $cleanupErrors.Add($_.Exception.Message) } }
    if ($cleanupErrors.Count) { Write-Warning ("Cleanup requires attention ($prefix): "+($cleanupErrors -join '; ')) }
    else { Write-Host 'PASS: temporary rule fixtures and login sessions cleaned up' }
}
if ($cleanupErrors.Count) { throw 'Rule cleanup failed; inspect warnings.' }
Write-Host 'Rule verification completed.'
