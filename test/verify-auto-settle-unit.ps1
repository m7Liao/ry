$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$jar = Join-Path $projectRoot 'Vue-springboot3/ruoyi-admin/target/ruoyi-admin.jar'
$classes = Join-Path $projectRoot 'Vue-springboot3/ruoyi-admin/target/test-classes'
& java.exe "-Dloader.path=$classes" '-Dloader.main=com.ruoyi.attendance.AttAutoSettleTest' -cp $jar org.springframework.boot.loader.launch.PropertiesLauncher
if ($LASTEXITCODE -ne 0) { throw 'Automatic settlement boundary tests failed.' }
