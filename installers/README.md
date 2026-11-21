# Installers

Scripts that turn a release build into **one file users install**. Each file is
named with the version from `pubspec.yaml` (`version: 0.1.0+1` → `0.1.0`), so
it's clear which version you are installing.

Users only ever get that one file (`.exe` on Windows, `.dmg` on Mac). Inno
Setup (Windows) and `hdiutil` (Mac) are build tools on the developer's machine
that pack the app into it; they are not shipped to or needed by users.

`LICENSE.txt` is the End User License Agreement. Users must accept it before
the Windows installer continues; the Mac `.dmg` contains it as `License.txt`.
It is a general template: have it checked before a public release.

| Platform | Command | Result in `installers/output/` |
|---|---|---|
| Windows | `powershell -ExecutionPolicy Bypass -File installers\windows\build.ps1` | `RecLite-0.1.0-windows-x64-setup.exe` |
| macOS (on a Mac) | `installers/macos/build_dmg.sh` | `RecLite-0.1.0-macos.dmg` |

`installers/output/` is not committed to git: the files are 10–30 MB each and are
rebuilt from these scripts. Share them through GitHub Releases instead.

## Releasing a new version

1. Raise `version:` in `pubspec.yaml` (e.g. `0.2.0+2`) and the same numbers in
   `lib/core/constants/app_info.dart` (a test checks they match).
2. Run the script for each platform.
3. Install the result on a clean machine before sharing it.

## Windows

- Needs Flutter 3.47.1, Visual Studio 2022 with C++, and Inno Setup 6
  (`winget install JRSoftware.InnoSetup`). If an older Flutter comes first on
  `PATH`, pass `-Flutter C:\Users\<you>\DevFlutter\flutter_3.47.1\bin\flutter.bat`.
- Steps the user sees: accept the license → choose the folder (pre-filled) →
  optional desktop icon → Install → launch RecLite.
- Installs for the current user without an admin prompt, adds a Start menu entry
  and appears in Settings → Apps with its version.
- Installing a newer version over an older one upgrades it in place; RecLite is
  closed first if it is running.
- Uninstalling removes the app only. Recordings and settings are kept.
- Requires Windows 10 version 2004 or later (needed for screen capture).
- **Not code-signed yet**, so Windows SmartScreen warns on other PCs
  ("More info" → "Run anyway"). Signing needs a code-signing certificate.

## macOS

- Needs Flutter 3.47.1 and Xcode. The `.dmg` opens a window with RecLite and an
  Applications shortcut: drag RecLite onto Applications to install.
- **Ad-hoc signed only** (never the company Apple team). Other Macs block it at
  first launch until it is signed with a Developer ID and notarised; until then
  users right-click the app → Open.
