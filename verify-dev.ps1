$ErrorActionPreference = 'Stop'
$baseUrl = 'http://127.0.0.1/dev-api'
$page = Invoke-WebRequest -UseBasicParsing 'http://127.0.0.1/' -TimeoutSec 15
if ($page.StatusCode -ne 200 -or $page.Content -notmatch '/src/main.js') { throw 'Frontend page check failed.' }
Write-Host 'PASS: frontend HTML'
$main = Invoke-WebRequest -UseBasicParsing 'http://127.0.0.1/src/main.js' -TimeoutSec 30
if ($main.StatusCode -ne 200 -or $main.Content -notmatch 'createApp') { throw 'Frontend module check failed.' }
Write-Host 'PASS: frontend entry module'
$anonymous = Invoke-RestMethod "$baseUrl/getInfo" -TimeoutSec 15
if ($anonymous.code -ne 401) { throw 'Anonymous request was not rejected.' }
Write-Host 'PASS: authentication required'
$captcha = Invoke-RestMethod "$baseUrl/captchaImage" -TimeoutSec 15
if ($captcha.code -ne 200 -or !$captcha.img) { throw 'Captcha generation failed.' }
# Read this test request's expected value from our local development Redis.
# Captcha remains enabled for normal logins.
$codeJson = & 'D:/redis/Redis-x64-5.0.14.1/redis-cli.exe' --raw GET ('captcha_codes:' + $captcha.uuid)
if ($LASTEXITCODE -ne 0 -or !$codeJson) { throw 'Captcha cache check failed.' }
$code = $codeJson | ConvertFrom-Json
$body = @{ username = 'admin'; password = 'admin123'; uuid = $captcha.uuid; code = [string]$code } | ConvertTo-Json
$login = Invoke-RestMethod "$baseUrl/login" -Method Post -ContentType 'application/json' -Body $body -TimeoutSec 15
if ($login.code -ne 200 -or !$login.token) { throw "Login failed: $($login.msg)" }
$headers = @{ Authorization = 'Bearer ' + $login.token }
try {
    Write-Host 'PASS: proxy, captcha, Redis and admin login'
    $info = Invoke-RestMethod "$baseUrl/getInfo" -Headers $headers -TimeoutSec 15
    if ($info.code -ne 200 -or $info.user.userName -ne 'admin') { throw 'User info check failed.' }
    $routers = Invoke-RestMethod "$baseUrl/getRouters" -Headers $headers -TimeoutSec 15
    if ($routers.code -ne 200 -or !$routers.data.Count) { throw 'Menu route check failed.' }
    if (($routers.data | ConvertTo-Json -Depth 30) -match 'ruoyi\.vip') { throw 'Framework promotion menu remains.' }
    $users = Invoke-RestMethod "$baseUrl/system/user/list?pageNum=1&pageSize=10" -Headers $headers -TimeoutSec 15
    if ($users.code -ne 200 -or !($users.rows | Where-Object { $_.userName -eq 'admin' })) { throw 'Database list check failed.' }
    $notices = Invoke-RestMethod "$baseUrl/system/notice/list?pageNum=1&pageSize=10" -Headers $headers -TimeoutSec 15
    $jobs = Invoke-RestMethod "$baseUrl/monitor/job/list?pageNum=1&pageSize=10" -Headers $headers -TimeoutSec 15
    if ($notices.code -ne 200 -or $jobs.code -ne 200) { throw 'Notice or scheduler API check failed.' }
    if (($notices.rows | ConvertTo-Json -Depth 10) -match '若依开源框架介绍|2018-07-01') { throw 'Framework sample notices remain.' }
    if (($jobs.rows | ConvertTo-Json -Depth 10) -match 'ryTask\.') { throw 'Framework sample jobs remain.' }
    $docs = Invoke-RestMethod 'http://127.0.0.1:8080/v3/api-docs/default' -TimeoutSec 30
    $apiPaths = $docs.paths.PSObject.Properties.Name
    if ($apiPaths -match '^/test/user' -or $apiPaths -notcontains '/system/user/list') { throw 'API documentation contains demo routes or lacks system routes.' }
    Write-Host 'PASS: user info, menus and database list'
    Write-Host 'PASS: notices, scheduler and real API documentation'
} finally {
    $logout = Invoke-RestMethod "$baseUrl/logout" -Method Post -Headers $headers -TimeoutSec 15
    if ($logout.code -ne 200) { throw 'Logout check failed.' }
}
$expired = Invoke-RestMethod "$baseUrl/getInfo" -Headers $headers -TimeoutSec 15
if ($expired.code -ne 401) { throw 'Token still works after logout.' }
Write-Host 'PASS: logout invalidates token'
