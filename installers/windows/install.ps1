# Runs inside RecLite-<version>-windows-x64-setup.exe after the user accepts the
# license. Installs (or upgrades) RecLite for the current user: no admin needed.
# __VERSION__ is filled in by build.ps1.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms

$version = '__VERSION__'
$appName = 'RecLite'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$dest = Join-Path $env:LOCALAPPDATA "Programs\$appName"
$exe = Join-Path $dest "$appName.exe"
$uninstallKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\$appName"

function Show-Message([string]$text, [string]$icon = 'Information') {
  [System.Windows.Forms.MessageBox]::Show($text, "$appName $version", 'OK', $icon) | Out-Null
}

try {
  # Screen capture needs Windows 10 version 2004 (build 19041) or later.
  if ([Environment]::OSVersion.Version.Build -lt 19041) {
    Show-Message "$appName needs Windows 10 version 2004 or later." 'Warning'
    exit 1
  }

  # Upgrading: close a running RecLite first so its files can be replaced.
  Get-Process -Name $appName -ErrorAction SilentlyContinue |
    Where-Object { $_.Path -and $_.Path.StartsWith($dest, [StringComparison]::OrdinalIgnoreCase) } |
    ForEach-Object {
      $_.CloseMainWindow() | Out-Null
      if (-not $_.WaitForExit(5000)) { $_ | Stop-Process -Force }
    }

  # Replace the program files only; recordings and settings live elsewhere.
  if (Test-Path $dest) { Remove-Item $dest -Recurse -Force }
  New-Item -ItemType Directory -Path $dest -Force | Out-Null
  Expand-Archive -Path (Join-Path $here "$appName.zip") -DestinationPath $dest -Force
  Copy-Item (Join-Path $here 'License.txt') $dest -Force
  Copy-Item (Join-Path $here 'uninstall.ps1') $dest -Force

  $shell = New-Object -ComObject WScript.Shell
  foreach ($folder in [Environment]::GetFolderPath('Programs'), [Environment]::GetFolderPath('Desktop')) {
    $link = $shell.CreateShortcut((Join-Path $folder "$appName.lnk"))
    $link.TargetPath = $exe
    $link.WorkingDirectory = $dest
    $link.IconLocation = "$exe,0"
    $link.Description = "$appName screen recorder"
    $link.Save()
  }

  # Settings > Apps entry, with its version and an uninstaller.
  $uninstall = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$dest\uninstall.ps1`""
  $sizeKb = [int]((Get-ChildItem $dest -Recurse -File | Measure-Object Length -Sum).Sum / 1KB)
  New-Item -Path $uninstallKey -Force | Out-Null
  $values = @{
    DisplayName = $appName
    DisplayVersion = $version
    Publisher = $appName
    DisplayIcon = $exe
    InstallLocation = $dest
    UninstallString = $uninstall
    QuietUninstallString = "$uninstall -Quiet"
  }
  foreach ($name in $values.Keys) {
    New-ItemProperty -Path $uninstallKey -Name $name -Value $values[$name] -PropertyType String -Force | Out-Null
  }
  foreach ($name in 'NoModify', 'NoRepair') {
    New-ItemProperty -Path $uninstallKey -Name $name -Value 1 -PropertyType DWord -Force | Out-Null
  }
  New-ItemProperty -Path $uninstallKey -Name 'EstimatedSize' -Value $sizeKb -PropertyType DWord -Force | Out-Null

  Start-Process $exe
} catch {
  Show-Message "$appName could not be installed.`n`n$($_.Exception.Message)" 'Error'
  exit 1
}
