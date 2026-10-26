param(
    [string]$BaseUrl = 'http://127.0.0.1/dev-api',
    [string]$AdminUser = 'admin',
    [string]$AdminPassword = 'admin123',
    [string]$RedisCli = 'D:/redis/Redis-x64-5.0.14.1/redis-cli.exe'
)
$ErrorActionPreference = 'Stop'
# 仅用于本地开发库；创建带随机前缀的隔离数据，finally 中清理。
$prefix = 'at_' + [Guid]::NewGuid().ToString('N').Substring(0, 10)
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

try {
    $adminHeaders = Login $AdminUser $AdminPassword
    $routers = Api 'Get' '/getRouters'
    $routerJson = $routers.data | ConvertTo-Json -Depth 30
    Assert-True ($routerJson -match 'attendance/site/index' -and $routerJson -match 'attendance/employee/index') 'Attendance menus missing.'
    $menus = (Api 'Get' '/system/menu/list').data
    $attendanceMenus = @($menus | Where-Object { $_.path -eq 'attendance' -or $_.perms -like 'attendance:*' } | ForEach-Object menuId)
    $role = Add-Role ($prefix + '_full') $attendanceMenus
    $readMenus = @($menus | Where-Object { $_.perms -in @('attendance:site:list','attendance:site:query','attendance:employee:list','attendance:employee:query') -or $_.path -eq 'attendance' } | ForEach-Object menuId)
    $readRole = Add-Role ($prefix + '_read') $readMenus
    $deptA = Add-Department ($prefix + '_A')
    $deptB = Add-Department ($prefix + '_B')
    $userA = Add-User ($prefix + '_a') $deptA @($role)
    $userB = Add-User ($prefix + '_b') $deptB @($readRole)
    $userC = Add-User ($prefix + '_c') $deptA @()
    $siteA = Add-Site ($prefix + '_A') $deptA
    $siteB = Add-Site ($prefix + '_B') $deptB
    $employeeA = Add-Employee ($prefix + '_A') $userA $siteA.siteId
    $employeeB = Add-Employee ($prefix + '_B') $userB $siteB.siteId
    Write-Host 'PASS: menu routes, site and employee creation with mapped fields'

    $site = (Api 'Get' "/attendance/site/$($siteA.siteId)").data
    Assert-True ($site.employeeCount -eq 1 -and $site.deptId -eq $deptA -and $site.longitude -eq 116.397) 'Site detail mapping or bound count is incorrect.'
    $site.siteName = $prefix + '_updated'
    $null = Api 'Put' '/attendance/site' $site
    Assert-True (((Api 'Get' "/attendance/site/$($siteA.siteId)").data.siteName) -eq $site.siteName) 'Site update failed.'
    $duplicate = Copy-Body $site
    $result = Api 'Post' '/attendance/site' $duplicate -AllowFailure
    Assert-True ($result.code -ne 200) 'Duplicate site code accepted.'
    $invalid = Copy-Body $site; $invalid.longitude = 181
    Assert-True ((Api 'Put' '/attendance/site' $invalid -AllowFailure).code -ne 200) 'Out of range longitude accepted.'
    $invalid = Copy-Body $site; $invalid.latitude = $null
    Assert-True ((Api 'Put' '/attendance/site' $invalid -AllowFailure).code -ne 200) 'Unpaired coordinates accepted.'
    $employee = (Api 'Get' "/attendance/employee/$($employeeA.employeeId)").data
    Assert-True ($employee.userId -eq $userA -and $employee.deptId -eq $deptA -and $employee.siteName -eq $site.siteName) 'Employee join mapping is incorrect.'
    $employee.phone = '13800138000'; $employee.email = 'attendance-test@example.invalid'
    $null = Api 'Put' '/attendance/employee' $employee
    Assert-True ((Api 'Post' '/attendance/employee' $employee -AllowFailure).code -ne 200) 'Duplicate account binding accepted.'
    $duplicate = Copy-Body $employee; $duplicate.userId = $userC
    Assert-True ((Api 'Post' '/attendance/employee' $duplicate -AllowFailure).code -ne 200) 'Duplicate employee number accepted.'
    $invalid = Copy-Body $employee; $invalid.userId = $userC
    Assert-True ((Api 'Put' '/attendance/employee' $invalid -AllowFailure).code -ne 200) 'Existing employee account replacement accepted.'
    $invalid = Copy-Body $employee; $invalid.status = '1'; $invalid.leaveDate = '2019-12-01'
    Assert-True ((Api 'Put' '/attendance/employee' $invalid -AllowFailure).code -ne 200) 'Invalid leave date accepted.'
    $invalid.leaveDate = $null
    Assert-True ((Api 'Put' '/attendance/employee' $invalid -AllowFailure).code -ne 200) 'Left employee without date accepted.'
    $invalid.status = '0'; $invalid.hireDate = '2099-01-01'
    Assert-True ((Api 'Put' '/attendance/employee' $invalid -AllowFailure).code -ne 200) 'Future hire date accepted.'
    Write-Host 'PASS: updates, unique constraints, coordinates, immutable account and employment dates'

    $site.status = '1'; $null = Api 'Put' '/attendance/site' $site
    $invalid = Copy-Body $employee; $invalid.userId = $userC; $invalid.employeeNo = $prefix + '_C'
    Assert-True ((Api 'Post' '/attendance/employee' $invalid -AllowFailure).code -ne 200) 'Binding disabled site accepted.'
    $null = Api 'Put' '/attendance/employee' $employee
    Assert-True ((Api 'Delete' "/attendance/site/$($site.siteId)" -AllowFailure).code -ne 200) 'Deleting bound site accepted.'
    Assert-True ((Api 'Delete' "/system/user/$userA" -AllowFailure).code -ne 200) 'Deleting bound account accepted.'
    $siteC = Add-Site ($prefix + '_C') $deptA
    Assert-True ((Api 'Delete' "/attendance/site/$($siteC.siteId),$($site.siteId)" -AllowFailure).code -ne 200) 'Partially invalid batch delete accepted.'
    $null = Api 'Get' "/attendance/site/$($siteC.siteId)"
    $site.status = '0'; $null = Api 'Put' '/attendance/site' $site
    $emptyDept = Add-Department ($prefix + '_empty')
    $emptySite = Add-Site ($prefix + '_dept') $emptyDept
    Assert-True ((Api 'Delete' "/system/dept/$emptyDept" -AllowFailure).code -ne 200) 'Deleting site-owning department accepted.'
    Write-Host 'PASS: disabled sites, user/department/site deletion guards and batch rollback'

    $headerA = Login ($prefix + '_a') $password
    $headerB = Login ($prefix + '_b') $password
    $headerC = Login ($prefix + '_c') $password
    $scopedSites = Api 'Get' '/attendance/site/list?pageNum=1&pageSize=100' -Headers $headerA
    Assert-True (@($scopedSites.rows | Where-Object deptId -ne $deptA).Count -eq 0) 'Site list leaks another department.'
    $scopedEmployees = Api 'Get' '/attendance/employee/list?pageNum=1&pageSize=100' -Headers $headerA
    Assert-True ($scopedEmployees.total -eq 1 -and $scopedEmployees.rows[0].userId -eq $userA) 'Employee list data scope is incorrect.'
    Assert-True ((Api 'Get' "/attendance/site/$($siteB.siteId)" -Headers $headerA -AllowFailure).code -eq 403) 'Cross department site detail allowed.'
    Assert-True ((Api 'Get' "/attendance/employee/$($employeeB.employeeId)" -Headers $headerA -AllowFailure).code -eq 403) 'Cross department employee detail allowed.'
    Assert-True ((Api 'Put' '/attendance/site' $siteB -Headers $headerA -AllowFailure).code -eq 403) 'Cross department site edit allowed.'
    Assert-True ((Api 'Put' '/attendance/employee' $employeeB -Headers $headerA -AllowFailure).code -eq 403) 'Cross department employee edit allowed.'
    Assert-True ((Api 'Delete' "/attendance/site/$($siteB.siteId)" -Headers $headerA -AllowFailure).code -eq 403) 'Cross department delete allowed.'
    $invalid = Copy-Body $employee; $invalid.siteId = $siteB.siteId
    Assert-True ((Api 'Put' '/attendance/employee' $invalid -Headers $headerA -AllowFailure).code -eq 403) 'Cross department site binding allowed.'
    $invalid = Copy-Body $site; $invalid.deptId = $deptB
    Assert-True ((Api 'Put' '/attendance/site' $invalid -Headers $headerA -AllowFailure).code -eq 403) 'Moving site to unauthorized department allowed.'
    $options = Api 'Get' '/attendance/employee/users' -Headers $headerA
    Assert-True (@($options.data | Where-Object { $_.deptId -ne $deptA -or $_.id -in @($userA,$userB) }).Count -eq 0) 'Account options leak bound or out of scope users.'
    Assert-True (($options | ConvertTo-Json -Depth 10) -notmatch 'password|salt') 'Account options expose credential fields.'
    $options = Api 'Get' '/attendance/site/options' -Headers $headerA
    Assert-True (@($options.data | Where-Object id -eq $siteB.siteId).Count -eq 0) 'Site options leak another department.'
    $null = Api 'Get' '/attendance/employee/list' -Headers $headerB
    Assert-True ((Api 'Post' '/attendance/site' $siteB -Headers $headerB -AllowFailure).code -eq 403) 'Read only role can write.'
    Assert-True ((Api 'Get' '/attendance/employee/list' -Headers $headerC -AllowFailure).code -eq 403) 'User without permissions can list employees.'
    $ownSiteBody = @{ siteCode=$prefix+'_own'; siteName='Scoped creation'; deptId=$deptA; address='Test address'; coordinateSystem='WGS84'; status='0' }
    $null = Api 'Post' '/attendance/site' $ownSiteBody -Headers $headerA
    $ownSite = (Api 'Get' ("/attendance/site/list?siteCode="+$prefix+'_own') -Headers $headerA).rows[0]
    $siteIds.Add([long]$ownSite.siteId)
    $ownEmployee = @{ employeeNo=$prefix+'_own'; employeeName='Scoped employee'; userId=$userC; siteId=$ownSite.siteId; hireDate='2020-01-01'; status='0' }
    $null = Api 'Post' '/attendance/employee' $ownEmployee -Headers $headerA
    $ownRecord = (Api 'Get' ("/attendance/employee/list?employeeNo="+$prefix+'_own') -Headers $headerA).rows[0]
    $employeeIds.Add([long]$ownRecord.employeeId)
    Assert-True ($ownRecord.userId -eq $userC) 'Scoped manager cannot create employee without system user permissions.'
    $injection = Api 'Get' '/attendance/site/list?params[dataScope]=OR%201=1' -Headers $headerA
    Assert-True (@($injection.rows | Where-Object deptId -ne $deptA).Count -eq 0) 'Client controlled dataScope bypassed filtering.'
    Write-Host 'PASS: RBAC, department scopes, direct ID access, binding scope and safe option projections'

    # 更换主要场所后，绑定人数必须同步；离职状态可保存并还原。
    $employee.siteId = $siteC.siteId
    $null = Api 'Put' '/attendance/employee' $employee -Headers $headerA
    Assert-True ((Api 'Get' "/attendance/site/$($siteC.siteId)").data.employeeCount -eq 1) 'Rebinding did not update count.'
    $employee.status = '1'; $employee.leaveDate = '2021-01-01'
    $null = Api 'Put' '/attendance/employee' $employee
    Assert-True ((Api 'Get' "/attendance/employee/$($employee.employeeId)").data.status -eq '1') 'Employment status update failed.'
    Write-Host 'PASS: primary site rebinding and employment status'
    foreach ($path in @('/src/views/attendance/site/index.vue','/src/views/attendance/employee/index.vue')) {
        $module = Invoke-WebRequest -UseBasicParsing ('http://127.0.0.1' + $path) -TimeoutSec 30
        Assert-True ($module.StatusCode -eq 200 -and $module.Content -match 'defineComponent') 'Vite page module compilation failed.'
    }
    Write-Host 'PASS: both Vue page modules compile through the running Vite server'
} finally {
    # 先注销测试登录，再清理本脚本记录的业务数据、账号、部门和角色。
    foreach ($headers in $sessions) {
        if ($adminHeaders -and $headers.Authorization -eq $adminHeaders.Authorization) { continue }
        try { $null = Api 'Post' '/logout' -Headers $headers } catch { $cleanupErrors.Add($_.Exception.Message) }
    }
    foreach ($entry in @(
        @{ path='/attendance/employee/'; ids=$employeeIds },
        @{ path='/attendance/site/'; ids=$siteIds },
        @{ path='/system/user/'; ids=$userIds },
        @{ path='/system/dept/'; ids=$departmentIds },
        @{ path='/system/role/'; ids=$roleIds }
    )) {
        foreach ($id in $entry.ids) {
            try { $null = Api 'Delete' ($entry.path + $id) } catch { $cleanupErrors.Add($_.Exception.Message) }
        }
    }
    if ($adminHeaders) { try { $null = Api 'Post' '/logout' } catch { $cleanupErrors.Add($_.Exception.Message) } }
    if ($cleanupErrors.Count) { Write-Warning ("Cleanup requires attention ($prefix): " + ($cleanupErrors -join '; ')) }
    else { Write-Host 'PASS: temporary test data and sessions cleaned up' }
}
if ($cleanupErrors.Count) { throw 'Test cleanup failed; see warnings above.' }
Write-Host 'Attendance verification completed.'
