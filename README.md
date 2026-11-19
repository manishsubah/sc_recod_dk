# RecLite

Lightweight desktop screen recorder for **macOS 13+** and **Windows 10 (2004)+**.
Flutter UI, native recording engine (ScreenCaptureKit / Windows Graphics Capture + Media Foundation), MP4 output split into 15-minute parts.

Full design and roadmap: [docs/PLAN.md](docs/PLAN.md).

## Layout

```
lib/                      Flutter app (Bloc + GetIt, feature folders)
packages/reclite_engine/  Native engine plugin (Swift + C++), Pigeon contract in pigeons/
integration_test/         Tests that run against the real native engine
```

## Common commands

```bash
flutter run -d macos                      # run the app
flutter test                              # unit + widget tests
flutter test integration_test -d macos    # real-engine tests
```

After changing `packages/reclite_engine/pigeons/engine_api.dart`:

```bash
cd packages/reclite_engine && dart run pigeon --input pigeons/engine_api.dart
```
