$ErrorActionPreference = 'Stop'
foreach ($component in @('frontend', 'backend', 'redis')) {
    $recordPath = Join-Path $PSScriptRoot ".runtime/$component-process.json"
    if (!(Test-Path $recordPath)) { continue }
    $record = Get-Content -LiteralPath $recordPath -Raw | ConvertFrom-Json
    $process = Get-Process -Id $record.Id -ErrorAction SilentlyContinue
    if ($process -and $process.StartTime.ToUniversalTime().Ticks -eq [long]$record.Started) {
        Stop-Process -Id $process.Id
        if (!$process.WaitForExit(10000)) { throw "Timed out stopping $component." }
        Write-Host "Stopped $component."
    }
    Remove-Item -LiteralPath $recordPath
}
