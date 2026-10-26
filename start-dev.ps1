param([switch]$Build, [switch]$Lan)
$ErrorActionPreference = 'Stop'
$projectRoot = $PSScriptRoot
$runtimeDir = Join-Path $projectRoot '.runtime'
$backendDir = Join-Path $projectRoot 'Vue-springboot3'
$frontendDir = Join-Path $projectRoot 'Vue3-master'
$logDir = Join-Path $runtimeDir 'logs'
New-Item -ItemType Directory -Force $logDir | Out-Null
if (!(Test-Path (Join-Path $runtimeDir 'application-local.yml'))) {
    throw 'Missing .runtime/application-local.yml (local database settings).'
}
function Test-Port([int]$Port) {
    $client = New-Object System.Net.Sockets.TcpClient
    try { $client.Connect('127.0.0.1', $Port); return $true }
    catch { return $false }
    finally { $client.Dispose() }
}
if (!(Test-Port 3306)) { throw 'MySQL is not listening on port 3306.' }
if ($Build) {
    Push-Location $backendDir
    try {
        & mvn.cmd '-Dmaven.repo.local=../.runtime/m2' -B -DskipTests package
        if ($LASTEXITCODE -ne 0) { throw 'Backend build failed.' }
    } finally { Pop-Location }
    Push-Location $frontendDir
    try {
        & npm.cmd install --cache ../.runtime/npm-cache --no-audit --no-fund
        if ($LASTEXITCODE -ne 0) { throw 'Frontend dependency installation failed.' }
    } finally { Pop-Location }
}
$jar = Join-Path $backendDir 'ruoyi-admin/target/ruoyi-admin.jar'
$vite = Join-Path $frontendDir 'node_modules/vite/bin/vite.js'
if (!(Test-Path $jar)) { throw 'Backend build missing. Run ./start-dev.ps1 -Build first.' }
if (!(Test-Port 6379)) {
    $redisExe = 'D:/redis/Redis-x64-5.0.14.1/redis-server.exe'
    if (!(Test-Path $redisExe)) { throw 'Redis missing. Start Redis on 127.0.0.1:6379 first.' }
    $redisProcess = Start-Process -FilePath $redisExe -ArgumentList '--bind 127.0.0.1 --port 6379 --save "" --appendonly no' -WorkingDirectory $runtimeDir -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $logDir 'redis.out.log') -RedirectStandardError (Join-Path $logDir 'redis.err.log')
    @{ Id = $redisProcess.Id; Started = $redisProcess.StartTime.ToUniversalTime().Ticks } | ConvertTo-Json | Set-Content (Join-Path $runtimeDir 'redis-process.json')
    for ($attempt = 0; $attempt -lt 20 -and !(Test-Port 6379); $attempt++) { Start-Sleep -Milliseconds 250 }
    if (!(Test-Port 6379)) { throw 'Redis failed to start. Check .runtime/logs/redis.*.log.' }
}
if (!(Test-Port 8080)) {
    $env:RUOYI_LOG_PATH = '../.runtime/logs'
    $javaExe = Join-Path $env:JAVA_HOME 'bin/java.exe'
    if (!(Test-Path $javaExe)) { throw 'JAVA_HOME must point to JDK 17.' }
    $backendProcess = Start-Process -FilePath $javaExe -ArgumentList '-jar ruoyi-admin/target/ruoyi-admin.jar --spring.config.additional-location=file:../.runtime/ --spring.profiles.active=druid,local --debug=false' -WorkingDirectory $backendDir -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $logDir 'backend.out.log') -RedirectStandardError (Join-Path $logDir 'backend.err.log')
    @{ Id = $backendProcess.Id; Started = $backendProcess.StartTime.ToUniversalTime().Ticks } | ConvertTo-Json | Set-Content (Join-Path $runtimeDir 'backend-process.json')
}
if (!(Test-Port 80)) {
    if (!(Test-Path $vite)) {
        Write-Warning 'Backend launched. Frontend dependencies are still missing; rerun after npm install.'
        return
    }
    $env:BROWSER = 'none'
    $frontendHost = if ($Lan) { '0.0.0.0' } else { '127.0.0.1' }
    $frontendProcess = Start-Process -FilePath (Get-Command node.exe).Source -ArgumentList "node_modules/vite/bin/vite.js --host $frontendHost --port 80 --strictPort" -WorkingDirectory $frontendDir -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $logDir 'frontend.out.log') -RedirectStandardError (Join-Path $logDir 'frontend.err.log')
    @{ Id = $frontendProcess.Id; Started = $frontendProcess.StartTime.ToUniversalTime().Ticks } | ConvertTo-Json | Set-Content (Join-Path $runtimeDir 'frontend-process.json')
}
foreach ($address in @('http://127.0.0.1:8080/captchaImage', 'http://127.0.0.1/')) {
    $ready = $false
    for ($attempt = 0; $attempt -lt 45; $attempt++) {
        try {
            $response = Invoke-WebRequest -UseBasicParsing $address -TimeoutSec 2
            if ($response.StatusCode -eq 200) { $ready = $true; break }
        } catch { Start-Sleep -Seconds 1 }
    }
    if (!$ready) { throw "Service did not become ready: $address. Check .runtime/logs." }
}
Write-Host 'Ready. Frontend: http://localhost  Backend: http://localhost:8080'
Write-Host 'Logs: .runtime/logs'
if ($Lan) { Write-Host 'LAN frontend enabled. Use this computer IPv4 address in the QR mobile address field.' }
