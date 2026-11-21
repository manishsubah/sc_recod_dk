# Builds installers\output\RecLite-<version>-windows-x64-setup.exe.
#
#   powershell -ExecutionPolicy Bypass -File installers\windows\build.ps1
#   powershell -ExecutionPolicy Bypass -File installers\windows\build.ps1 -Flutter C:\path\to\flutter\bin\flutter.bat
#
# Needs Flutter 3.47.1, Visual Studio 2022 (C++), and Inno Setup 6
# (winget install JRSoftware.InnoSetup).
param(
  [string]$Flutter = 'flutter',
  [switch]$SkipBuild
)
$ErrorActionPreference = 'Stop'

$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$pubspec = Get-Content (Join-Path $root 'pubspec.yaml') -Raw
if ($pubspec -notmatch '(?m)^version:\s*(\d+\.\d+\.\d+)\+(\d+)') {
  throw 'pubspec.yaml has no "version: x.y.z+build" line.'
}
$version = $Matches[1]
$build = $Matches[2]
Write-Host "RecLite $version (build $build)"

if (-not $SkipBuild) {
  Push-Location $root
  try {
    & $Flutter build windows --release
    if ($LASTEXITCODE -ne 0) { throw "flutter build failed ($LASTEXITCODE)." }
  } finally {
    Pop-Location
  }
}

$release = Join-Path $root 'build\windows\x64\runner\Release'
if (-not (Test-Path (Join-Path $release 'RecLite.exe'))) {
  throw "No release build in $release. Run without -SkipBuild."
}

# Flutter apps need the Visual C++ runtime; shipping it next to the exe means users
# don't have to install the redistributable themselves (Microsoft allows this).
foreach ($dll in 'msvcp140.dll', 'vcruntime140.dll', 'vcruntime140_1.dll') {
  Copy-Item (Join-Path $env:WINDIR "System32\$dll") $release -Force
}

$iscc = @(
  "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe",
  "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
  "$env:ProgramFiles\Inno Setup 6\ISCC.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $iscc) {
  throw 'Inno Setup 6 not found. Install it with: winget install JRSoftware.InnoSetup'
}

& $iscc /Q "/DAppVersion=$version" "/DBuildNumber=$build" (Join-Path $PSScriptRoot 'reclite.iss')
if ($LASTEXITCODE -ne 0) { throw "Inno Setup failed ($LASTEXITCODE)." }

$setup = Join-Path $root "installers\output\RecLite-$version-windows-x64-setup.exe"
$size = [math]::Round((Get-Item $setup).Length / 1MB, 1)
Write-Host "Done: $setup ($size MB)"
