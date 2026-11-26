# Builds installers\output\RecLite-<version>-windows-x64-setup.exe with IExpress,
# which is built into Windows (nothing to install).
#
#   powershell -ExecutionPolicy Bypass -File installers\windows\build.ps1
#   powershell -ExecutionPolicy Bypass -File installers\windows\build.ps1 -Flutter C:\path\to\flutter\bin\flutter.bat
#
# Needs Flutter 3.47.1 and Visual Studio 2022 (C++).
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
Write-Host "RecLite $version (build $($Matches[2]))"

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

# IExpress can't hold folders, so the app (which has a data\ folder) goes in as a zip.
$stage = Join-Path ([IO.Path]::GetTempPath()) 'reclite_installer'
if (Test-Path $stage) { Remove-Item $stage -Recurse -Force }
New-Item -ItemType Directory -Path $stage | Out-Null
Compress-Archive -Path (Join-Path $release '*') -DestinationPath (Join-Path $stage 'RecLite.zip')
(Get-Content (Join-Path $PSScriptRoot 'install.ps1') -Raw).Replace('__VERSION__', $version) |
  Set-Content (Join-Path $stage 'install.ps1') -Encoding UTF8
Copy-Item (Join-Path $PSScriptRoot 'uninstall.ps1') $stage
# The license box only breaks lines on CRLF.
$license = (Get-Content (Join-Path $root 'installers\LICENSE.txt') -Raw) -replace "`r?`n", "`r`n"
[IO.File]::WriteAllText((Join-Path $stage 'License.txt'), $license, [Text.UTF8Encoding]::new($false))
Set-Content (Join-Path $stage 'install.cmd') -Encoding ASCII -Value `
  '@powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0install.ps1"'

$output = Join-Path $root 'installers\output'
New-Item -ItemType Directory -Path $output -Force | Out-Null
$setup = Join-Path $output "RecLite-$version-windows-x64-setup.exe"
if (Test-Path $setup) { Remove-Item $setup -Force }

# The user sees the license first and must answer Yes; then install.cmd runs.
# IExpress only accepts the file list in this exact form (names via [Strings]).
$files = 'RecLite.zip', 'install.ps1', 'install.cmd', 'uninstall.ps1', 'License.txt'
$fileStrings = (0..($files.Count - 1) | ForEach-Object { "FILE$_=`"$($files[$_])`"" }) -join "`r`n"
$fileList = (0..($files.Count - 1) | ForEach-Object { "%FILE$_%=" }) -join "`r`n"
$sed = @"
[Version]
Class=IEXPRESS
SEDVersion=3
[Options]
PackagePurpose=InstallApp
ShowInstallProgramWindow=1
HideExtractAnimation=0
UseLongFileName=1
InsideCompressed=0
CAB_FixedSize=0
CAB_ResvCodeSigning=0
RebootMode=N
InstallPrompt=%InstallPrompt%
DisplayLicense=%DisplayLicense%
FinishMessage=%FinishMessage%
TargetName=%TargetName%
FriendlyName=%FriendlyName%
AppLaunched=%AppLaunched%
PostInstallCmd=%PostInstallCmd%
AdminQuietInstCmd=%AdminQuietInstCmd%
UserQuietInstCmd=%UserQuietInstCmd%
SourceFiles=SourceFiles
[Strings]
InstallPrompt=
DisplayLicense=$(Join-Path $stage 'License.txt')
FinishMessage=
TargetName=$setup
FriendlyName=RecLite $version Setup
AppLaunched=install.cmd
PostInstallCmd=<None>
AdminQuietInstCmd=
UserQuietInstCmd=
$fileStrings
[SourceFiles]
SourceFiles0=$stage\
[SourceFiles0]
$fileList
"@
$sedFile = Join-Path $stage 'reclite.sed'
Set-Content $sedFile $sed -Encoding ASCII

# IExpress fails on a quoted path, so it runs inside the staging folder and gets
# the bare file name. Its exit code is unreliable; the output file is the check.
Start-Process (Join-Path $env:WINDIR 'System32\iexpress.exe') -WorkingDirectory $stage `
  -ArgumentList '/N', '/Q', 'reclite.sed' -Wait -WindowStyle Hidden
if (-not (Test-Path $setup)) {
  throw 'IExpress did not create the installer.'
}

Remove-Item $stage -Recurse -Force
$size = [math]::Round((Get-Item $setup).Length / 1MB, 1)
Write-Host "Done: $setup ($size MB)"
