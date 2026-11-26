# Removes RecLite (started from Settings > Apps). Recordings and settings are kept.
param([switch]$Quiet)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms

$appName = 'RecLite'
$dest = Join-Path $env:LOCALAPPDATA "Programs\$appName"

if (-not $Quiet) {
  $answer = [System.Windows.Forms.MessageBox]::Show(
    "Remove $appName from this PC?`n`nYour recordings and settings are kept.",
    "Uninstall $appName", 'YesNo', 'Question')
  if ($answer -ne 'Yes') { exit 0 }
}

try {
  Get-Process -Name $appName -ErrorAction SilentlyContinue |
    Where-Object { $_.Path -and $_.Path.StartsWith($dest, [StringComparison]::OrdinalIgnoreCase) } |
    ForEach-Object {
      $_.CloseMainWindow() | Out-Null
      if (-not $_.WaitForExit(5000)) { $_ | Stop-Process -Force }
    }
  foreach ($folder in [Environment]::GetFolderPath('Programs'), [Environment]::GetFolderPath('Desktop')) {
    Remove-Item (Join-Path $folder "$appName.lnk") -Force -ErrorAction SilentlyContinue
  }
  Remove-Item "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\$appName" -Recurse -Force -ErrorAction SilentlyContinue
  # This script lives in the folder it deletes; it is already loaded, so that's fine.
  Set-Location $env:TEMP
  Remove-Item $dest -Recurse -Force
  if (-not $Quiet) {
    [System.Windows.Forms.MessageBox]::Show("$appName was removed.", "Uninstall $appName") | Out-Null
  }
} catch {
  if (-not $Quiet) {
    [System.Windows.Forms.MessageBox]::Show(
      "$appName could not be removed completely.`n`n$($_.Exception.Message)",
      "Uninstall $appName", 'OK', 'Error') | Out-Null
  }
  exit 1
}
