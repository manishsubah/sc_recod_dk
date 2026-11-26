# Installers

Scripts that turn a release build into **one file users install**. Each file is
named with the version from `pubspec.yaml` (`version: 2.0.1+2` → `2.0.1`), so
it's clear which version you are installing.

Users only ever get that one file (`.exe` on Windows, `.dmg` on Mac). It is
made with tools that come with the operating system — IExpress on Windows,
`hdiutil` on Mac — so nothing extra needs to be installed to build it.

`LICENSE.txt` is the End User License Agreement. Users must accept it before
the Windows installer continues; the Mac `.dmg` contains it as `License.txt`.
It is a general template: have it checked before a public release.

| Platform | Command | Result in `installers/output/` |
|---|---|---|
| Windows | `powershell -ExecutionPolicy Bypass -File installers\windows\build.ps1` | `RecLite-2.0.1-windows-x64-setup.exe` |
| macOS (on a Mac) | `installers/macos/build_dmg.sh` | `RecLite-2.0.1-macos.dmg` |

`installers/output/` is not committed to git: the files are 10–30 MB each and are
rebuilt from these scripts. Share them through GitHub Releases instead.

## Releasing a new version

1. Raise `version:` in `pubspec.yaml` (e.g. `2.0.2+3`) and the same numbers in
   `lib/core/constants/app_info.dart` (a test checks they match).
2. Run the script for each platform.
3. Install the result on a clean machine before sharing it.

## Windows

- Needs Flutter 3.47.1 and Visual Studio 2022 with C++. If an older Flutter comes
  first on `PATH`, pass `-Flutter C:\Users\<you>\DevFlutter\flutter_3.47.1\bin\flutter.bat`.
- What the user sees: double-click the `.exe` → license → **Yes** → RecLite opens.
  (**No** cancels; nothing is installed.)
- Installs to `%LOCALAPPDATA%\Programs\RecLite` for the current user without an
  admin prompt, adds Start menu and desktop shortcuts, and appears in
  Settings → Apps with its version.
- Running a newer version's `.exe` upgrades in place; the installed RecLite is
  closed first if it is running.
- Uninstall from Settings → Apps. It removes the app only; recordings and
  settings are kept.
- How it works: `build.ps1` zips the release build and packs it with
  `install.ps1` (copies files, shortcuts, Apps entry), `uninstall.ps1` and the
  license into one self-extracting `.exe` using Windows' built-in IExpress.
- Requires Windows 10 version 2004 or later (needed for screen capture).
- **Not code-signed yet**, so Windows SmartScreen warns on other PCs
  ("More info" → "Run anyway"). Signing needs a code-signing certificate.

## macOS

- Needs Flutter 3.47.1 and Xcode. The `.dmg` opens a window with RecLite and an
  Applications shortcut: drag RecLite onto Applications to install.
- **Ad-hoc signed only** (never the company Apple team). Other Macs block it at
  first launch until it is signed with a Developer ID and notarised; until then
  users right-click the app → Open.
