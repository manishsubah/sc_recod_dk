# RecLite — notes for Claude

Lightweight desktop screen recorder: Flutter UI + native engines (Swift on macOS, C++ on Windows), MP4 output split into 15-minute parts.

**Start here:** [docs/CONTINUE_ON_WINDOWS.md](docs/CONTINUE_ON_WINDOWS.md) (current status, setup, test checklist, next steps). Full design: [docs/PLAN.md](docs/PLAN.md).

## Current state (2026-11-19)
- macOS engine: Phase 1 done and tested on a real Mac (screen/area, system sound + mic, parts, pause, crash recovery).
- Windows engine (`packages/reclite_engine/windows/`): same features, written on the Mac, **not yet compiled or run on Windows**. First job on a Windows PC: build, fix compile errors, run the checklist in CONTINUE_ON_WINDOWS.md §3.
- Windows is the user's main platform.

## Rules
- Code style and architecture: `.app-rules/rules/*.mdc` (domain is pure Dart, cubits talk to repositories only, design tokens from `lib/app/theme/app_tokens.dart`, `package:` imports, minimal comments).
- Engine contract: `packages/reclite_engine/pigeons/engine_api.dart`. After editing, run `dart run pigeon --input pigeons/engine_api.dart` in `packages/reclite_engine` and commit the generated files unformatted.
- Keep macOS and Windows engines behaving the same; the Swift engine is the tested reference.
- Before handing work back: `flutter analyze`, `flutter test`, and the portable C++ tests in `packages/reclite_engine/windows/test/`.
- **The user commits and pushes themselves.** Don't commit or push; suggest a commit message instead.
- Never configure the company (12th Wonder) Apple Developer team for signing; macOS debug builds stay ad-hoc signed.
