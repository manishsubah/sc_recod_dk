# RecLite — notes for Claude

Lightweight desktop screen recorder: Flutter UI + native engines (Swift on macOS, C++ on Windows), MP4 output split into 15-minute parts.

**Start here:** [docs/CONTINUE_ON_WINDOWS.md](docs/CONTINUE_ON_WINDOWS.md) (current status, setup, test checklist, next steps). Full design: [docs/PLAN.md](docs/PLAN.md).

## Current state (2026-11-19)
- macOS engine: Phase 1 done and tested on a real Mac (screen/area, system sound + mic, parts, pause, crash recovery).
- Windows engine: builds (warnings as errors) and records correctly on the user's Windows PC; 20-second parts, force-kill recovery and headphone switching are not yet checked there.
- Phase 3 started: save folder, History screen, Settings (split length, quality, frame rate, mouse pointer, theme) and global shortcuts (Ctrl+Alt+R / Ctrl+Alt+P, own engine code, not hotkey_manager), mini recording bar, tray icon and single-window recording are done. Phase 3 is complete; next is Phase 4 (long soak test, A/V sync, signing, installer).
- macOS Swift for Phase 3 (openPath, moveToTrash, showCursor, GlobalShortcuts, WindowController, TrayIcon, WindowCatalog) is written but not yet built on a Mac.
- Windows is the user's main platform. Use Flutter 3.47.1 (`C:\Users\manis\DevFlutter\flutter_3.47.1`); the older 3.32.7 on PATH can't resolve this project.

## Rules
- Code style and architecture: `.app-rules/rules/*.mdc` (domain is pure Dart, cubits talk to repositories only, design tokens from `lib/app/theme/app_tokens.dart`, `package:` imports, minimal comments).
- Engine contract: `packages/reclite_engine/pigeons/engine_api.dart`. After editing, run `dart run pigeon --input pigeons/engine_api.dart` in `packages/reclite_engine` and commit the generated files unformatted.
- Keep macOS and Windows engines behaving the same; the Swift engine is the tested reference.
- Before handing work back: `flutter analyze`, `flutter test`, and the portable C++ tests in `packages/reclite_engine/windows/test/`.
- **The user commits and pushes themselves.** Don't commit or push; suggest a commit message instead.
- Never configure the company (12th Wonder) Apple Developer team for signing; macOS debug builds stay ad-hoc signed.
