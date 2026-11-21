# Continue RecLite on Windows

> **संकेत (quick hint):** Windows PC पर सबसे पहले **Step 1–3** करें (setup → build → test).
> अगर build में error आए, तो **Step 4** वाला prompt Claude को दें। उसके बाद ही **Phase 3** शुरू करें।
>
> **In short:** set up the PC (Step 1) → build and run (Step 2) → run the test checklist (Step 3) → fix what breaks (Step 4) → then continue with Phase 3 (Step 6).

Written 2026-11-19, when development moved from the Mac to a Windows PC. Full design: [PLAN.md](PLAN.md).

---

## 0. Where things stand

| Phase | macOS | Windows |
|---|---|---|
| 0 — Setup, app shell, CI | ✅ Done | ✅ Done |
| 1a — Screen / area → MP4 | ✅ Tested on a real Mac | 🔶 Code written, **never run** |
| 1b — System sound + mic | ✅ Tested on a real Mac | 🔶 Code written, **never run** |
| 1c — 15-min parts, pause, crash recovery | ✅ Tested (incl. a real force-kill) | 🔶 Code written, **never run** |
| 3 — History, Settings, shortcuts, mini bar | ⏳ Not started | ⏳ Not started |
| 4 — Long tests, signing, installer | ⏳ Not started | ⏳ Not started |

**Most important fact:** the Windows engine (`packages/reclite_engine/windows/`, ~4,700 lines of C++) was written on a Mac and has **never been compiled by the Windows compiler on a real machine**. The first CI build was queued when this guide was written (commit `9f5d6b5`, run `44548978599`). Expect a first round of compile errors. That is normal; Step 4 explains how to fix them.

What *was* verified on the Mac for the Windows engine:
- The audio mixer and timeline: 14 tests, all pass.
- `session.json` and the disk guard: 12 tests, all pass, including reading a real Mac `session.json`.

Both run in CI on every push.

---

## 1. Set up the Windows PC (once)

Needs **Windows 10 version 2004 (build 19041) or later**; Windows 11 is best (no yellow capture border).

1. **Git**: https://git-scm.com/download/win
2. **Visual Studio 2022** (Community is free): in the installer, tick **"Desktop development with C++"**. Make sure a **Windows 11 SDK** (or Windows 10 SDK 10.0.19041+) is selected on the right.
3. **Flutter 3.47.1 (stable)**: https://docs.flutter.dev/get-started/install/windows. Same version as the Mac and CI.
4. **ffmpeg** (to check recordings): `winget install Gyan.FFmpeg`
5. Optional: **Claude Code**, to continue with Claude on this PC.

Check it:
```powershell
flutter doctor -v
```
The **"Visual Studio – develop Windows apps"** line must be ✅. Android/Xcode lines don't matter.

Get the code:
```powershell
git clone https://github.com/manishsubah/sc_recod_dk.git
cd sc_recod_dk
flutter pub get
```
(If you already cloned it: `git pull`.)

---

## 2. Build and run

```powershell
flutter run -d windows
```

The first build takes a few minutes. If it fails, go to **Step 4**.

**Test mode with short parts** (debug builds only):
```powershell
$env:RECLITE_SEGMENT_SECONDS = "20"
flutter run -d windows
```
"Split every" on the home screen should then say **20 seconds**.

**Ready-made build from CI** (no Flutter needed): GitHub → **Actions** → latest run → **Artifacts** → `RecLite-windows-x64` → unzip → run `RecLite.exe`.
If it says `VCRUNTIME140.dll` is missing, install the "Microsoft Visual C++ Redistributable (x64)".

Recordings are saved straight into the save folder (default `%USERPROFILE%\Videos\RecLite`) as `RecLite_<date>_<time>.mp4`, or `…_Part01.mp4`, `_Part02.mp4`… for long ones. Their manifests are in `%LOCALAPPDATA%\RecLite\Sessions`.

---

## 3. Test checklist on Windows

Do these in order. Each one matches a test that already passed on the Mac. Check every file with ffprobe:

```powershell
ffprobe -v error -show_entries stream=codec_type,codec_name,width,height,duration -of compact "path\to\Part01.mp4"
ffmpeg -v error -i "path\to\Part01.mp4" -f null -   # no output = decodes cleanly
```

| # | Test | Expected |
|---|---|---|
| 1 | Open the app | "Ready to Record"; System shows your Windows version; Hardware encoding lists H.264 |
| 2 | Screen picker | Your monitors with real names, main one marked "Main" |
| 3 | Full screen, 10 s, **System sound off** | `Part01.mp4`, H.264, ≤1440 p, decodes cleanly, length ≈ what the timer showed |
| 4 | Area: drag a rectangle | Screen dims, size label follows the mouse, Esc cancels; red outline while recording; file size = the rectangle (scaled down if taller than 1440) |
| 5 | System sound on, play a YouTube video | Video + `aac` audio; audio length ≈ video length; the meter moves |
| 6 | Microphone on, talk | Mic meter moves; your voice is in the file |
| 7 | Pause 10 s, then Resume | Bar shows PAUSED, timer stops; paused time isn't in the file |
| 8 | Test mode 20 s, record ~50 s | Part 1 → 2 → 3 in the bar; 3 files of 20 / 20 / ~10 s; `session.json` says `"completed"` |
| 9 | Crash: while recording, run `taskkill /F /IM RecLite.exe` | Finished parts are intact; reopen → "RecLite recovered a recording" banner; the unfinished part is now a playable `.mp4`; `session.json` says `"recovered"` |
| 10 | Unplug or switch headphones while recording | Recording continues; sound comes from the new device |
| 11 | RecLite window visible on the recorded screen | The RecLite window does **not** appear in the video |

---

## 4. When something breaks — what to tell Claude

Open Claude Code in the project folder and paste:

> Read `CLAUDE.md` and `docs/CONTINUE_ON_WINDOWS.md`. We moved RecLite development from a Mac to this Windows PC. The Windows engine in `packages/reclite_engine/windows/` was written on the Mac and never compiled here. Run `flutter run -d windows`, fix every compile/link error, then go through the Step 3 test checklist with me and fix what fails. Keep the same behaviour as the macOS engine (`packages/reclite_engine/macos/`). Don't commit; I commit myself.

You can also send the CI log of a failed run:
```powershell
gh run view --log-failed
```

### Where problems are most likely (check these first)

| Area | File | Risk |
|---|---|---|
| First compile | everything in `windows/` | Header order (`core/win.h` must come first), C++/WinRT (`windowsapp.lib`, `/bigobj`), MSVC warnings (`/WX-` is set for now) |
| Exceptions | `windows/CMakeLists.txt` | Flutter sets `_HAS_EXCEPTIONS=0`; we override it to 1 for C++/WinRT. Check the build accepts that |
| GPU textures | `capture/frame_converter.cpp` | `D3D11_BIND_VIDEO_ENCODER` fallback; the video processor colour space (colours look wrong → fix here) |
| Encoder | `writer/segment_writer.cpp` | PCs without a hardware H.264 encoder (software fallback is untested); fragmented MP4 container attribute |
| Audio | `audio/wasapi_source.cpp` | `AUTOCONVERTPCM` on old drivers; loopback sends nothing during silence (the mixer fills it) |
| Area units | `engine/recording_engine.cpp` | On Windows the area is in **physical pixels** (macOS uses points). The label shows pixels |
| Recovery | `storage/session_storage.cpp` | Reading a crashed fragmented MP4's length (falls back to reading all samples) |
| Threads | `core/platform_dispatcher.*`, `core/serial_queue.*` | Pigeon replies/events must run on the platform thread (they do, via the dispatcher) |

When the engine is stable, remove `/WX-` in `packages/reclite_engine/windows/CMakeLists.txt` so warnings fail the build again.

---

## 5. Code map

| Layer | Where | Notes |
|---|---|---|
| Flutter UI | `lib/features/recording/presentation/` | Pages, widgets, Blocs/Cubits |
| Domain (pure Dart) | `lib/features/recording/domain/` | Entities + repository interfaces |
| Data | `lib/features/recording/data/` | Calls the engine plugin |
| Engine contract | `packages/reclite_engine/pigeons/engine_api.dart` | **Single source of truth** for Dart ↔ native |
| macOS engine | `packages/reclite_engine/macos/reclite_engine/Sources/reclite_engine/` | Swift, tested; the reference behaviour |
| Windows engine | `packages/reclite_engine/windows/` | C++, see below |
| Plan / design | `docs/PLAN.md` | Full plan, phases, acceptance criteria |
| Code rules | `.app-rules/rules/*.mdc` | Architecture, comments, design tokens, state, testing |

Windows engine files:
```
windows/
├── reclite_engine_plugin.*   Pigeon host API → RecordingEngine
├── engine/recording_engine.* Lifecycle, timers, events, disk guard (platform thread)
├── capture/                  Monitors, D3D11 device, Windows Graphics Capture, BGRA→NV12
├── audio/                    WASAPI loopback + mic, mixer, timeline, level meter
├── writer/                   Media Foundation MP4 part writer, multi-part recorder
├── storage/                  session.json, naming, crash recovery, disk guard
├── ui/                       Area overlay + red outline (Win32)
├── core/                     Serial queue, platform-thread dispatcher, clock, strings
└── test/                     Portable C++ tests (run in CI)
```

---

## 6. Next steps after Windows works

1. **Finish Phase 2:** all 11 checks in Step 3 pass, then turn warnings-as-errors back on (remove `/WX-`).
2. **Phase 3 (product features)**, for both platforms:
   - Choose the save folder (**Browse**) and remember it (`file_selector`, `shared_preferences`)
   - **History** screen, reading `session.json` files: Play, Show in folder, Move to Recycle Bin
   - **Settings:** part length (5/10/15/30/60 min), quality, fps, cursor on/off, theme
   - **Global shortcuts:** start/stop and pause
   - **Mini recording bar**, plus a tray icon
   - **Window capture** (one app window)
3. **Phase 4:**
   - A 4–8 h soak test watching memory in Task Manager
   - A/V sync check
   - Code signing and an installer (MSIX or Inno Setup)

---

## 7. Rules that still apply

- **Engine contract changes:** edit `pigeons/engine_api.dart`, then regenerate from `packages/reclite_engine`:
  ```powershell
  dart run pigeon --input pigeons/engine_api.dart
  ```
  Commit the generated files **as they are**; never format `*.g.dart`. CI fails if they're out of date.
- **Before every commit:**
  ```powershell
  flutter analyze
  flutter test
  ```
- **Portable C++ tests** (in a "Developer PowerShell for VS 2022", from `packages/reclite_engine/windows`):
  ```powershell
  cl /std:c++17 /EHsc /nologo /I. test\audio_mixer_test.cpp audio\audio_mixer.cpp audio\audio_pipeline.cpp /Fe:audio_test.exe; .\audio_test.exe
  cl /std:c++17 /EHsc /nologo test\storage_test.cpp storage\session_manifest.cpp storage\disk_guard.cpp /Fe:storage_test.exe; .\storage_test.exe
  ```
- **Recording logic changes** (parts, pause, recovery, audio) must keep **both** engines behaving the same. The macOS Swift version is the tested reference.
- **Signing:** the Mac uses ad-hoc signing only. Never use the company (12th Wonder) Apple account for this project.
- **Commits:** you commit and push yourself; Claude suggests the message.
