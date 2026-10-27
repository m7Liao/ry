param([switch]$Native,[string]$Portrait='',[string]$DifferentPortrait='',[string]$MultiplePortrait='')
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$jar=Join-Path $root 'Vue-springboot3/ruoyi-admin/target/ruoyi-admin.jar'
$classes=Join-Path $root 'Vue-springboot3/ruoyi-admin/target/test-classes'
$faceArgs=@()
if ($Native) { $faceArgs+= 'native'; if ($Portrait) { $faceArgs+=(Resolve-Path -LiteralPath $Portrait).Path } }
if ($Native -and $Portrait -and $DifferentPortrait) { $faceArgs+=(Resolve-Path -LiteralPath $DifferentPortrait).Path; if ($MultiplePortrait) { $faceArgs+=(Resolve-Path -LiteralPath $MultiplePortrait).Path } }
Push-Location (Join-Path $root 'Vue-springboot3')
try {
    & java.exe "-Dloader.path=$classes" '-Dloader.main=com.ruoyi.attendance.AttFaceTest' -cp $jar org.springframework.boot.loader.launch.PropertiesLauncher @faceArgs
    if ($LASTEXITCODE -ne 0) { throw 'Face validation failed' }
} finally { Pop-Location }
