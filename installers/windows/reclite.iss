; RecLite Windows installer (Inno Setup 6). Build with installers\windows\build.ps1,
; which passes AppVersion and BuildNumber from pubspec.yaml.

#ifndef AppVersion
  #error Run installers\windows\build.ps1 (it sets AppVersion from pubspec.yaml).
#endif
#ifndef BuildNumber
  #define BuildNumber "0"
#endif

#define AppName "RecLite"
#define AppExe "RecLite.exe"
#define Publisher "RecLite"
#define RepoRoot "..\.."

[Setup]
; Never change AppId: Windows uses it to recognise upgrades of the same app.
AppId={{0385B57F-BA15-47CC-A6AA-6428278BEB1C}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher={#Publisher}
AppCopyright=© 2026 {#Publisher}. All rights reserved.
VersionInfoVersion={#AppVersion}.{#BuildNumber}
VersionInfoProductVersion={#AppVersion}
VersionInfoDescription={#AppName} {#AppVersion} Setup

; Installs for the current user: no admin prompt, no extra questions.
PrivilegesRequired=lowest
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes

; Windows Graphics Capture needs Windows 10 version 2004 (build 19041) or later.
MinVersion=10.0.19041
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

; Upgrades close a running RecLite first and keep the install folder.
CloseApplications=yes
RestartApplications=no

; The user must accept the license agreement before installing.
LicenseFile=..\LICENSE.txt

SetupIconFile={#RepoRoot}\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#AppExe}
UninstallDisplayName={#AppName} {#AppVersion}
WizardStyle=modern
WizardSmallImageFile={#RepoRoot}\assets\reclite_icon.png
Compression=lzma2/max
SolidCompression=yes

OutputDir=..\output
OutputBaseFilename={#AppName}-{#AppVersion}-windows-x64-setup

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#RepoRoot}\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "..\LICENSE.txt"; DestDir: "{app}"; DestName: "License.txt"

[Icons]
Name: "{autoprograms}\{#AppName}"; Filename: "{app}\{#AppExe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExe}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExe}"; Description: "{cm:LaunchProgram,{#AppName}}"; Flags: nowait postinstall skipifsilent

; Uninstalling never touches recordings or settings: they belong to the user.
