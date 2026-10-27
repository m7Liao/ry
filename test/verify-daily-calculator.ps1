$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$jar = Join-Path $projectRoot 'Vue-springboot3/ruoyi-admin/target/ruoyi-admin.jar'
$classes = Join-Path $projectRoot 'Vue-springboot3/ruoyi-attendance/target/test-classes'
if (!(Test-Path -LiteralPath $jar) -or !(Test-Path -LiteralPath $classes)) { throw 'Build the backend including test compilation first.' }
& java.exe "-Dloader.path=$classes" '-Dloader.main=com.ruoyi.attendance.AttDailyCalculatorTest' -cp $jar org.springframework.boot.loader.launch.PropertiesLauncher
if ($LASTEXITCODE -ne 0) { throw 'Daily calculator boundary tests failed.' }
