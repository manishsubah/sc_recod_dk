# RecLite — Project Plan

> **Record. Save. Share.**
> A lightweight desktop screen recorder for macOS and Windows, built with Flutter and native recording engines.

This document explains **what** we are building, **how** it works, and **in what order** we will build it. Each section starts with a plain-language explanation, followed by the technical details.

---

## Table of Contents

1. [What is RecLite?](#1-what-is-reclite)
2. [Name, Copyright and Legal Checks](#2-name-copyright-and-legal-checks)
3. [Fixes to the Original Spec](#3-fixes-to-the-original-spec)
4. [Supported Platforms](#4-supported-platforms)
5. [The Big Picture (Architecture)](#5-the-big-picture-architecture)
6. [Technology Stack](#6-technology-stack)
7. [Project Folder Structure](#7-project-folder-structure)
8. [The Recording Engine (Core)](#8-the-recording-engine-core)
9. [Automatic 15-Minute Segments](#9-automatic-15-minute-segments)
10. [Crash Safety](#10-crash-safety)
11. [macOS Engine Details](#11-macos-engine-details)
12. [Windows Engine Details](#12-windows-engine-details)
13. [Audio: System Sound + Microphone](#13-audio-system-sound--microphone)
14. [Flutter ↔ Native Communication](#14-flutter--native-communication)
15. [Flutter App Design](#15-flutter-app-design)
16. [Storage, Files and Disk Space](#16-storage-files-and-disk-space)
17. [Recording History](#17-recording-history)
18. [Permissions](#18-permissions)
19. [Error Handling](#19-error-handling)
20. [Performance Rules](#20-performance-rules)
21. [User Interface](#21-user-interface)
22. [Development Phases](#22-development-phases)
23. [Testing Plan](#23-testing-plan)
24. [Distribution and Packaging](#24-distribution-and-packaging)
25. [Open Decisions](#25-open-decisions)
26. [Acceptance Criteria (Definition of Done)](#26-acceptance-criteria-definition-of-done)
27. [Glossary](#27-glossary)

---

## 1. What is RecLite?

**In simple words:** RecLite records your computer screen and the sound playing on it (for example a Zoom meeting, an online class, or a YouTube tutorial). It saves the recording as normal MP4 video files that play anywhere. Long recordings are automatically cut into 15-minute pieces, so if something goes wrong, you only lose a few seconds — never the whole recording.

**Main goals**

| Goal | What it means |
|---|---|
| Lightweight | Uses little memory (RAM) and little CPU, even after hours of recording |
| Reliable | Keeps recording without the user touching anything |
| Safe | Finished parts are always playable, even after a crash or power cut |
| Simple | One big "Start Recording" button; sensible defaults |
| Standard output | MP4 files (H.264 video + AAC audio) |

**Main use cases:** meetings, online classes, presentations, demos, live sessions.

---

## 2. Name, Copyright and Legal Checks

**In simple words:** Nothing in the idea copies anybody's work. Screen recorders are a common type of app. The two things to check are the **name** (trademark) and the **logo**.

### 2.1 Name "RecLite"

A name is protected by **trademark**, not copyright. We cannot confirm it is free without searching. Before publishing, check:

- [ ] USPTO trademark search (USA) — https://tmsearch.uspto.gov
- [ ] EUIPO (Europe) — https://euipo.europa.eu/eSearch
- [ ] WIPO Global Brand Database — https://branddb.wipo.int
- [ ] Mac App Store and Microsoft Store (search "RecLite")
- [ ] Domain name (e.g. `reclite.app`) and GitHub organisation
- [ ] Keep 1–2 backup names ready in case "RecLite" is taken

### 2.2 Logo

- The camera-in-brackets icon is a generic idea and is fine.
- Because the mockup was AI-generated, do a **reverse image search** (Google Images / TinEye) to make sure it does not closely match an existing app icon.

### 2.3 Video codec licensing

- H.264 video and AAC audio are covered by patents.
- **We use the encoders built into the operating system** (Apple VideoToolbox, Microsoft Media Foundation). Apple and Microsoft already pay those licences, so we do not have to.
- **Do not bundle FFmpeg.** Its licences (LGPL/GPL) and codec patents create legal risk for a closed-source app.

### 2.4 Third-party packages

- Use only packages with permissive licences (MIT, BSD, Apache-2.0).
- Keep a `THIRD_PARTY_NOTICES` file listing them.

---

## 3. Fixes to the Original Spec

The original requirements had a few contradictions. These are the agreed corrections:

| # | Problem in original spec | Decision |
|---|---|---|
| 1 | Says "5-minute segments" in one place and "15 minutes" elsewhere | **15 minutes** is the default. Make it configurable later (5 / 10 / 15 / 30 / 60). |
| 2 | Example files are named `VeyraCast_...` | Use **`RecLite_...`** |
| 3 | File names had no seconds (`_1000_`) → two recordings in the same minute would clash | Use `RecLite_2026-11-19_10-00-00_Part01.mp4` |
| 4 | "Each segment ≈ 15 minutes" is unclear when the user pauses | A segment = **15 minutes of recorded video**. Paused time does not count. |
| 5 | The mockup shows Flutter plugins `screen_capture` and `flutter_sound` | **Not used.** All capture is done in our own native engine. |
| 6 | The mockup says "BLoC / Riverpod" | Use **flutter_bloc + get_it** only. Do not mix in Riverpod. |
| 7 | "Record a specific window" + "system audio" | System audio = **all** computer sound, not just that window. Per-app audio is a future feature. |
| 8 | "Delete recordings" | **Move to Trash / Recycle Bin**, not permanent delete. |
| 9 | Typo "interrial" in the mockup | "internal" |

---

## 4. Supported Platforms

| Platform | Minimum version | Why |
|---|---|---|
| macOS | **13 Ventura** | First version where ScreenCaptureKit can record system audio |
| Windows | **10 version 2004 (build 19041)** | Needed for stable Windows Graphics Capture with cursor control |

Notes:

- macOS microphone capture through ScreenCaptureKit needs macOS 15. On macOS 13–14 we capture the mic separately (see §13).
- On Windows 10, a thin yellow border appears around the captured area. Windows 11 lets us hide it.
- **Development note:** macOS code is built on a Mac. Windows code must be built on a **Windows PC or a Windows VM**. Plan for this early.

---

## 5. The Big Picture (Architecture)

**In simple words:** The app has two halves.

1. **The Flutter app (the face):** buttons, settings, history list. It only *tells* the engine what to do and *shows* what the engine reports.
2. **The native engine (the muscles):** written in Swift (Mac) and C++ (Windows). It grabs the screen, grabs the sound, compresses the video using the graphics card, and writes MP4 files straight to disk.

Video frames **never** travel into Flutter. Flutter only gets small messages like "recording, 00:12:34, part 1".

```
┌──────────────────────────────────────────────────────────────┐
│                     FLUTTER APP (Dart)                       │
│                                                              │
│   UI pages ──► Blocs / Cubits ──► Repositories               │
│                                       │                      │
│                          RecordingPlatform (Dart API)        │
└───────────────────────────────────────┼──────────────────────┘
          commands (Pigeon)  ▼          ▲  events (EventChannel)
          start/stop/pause              │  status, time, levels, errors
┌───────────────────────────────────────┼──────────────────────┐
│                NATIVE ENGINE (Swift / C++)                   │
│                                                              │
│  Screen Capture ─┐                                           │
│                  ├─► Sync Clock ─► Encoder (GPU) ─► Segment  │
│  System Audio ───┤                 H.264 + AAC     Manager   │
│  Microphone ─────┘   (Audio Mixer)                   │       │
│                                                      ▼       │
│                                        Fragmented MP4 files  │
│                                        + session.json        │
└──────────────────────────────────────────────────────────────┘
                                │
                                ▼
                        Disk (user's folder)
```

### Data flow in one sentence

Screen frame → (stays on the GPU) → hardware encoder → small compressed packets → written to the current MP4 file → every 15 minutes, a new file is started.

---

## 6. Technology Stack

### 6.1 Flutter side

| Area | Choice | Why |
|---|---|---|
| Framework | Flutter (stable, currently 3.47) + Dart 3.13 | One UI codebase for Mac and Windows |
| Design | Material 3 with a custom theme | Modern look, light & dark mode |
| State management | `flutter_bloc` | Recording is a clear state machine; Bloc models this well and is easy to test |
| Dependency injection | `get_it` | Simple service locator |
| Native API bindings | `pigeon` | Generates type-safe Dart ↔ Swift ↔ C++ code (no hand-written string channel names) |
| Window control | Native (Swift / Win32) for now; re-evaluate `window_manager` in Phase 3 | Window size, mini always-on-top indicator |
| Global shortcuts | `hotkey_manager` | Start/stop even when the app is not focused |
| Tray / menu bar | `tray_manager` | Hide the main window while recording |
| Folder picker | `file_selector` | Official package for choosing an output folder |
| Settings storage | `shared_preferences` | Small key/value settings |
| Open files/folders | `url_launcher` | Open MP4 in default player, reveal folder |
| Equality / models | `equatable` (or `freezed`) | Clean state classes |
| Tests | `bloc_test`, `mocktail` | Unit tests for Blocs and repositories |

### 6.2 Native side

| Job | macOS | Windows |
|---|---|---|
| Screen capture | ScreenCaptureKit (`SCStream`) | Windows Graphics Capture (WGC) |
| System audio | ScreenCaptureKit audio | WASAPI loopback |
| Microphone | `AVAudioEngine` (13–14) / SCK mic (15+) | WASAPI capture |
| Video encoding | VideoToolbox (via `AVAssetWriter`) | Media Foundation hardware MFT (NVIDIA NVENC / Intel QuickSync / AMD AMF) |
| MP4 writing | `AVAssetWriter` (fragmented) | `IMFSinkWriter` (fragmented MP4 container) |
| Colour conversion | Done by ScreenCaptureKit on GPU | `ID3D11VideoProcessor` on GPU |
| Language | Swift | C++17 (C++/WinRT for WGC) |

### 6.3 Not used (on purpose)

- ❌ FFmpeg — licence and patent risk, large binary.
- ❌ Dart FFI for frames — frames never go to Dart.
- ❌ Flutter screen-capture/audio plugins — not efficient enough, not controllable enough.
- ❌ Riverpod — one state solution only (Bloc).
- ❌ A database — a small JSON file per recording is enough (see §17).

---

## 7. Project Folder Structure

**In simple words:** The Flutter app and the native engine live in one repository, but the engine is its own package. This keeps the app code clean and lets us test the engine on its own.

```
screen_recorder/
├── docs/
│   └── PLAN.md                    ← this file
├── lib/                           ← Flutter app
│   ├── main.dart
│   ├── app/
│   │   ├── app.dart               ← MaterialApp, theme, routes
│   │   ├── di.dart                ← GetIt registrations
│   │   ├── router/
│   │   └── theme/
│   ├── core/
│   │   ├── constants/
│   │   ├── errors/                ← Failure types
│   │   ├── extensions/
│   │   └── utils/                 ← formatters (duration, bytes)
│   └── features/
│       ├── recording/             ← start/pause/stop, live status
│       │   ├── data/
│       │   ├── domain/
│       │   └── presentation/
│       ├── sources/               ← displays, windows, audio devices
│       ├── history/               ← past recordings
│       └── settings/              ← folder, segment length, shortcuts, quality
├── packages/
│   └── reclite_engine/            ← native engine as a Flutter plugin
│       ├── pigeons/
│       │   └── engine_api.dart    ← API definition (source for codegen)
│       ├── lib/                   ← generated Dart API + small wrapper
│       ├── macos/
│       │   └── Classes/
│       │       ├── Engine/        ← RecordingEngine (lifecycle, state)
│       │       ├── Capture/       ← ScreenCaptureKit, mic
│       │       ├── Audio/         ← mixer, resampler, level meter
│       │       ├── Writer/        ← SegmentWriter, SegmentManager
│       │       └── Storage/       ← manifest, disk monitor, recovery
│       └── windows/
│           ├── engine/
│           ├── capture/           ← WGC, D3D11
│           ├── audio/             ← WASAPI loopback, mic, mixer
│           ├── writer/            ← Media Foundation sink writer, segments
│           └── storage/
├── macos/                         ← Flutter macOS runner
├── windows/                       ← Flutter Windows runner (to be added)
└── test/
```

### Simplifications compared to the original spec

- `audio` and `storage` are **not** separate features. Audio toggles are part of `recording`/`sources`; storage is part of `settings` and the engine.
- **Use-case classes only where they add logic.** If a use case would just call one repository method, skip it and call the repository from the Bloc.
- The spec's `native/macos/...` folders become `packages/reclite_engine/macos/...` — same idea, proper Flutter plugin layout.
- The `android/`, `ios/` and `web/` folders from the template can be removed.

---

## 8. The Recording Engine (Core)

**In simple words:** The engine is a small machine with a few parts. Each part does one job and passes its output to the next part. Nothing piles up in memory: if the disk or encoder is slow, the engine drops a frame instead of storing it.

### 8.1 Engine parts

| Part | Job |
|---|---|
| **RecordingEngine** | Owns the whole session: start, pause, resume, stop, errors. Single source of truth for state. |
| **ScreenSource** | Gives a stream of screen frames (GPU textures) with timestamps. |
| **AudioSource(s)** | System audio and microphone, each with timestamps. |
| **AudioMixer** | Converts all audio to one format and mixes it into one track. |
| **SessionClock** | One master clock. Every frame and audio sample gets a time from it. Handles pause offsets. |
| **SegmentWriter** | Encodes and writes one MP4 file. |
| **SegmentManager** | Decides when to close the current file and start the next one. |
| **DiskMonitor** | Checks free space regularly. |
| **ManifestWriter** | Keeps `session.json` up to date (list of parts, durations, sizes). |
| **EventEmitter** | Sends small status messages to Flutter. |

### 8.2 Engine states

```
           start()                 pause()
  IDLE ──────────► STARTING ──► RECORDING ◄──────► PAUSED
    ▲                  │            │      resume()   │
    │                  ▼            ▼ stop()          │ stop()
    │               ERROR       STOPPING ◄────────────┘
    │                  │            │
    └──────────────────┴────────────┘
```

- Only valid transitions are allowed. For example, `pause()` while `IDLE` is ignored and reports an error.
- `STOPPING` waits until the last file is safely finished before going back to `IDLE`.

### 8.3 Threads (who does what)

| Thread / queue | Work |
|---|---|
| Capture callback | Receives frames. Must return fast. Only hands off the frame. |
| Audio callback | Receives audio. Resample + mix, hand off. |
| Writer queue (serial) | Appends samples to the current writer. |
| Finalize queue | Finishes the old segment file in the background. |
| Main / platform thread | Talks to Flutter only. |

### 8.4 Default recording settings

| Setting | Default | Options |
|---|---|---|
| Resolution | Native, capped at 1440p | 720p / 1080p / 1440p / Native |
| Frame rate | 30 fps | 15 / 24 / 30 / 60 |
| Video codec | H.264 (most compatible) | H.264 / HEVC (smaller files) |
| Frame timing | Variable (no new frame when the screen is still) | — |
| Video bitrate | Quality-based, capped (~6 Mbps max @1080p30) | Low / Medium / High |
| Keyframe interval | 2 seconds | — |
| Audio | AAC, 48 kHz, stereo, 160 kbps | — |
| Segment length | 15 minutes | 5 / 10 / 15 / 30 / 60 (later) |
| Cursor | Shown | Show / Hide |

Rough file size: see §8.5.4.

### 8.5 Video Format Decision

**In simple words:** We keep **MP4**. MP4 is only the "box" (container); what makes a file big or small is the **codec** inside the box and the recording settings. MP4 with H.264 plays on every computer, phone, browser and editor, and the fragmented version is crash-safe.

#### 8.5.1 Container comparison

| Container | Plays everywhere? | Crash-safe? | Verdict |
|---|---|---|---|
| **MP4 (fragmented)** | ✅ Mac, Windows, phones, browsers, editors, WhatsApp, YouTube | ✅ | **Chosen** |
| MKV | ❌ No QuickTime/iPhone; some editors refuse it | ✅ | Compatibility too limited |
| WebM | ❌ Weak on Apple; no practical hardware encoder | ✅ | Made for the web, not recording |
| MOV | ⚠️ Mostly Apple | ⚠️ | No advantage over MP4 |

Fragmented MP4 gives the crash safety MKV is known for, while keeping MP4's compatibility.

#### 8.5.2 Codec comparison (what goes inside the MP4)

| Codec | File size | Plays everywhere? | Hardware encoding | Decision |
|---|---|---|---|---|
| **H.264** | Baseline (100%) | ✅ Everywhere | ✅ Every Mac and PC | **Default** |
| **HEVC (H.265)** | ~40–50% smaller | ⚠️ Mac/iPhone fine; Windows may need the $0.99 "HEVC Video Extensions" to play | ✅ Apple Silicon, most PCs since ~2016 | **Optional "Smaller files" mode** |
| AV1 | ~50–60% smaller | ⚠️ Newer devices only | ❌ No Mac encodes it; only new GPUs (NVIDIA RTX 40+, Intel Arc, AMD RX 7000) | Future version |
| VP9 | ~40% smaller | ⚠️ Poor on Apple | ❌ Rarely available | Not used |

Audio: **AAC-LC**, 48 kHz stereo, 128–160 kbps. Plays everywhere; tiny compared to video.

**Final choice:**

- **Default:** Fragmented MP4 + **H.264 High profile** + **AAC-LC**.
- **Setting:** "Smaller files (HEVC)" with a note: *"May need a free/cheap codec on some Windows PCs."*
- **Future:** AV1 when hardware encoding is common on both platforms (including Mac).

#### 8.5.3 How we keep files light (more important than the codec)

1. **Variable frame rate:** ScreenCaptureKit and Windows Graphics Capture only send a frame when the screen changes. A still slide costs almost nothing. (macOS: skip frames whose `SCFrameStatus` is `.idle`; Windows: WGC only fires on change.)
2. **Quality-based bitrate with a cap:** the encoder uses few bits for simple content (slides, code) and more only for motion. macOS: `AVVideoQualityKey` / average bitrate + `AVVideoExpectedSourceFrameRateKey`; Windows: `eAVEncCommonRateControlMode_Quality` (or `PeakConstrainedVBR`) with a max bitrate.
3. **Resolution cap (1080p / 1440p):** recording a 5K Retina screen at full size gives huge files with no visible benefit. Scaling is done on the GPU.
4. **30 fps by default:** 15 fps is enough for slides and classes (about half the size). 60 fps only for motion-heavy content.
5. **2-second keyframe interval:** good balance between file size and fast seeking.
6. **Audio 128–160 kbps:** clear speech and music for meetings and classes.

#### 8.5.4 Expected size per 15-minute part

| Content | H.264 | HEVC |
|---|---|---|
| Slides / meetings (1080p30) | ~150–300 MB | ~80–170 MB |
| Mixed / video playback (1080p30) | ~500–700 MB | ~300–400 MB |
| Slides / classes (1080p15) | ~100–200 MB | ~60–120 MB |

These are estimates; real numbers will be measured in Phase 4 and used for the "estimated recording time left" display (§16).

---

## 9. Automatic 15-Minute Segments

**In simple words:** Every 15 minutes, the app closes the current video file and immediately starts a new one. There is no gap and no lost sound between files. Each file plays on its own.

### 9.1 Example

Recording starts at 10:00:00:

```
Recordings/
└── RecLite_2026-11-19_10-00-00/
    ├── RecLite_2026-11-19_10-00-00_Part01.mp4
    ├── RecLite_2026-11-19_10-15-00_Part02.mp4
    ├── RecLite_2026-11-19_10-30-00_Part03.mp4
    ├── RecLite_2026-11-19_10-45-00_Part04.mp4
    └── session.json
```

If the user pauses for 5 minutes during Part02, Part03 starts at about 10:35 (the name uses the real clock time when that part started).

### 9.2 How the switch works (technical)

1. **Pre-warm:** About 10 seconds before the boundary, create the next writer (file opened, encoder ready). This avoids a hiccup at the switch.
2. **Cut point:** The boundary time `T` = segment start + 15:00 of *recorded* time.
3. **Route by timestamp:**
   - Video frames with time `< T` → old writer.
   - Video frames with time `≥ T` → new writer. The new writer's first frame is always a keyframe, so the file plays on its own.
4. **Split audio exactly:** The audio buffer that crosses `T` is cut into two pieces — the first piece goes to the old file, the second to the new file. No gap, no overlap, so sound stays in sync.
5. **Finish old file in the background:** The old writer is finalised on a separate queue, so recording never waits.
6. **Rename:** `Part01.mp4.part` → `Part01.mp4` when finalisation succeeds.
7. **Update manifest:** Add the finished part to `session.json`.
8. **Notify Flutter:** `segmentCompleted` event with part number, path, duration, size.

### 9.3 Rules

- Segment timing uses **recorded media time**, not wall-clock time.
- If the user pauses across a boundary, the switch happens after resume when 15:00 of media is reached.
- If creating the next file fails (e.g., disk full), the engine finishes the current part safely, then stops with an error.

---

## 10. Crash Safety

**In simple words:** A normal MP4 file has its "table of contents" written at the very end. If the app crashes before the end, the file is broken. We use a special kind of MP4 (**fragmented MP4**) that writes a small table of contents every few seconds. So even if the computer loses power, the current part is playable up to the last few seconds.

### 10.1 Protection layers

| Layer | What it protects | How |
|---|---|---|
| 1. Segments | Older parts | Each finished part is a complete, closed file |
| 2. Fragmented MP4 | Current part | A fragment is written every ~5 s; lose at most ~5 s |
| 3. `.part` file name | Clarity | Unfinished file is named `...Part03.mp4.part` until done |
| 4. `session.json` | Knowing what exists | Updated after every finished part (written to a temp file, then renamed — atomic) |
| 5. Startup recovery | Leftovers after a crash | On launch, find `.part` files, try to repair/rename them, mark the session as "recovered" |

### 10.2 Technical notes

- macOS: `AVAssetWriter.movieFragmentInterval = CMTime(seconds: 5)`.
- Windows: Sink Writer with `MF_TRANSCODE_CONTAINERTYPE = MFTranscodeContainerType_FMPEG4`.
- Fragmented MP4 plays in QuickTime, VLC, Windows Media Player, browsers and editors.
- Optional "make standard MP4" button later (re-mux without re-encoding) for tools that dislike fragmented files.

---

## 11. macOS Engine Details

### 11.1 Screen capture (ScreenCaptureKit)

- Get lists with `SCShareableContent` → displays, windows, apps (sent to Flutter for the source picker).
- Build an `SCContentFilter`:
  - Full display, **excluding RecLite's own windows** (so the app UI is not in the video).
  - Or a single window.
- `SCStreamConfiguration`:
  - `width/height` = target size → **the GPU scales** big Retina screens down for free.
  - `pixelFormat = kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange` (NV12) → the encoder's native format, so no colour conversion on the CPU.
  - `minimumFrameInterval = 1/30 s`.
  - `queueDepth = 5` → at most 5 frames in flight (bounded memory).
  - `showsCursor = true/false`.
  - `capturesAudio = true`, `sampleRate = 48000`, `channelCount = 2`, `excludesCurrentProcessAudio = true`.
- Frames arrive as `CMSampleBuffer` with an IOSurface-backed `CVPixelBuffer` → passed directly to the writer (**zero copy**).
- Skip frames whose `SCFrameStatus` is not `.complete` (idle/blank frames).

### 11.2 Encoding and writing (AVAssetWriter)

- One `AVAssetWriter` per segment, file type `.mp4`.
- Video input: H.264 (or HEVC), average bitrate, `AVVideoMaxKeyFrameIntervalDurationKey = 2`, `expectsMediaDataInRealTime = true`. AVAssetWriter uses the VideoToolbox hardware encoder automatically.
- Audio input: AAC 48 kHz stereo.
- `movieFragmentInterval` set for crash safety.
- If `isReadyForMoreMediaData == false`, **drop the video frame** (never queue it) and count it in stats.

### 11.3 Microphone

- macOS 15+: `SCStreamConfiguration.captureMicrophone = true` (one clock with screen).
- macOS 13–14: `AVAudioEngine` input node; timestamps converted to the same host-time clock.

### 11.4 Pause

- Keep the `SCStream` running (restarting is slow and may show permission prompts).
- While paused, drop all incoming samples.
- On resume, add the paused duration to a `pauseOffset` and subtract it from every later timestamp so the video has no gap.

### 11.5 macOS specifics

- Add `NSMicrophoneUsageDescription` to `Info.plist`.
- Screen Recording permission: check with `CGPreflightScreenCaptureAccess()`, request with `CGRequestScreenCaptureAccess()`. The user may need to **restart the app** after granting.
- Prevent sleep during recording with `ProcessInfo.beginActivity(.userInitiated, .idleSystemSleepDisabled)`.
- If App Sandbox is enabled: use **security-scoped bookmarks** to remember the chosen output folder across launches.

---

## 12. Windows Engine Details

### 12.1 Screen capture (Windows Graphics Capture)

- Create `GraphicsCaptureItem` from a monitor (`HMONITOR`) or window (`HWND`) via `IGraphicsCaptureItemInterop`.
- `Direct3D11CaptureFramePool::CreateFreeThreaded(device, B8G8R8A8, 2 buffers, size)` → only 2 frames in flight (bounded memory).
- Settings: `IsCursorCaptureEnabled`, `IsBorderRequired = false` (Windows 11).
- Handle `ContentSize` changes (window resized) by recreating the pool.
- Exclude RecLite's own window with `SetWindowDisplayAffinity(hwnd, WDA_EXCLUDEFROMCAPTURE)`.

### 12.2 GPU colour conversion

- Frames are BGRA textures. Hardware encoders want NV12.
- Use `ID3D11VideoProcessor` to convert (and scale) BGRA → NV12 **on the GPU**. No CPU copy.

### 12.3 Encoding and writing (Media Foundation)

- `IMFSinkWriter` created with:
  - `MF_SINK_WRITER_D3D_MANAGER` = DXGI device manager → encoder reads GPU textures directly.
  - `MF_READWRITE_ENABLE_HARDWARE_TRANSFORMS = TRUE` → uses NVENC / QuickSync / AMF.
  - Container: fragmented MP4.
- Video: H.264, `CODECAPI_AVEncCommonRateControlMode`, bitrate, GOP = 2 s, low-latency mode.
- Audio: AAC encoder MFT, 48 kHz stereo.
- If no hardware encoder exists: fall back to the Microsoft software H.264 encoder and lower defaults (720p/30).
- If the writer is falling behind: drop the frame, never queue.

### 12.4 System audio (WASAPI loopback)

- Open the default **render** device in shared mode with `AUDCLNT_STREAMFLAGS_LOOPBACK`.
- ⚠️ **Important gotcha:** when nothing is playing, loopback delivers **no data at all**. If we ignore this, sound drifts out of sync with video. Fix: compare the `QueryPerformanceCounter` clock with received samples and **insert silence** for any gap.
- Listen for device changes (`IMMNotificationClient::OnDefaultDeviceChanged`) — e.g., headphones plugged in — and reopen the stream on the new device without stopping the recording.

### 12.5 Microphone

- WASAPI capture on the selected input device; same QPC clock.

### 12.6 Windows specifics

- Prevent sleep: `SetThreadExecutionState(ES_CONTINUOUS | ES_SYSTEM_REQUIRED | ES_DISPLAY_REQUIRED)`.
- Microphone privacy setting: detect `E_ACCESSDENIED` and guide the user to *Settings → Privacy → Microphone*.
- Build with MSVC, C++17, link `d3d11`, `dxgi`, `mfplat`, `mfreadwrite`, `mfuuid`, `windowsapp`.

---

## 13. Audio: System Sound + Microphone

**In simple words:** We can record the computer's sound, your microphone, or both. When both are on, we blend them into one soundtrack so every video player plays both voices.

### 13.1 Pipeline

```
System audio ──► Resample to 48 kHz float stereo ──┐
                                                   ├──► Mixer ──► AAC encoder ──► MP4
Microphone ────► Resample to 48 kHz float stereo ──┘      │
                                                          └──► Level meter ──► Flutter (≈15×/s)
```

### 13.2 Rules

- One common format: **48 kHz, 32-bit float, stereo**.
- Microphone mono → duplicated to both channels.
- Mixer uses per-source volume and a soft limiter to avoid clipping.
- Level meter (RMS + peak per source) is calculated natively; only 2 small numbers per source are sent to Flutter about 15 times per second.
- Default: **one mixed audio track**. Advanced option later: separate tracks (system + mic) for editing.
- If an audio source fails mid-recording, keep recording video with the remaining audio and show a warning.

---

## 14. Flutter ↔ Native Communication

**In simple words:** Flutter sends short commands (like "start"), and the engine sends back short news updates (like "1 minute recorded"). No video ever goes through this connection.

### 14.1 Commands (Flutter → Native) — Pigeon `HostApi`

| Command | Description |
|---|---|
| `getCapabilities()` | OS version, hardware encoder available, mic capture method |
| `checkPermissions()` / `requestPermission(type)` | Screen, mic |
| `listDisplays()` | ID, name, resolution, is-main |
| `listWindows()` | ID, title, app name, (small thumbnail later) |
| `listAudioDevices()` | Input devices |
| `getDiskSpace(path)` | Free bytes |
| `startRecording(config)` | Source, audio toggles, folder, quality, segment length |
| `pauseRecording()` / `resumeRecording()` | — |
| `stopRecording()` | Returns when the last part is safely written |
| `recoverSessions(folder)` | Repair leftovers after a crash |

### 14.2 Events (Native → Flutter) — `EventChannel`

| Event | When | Data |
|---|---|---|
| `stateChanged` | Any state change | new state |
| `tick` | Once per second | elapsed time, current part, current file size, dropped frames |
| `audioLevels` | ~15 times/second (only when UI visible) | system level, mic level |
| `segmentCompleted` | Each finished part | part #, path, duration, size |
| `diskWarning` | Low space | free bytes, estimated minutes left |
| `error` | Any problem | code, message, is-fatal |

### 14.3 Technical notes

- **Pigeon** generates Swift and C++ code from one Dart definition file → no typos in channel names, compile-time checked types.
- Events use a standard `EventChannel` with small maps or Pigeon data classes.
- No polling from Flutter. Native pushes updates.
- **No FFI needed.**

---

## 15. Flutter App Design

### 15.1 Layers (Clean Architecture, kept simple)

| Layer | Contains | Rule |
|---|---|---|
| **Presentation** | Pages, widgets, Blocs/Cubits | Knows nothing about native code |
| **Domain** | Entities (`RecordingSession`, `Segment`, `CaptureSource`), repository interfaces | Pure Dart, no Flutter imports |
| **Data** | Repository implementations, data sources (engine plugin, shared_preferences, file system) | Only layer that talks to native/OS |

### 15.2 Blocs and Cubits

| Name | Type | Responsibility |
|---|---|---|
| `RecordingBloc` | Bloc | Session state machine: idle → starting → recording ⇄ paused → stopping → error |
| `SourcesCubit` | Cubit | Load displays, windows, audio devices; current selection |
| `AudioLevelsCubit` | Cubit | Live meter values (separate so the meter does not rebuild the whole page) |
| `SettingsCubit` | Cubit | Output folder, segment length, quality, shortcuts, theme |
| `HistoryCubit` | Cubit | List, open, reveal, delete recordings |
| `PermissionsCubit` | Cubit | Screen/mic permission status and onboarding |

### 15.3 Dependency injection (GetIt)

```dart
// app/di.dart (sketch)
final sl = GetIt.instance;

void setupDI() {
  sl.registerLazySingleton<RecliteEngine>(() => RecliteEngine());
  sl.registerLazySingleton<RecordingRepository>(() => RecordingRepositoryImpl(sl()));
  sl.registerLazySingleton<SettingsRepository>(() => SettingsRepositoryImpl(sl()));
  sl.registerLazySingleton<HistoryRepository>(() => HistoryRepositoryImpl());
  sl.registerFactory(() => RecordingBloc(sl(), sl()));
  // ...
}
```

### 15.4 Error model

- Native error codes are mapped to a Dart `Failure` type (e.g., `PermissionFailure`, `DiskFullFailure`, `EncoderFailure`).
- The UI shows a human-friendly message and a suggested action for each.

---

## 16. Storage, Files and Disk Space

**In simple words:** You choose where videos go. The app remembers your choice, shows how much space is left, warns you if space is getting low, and stops safely before the disk is full. It never overwrites an existing video.

### 16.1 Rules

- **Default folder:** `~/Movies/RecLite` (macOS), `%USERPROFILE%\Videos\RecLite` (Windows).
- **Remember last folder** (`shared_preferences`; plus security-scoped bookmark on sandboxed macOS).
- **Session folder:** each recording gets its own sub-folder (on by default, can be turned off).
- **Before recording:** show free space and estimated recording time left (free space ÷ bitrate).
- **Block start** if free space is below 1 GB.
- **During recording:** engine checks every 10 seconds.
  - Below 2 GB → `diskWarning` event (yellow banner).
  - Below 500 MB → finish the current part cleanly and stop, with a clear message.
- **Never overwrite:** if a file name exists, add a suffix (`_2`, `_3`). Files are created with "create new" mode so the OS refuses to overwrite.
- **Folder removed during recording** (e.g., USB drive unplugged) → stop safely, report error.

### 16.2 `session.json` example

```json
{
  "app": "RecLite",
  "version": 1,
  "sessionId": "2026-11-19_10-00-00",
  "startedAt": "2026-11-19T10:00:00+05:30",
  "endedAt": "2026-11-19T11:02:11+05:30",
  "status": "completed",
  "source": { "type": "display", "name": "Built-in Retina Display" },
  "audio": { "system": true, "microphone": false },
  "video": { "codec": "h264", "width": 1920, "height": 1080, "fps": 30 },
  "segments": [
    { "index": 1, "file": "RecLite_2026-11-19_10-00-00_Part01.mp4", "durationMs": 900000, "bytes": 512345678, "status": "complete" },
    { "index": 2, "file": "RecLite_2026-11-19_10-15-00_Part02.mp4", "durationMs": 900000, "bytes": 498765432, "status": "complete" }
  ]
}
```

`status` values: `recording`, `completed`, `recovered`, `failed`.

---

## 17. Recording History

**In simple words:** A list of your past recordings with date, length, size and location. You can play, open the folder, or delete (to Trash).

### 17.1 How it works

- Scan the output folder for `session.json` files (no database).
- Recordings without a manifest (older/manual files) are listed as plain MP4 files.
- Show per session: date, total duration, number of parts, total size, location, status badge (e.g., "Recovered").
- Expand a session to see its parts.

### 17.2 Actions

| Action | How |
|---|---|
| Play | Open the MP4 with the default player (`url_launcher` / native `open`) |
| Show in folder | macOS: reveal in Finder; Windows: `explorer /select,` |
| Delete | Confirmation dialog → move to Trash / Recycle Bin (native call) |
| Refresh | Rescan; also auto-refresh after each recording |

---

## 18. Permissions

**In simple words:** The operating system asks the user before any app can see the screen or hear the microphone. RecLite explains why it needs this and guides the user step by step.

| Permission | macOS | Windows |
|---|---|---|
| Screen recording | Required. System Settings → Privacy & Security → Screen & System Audio Recording. App restart may be needed. | Not needed (WGC is allowed by default) |
| System audio | Covered by screen recording permission | Not needed |
| Microphone | Required if mic is on. Standard system prompt. | Settings → Privacy → Microphone must allow desktop apps |

### Onboarding flow

1. First launch → "Welcome" screen explaining what is needed.
2. Button "Grant Screen Access" → triggers system prompt / opens System Settings.
3. App detects the change (check when the window gets focus) and shows "Restart RecLite" if required.
4. Microphone is asked only when the user turns the mic on for the first time.

---

## 19. Error Handling

| Problem | What the user sees | What the engine does |
|---|---|---|
| Screen permission missing | "RecLite needs screen access" + button | Refuses to start |
| Mic permission missing | Warning; mic toggle turns off | Records without mic |
| Screen capture stops (display unplugged, window closed) | "Source disappeared" | Finish current part, stop |
| Audio device changed | Small notice | Re-open on new default device, continue |
| Audio device failed | Warning | Continue with video + other audio |
| Encoder failure | Error message | Finish current part; try software encoder on next start |
| Disk almost full | Yellow banner with minutes left | — |
| Disk full | "Stopped: disk full. Your recording is saved." | Finalise and stop |
| Segment finalisation fails | Warning on that part | Keep `.part` file; recovery tries on next launch |
| App crash / power loss | On next launch: "We recovered your last recording" | Startup recovery (§10) |
| System sleep | Warning before sleep (we prevent idle sleep) | On forced sleep: finalise and stop |

**Rule:** No error may damage parts that are already finished.

---

## 20. Performance Rules

**In simple words:** The app should stay light even after 8 hours of recording. Video data flows through the graphics card straight to the disk and is never collected in memory.

| # | Rule | How |
|---|---|---|
| 1 | Never keep the whole video in memory | Stream: capture → encode → disk |
| 2 | Bounded buffers | SCK `queueDepth = 5`; WGC pool of 2 frames; small audio ring buffer |
| 3 | Back-pressure | If the writer is busy, **drop** the newest video frame — never queue unlimited frames |
| 4 | Zero-copy | GPU textures/IOSurfaces go straight to the hardware encoder |
| 5 | GPU colour + scaling | SCK config (Mac), D3D11 video processor (Windows) |
| 6 | Hardware encoders first | VideoToolbox, NVENC/QuickSync/AMF |
| 7 | No frames to Dart | Only small events |
| 8 | No polling from Flutter | Native pushes events |
| 9 | Throttle UI updates | 1 tick/s; audio meters ~15/s and paused when window hidden |
| 10 | Release everything | Writers, streams, devices closed on stop; checked with leak tools |
| 11 | Small UI while recording | Option to hide main window to tray / show mini indicator |

### Target numbers (1080p30, H.264, hardware encoder)

| Metric | Target |
|---|---|
| Engine memory | < 100 MB and flat over time |
| Whole app memory (with Flutter UI) | < 250 MB |
| CPU | < 10% on a modern 4-core machine |
| Dropped frames | < 0.5% |
| A/V drift after 4 hours | < 40 ms |
| Gap between parts | 0 frames lost |

> Note: The Flutter UI itself uses around 80–150 MB of RAM. That is the biggest memory user, not the recorder. Hiding the main window during recording helps.

---

## 21. User Interface

**In simple words:** Three screens — Home, History, Settings — plus a tiny floating bar while recording. Clean, calm, no heavy animations.

### 21.1 Home (ready to record)

```
┌────────────────────────────────────────────────────────┐
│  RecLite                         [History] [Settings]  │
├────────────────────────────────────────────────────────┤
│  ✅ Ready to Record                                    │
│                                                        │
│  Source:     [ 🖥 Built-in Display (1920×1080)  ▾ ]    │
│  Audio:      [✓] System sound   ▮▮▮▮▯▯                 │
│              [ ] Microphone      ▯▯▯▯▯▯                 │
│  Save to:    [ ~/Movies/RecLite        ] [Browse]      │
│              120 GB free · about 40 h of recording     │
│  Split every: [ 15 minutes ▾ ]                         │
│                                                        │
│              [  ●  Start Recording  ]                  │
│                 ⌘⇧R to start/stop                      │
└────────────────────────────────────────────────────────┘
```

### 21.2 Recording (mini floating indicator)

```
┌──────────────────────────────────────────┐
│ ● REC  01:23:45   Part 6   [❚❚]  [■]     │
└──────────────────────────────────────────┘
```

- Always on top, small, draggable, excluded from the recording.
- Main window can be hidden; tray/menu-bar icon shows a red dot.

### 21.3 History

- List of sessions (newest first), expandable to parts.
- Each row: date, duration, parts, size, location, actions (Play / Folder / Delete).

### 21.4 Settings

- General: output folder, session sub-folder on/off, theme (system/light/dark).
- Recording: resolution, frame rate, quality, codec, cursor, segment length.
- Audio: default mic device, default toggles.
- Shortcuts: start/stop, pause/resume (editable).
- About: version, licences.

### 21.5 Default keyboard shortcuts

| Action | macOS | Windows |
|---|---|---|
| Start / Stop | ⌘ ⇧ R | Ctrl Shift R |
| Pause / Resume | ⌘ ⇧ P | Ctrl Shift P |

(Check they do not clash with common apps; users can change them.)

---

## 22. Development Phases

**In simple words:** Build one working slice first (Mac, full pipeline including segments), then copy the design to Windows, then add the extra screens, then test hard.

> Change from the original plan: segmentation moves into **Phase 1**, because it changes how the writer is built. Adding it later would mean rewriting the writer.

### Phase 0 — Setup ✅ Done (2026-11-19)

- [x] Removed `android/`, `ios/`, `web/`; added Windows target. App named **RecLite** (bundle ID `com.manishsubah.reclite`, Dart package `reclite`).
- [x] Created `packages/reclite_engine` plugin (macOS Swift + Windows C++).
- [x] Added packages: flutter_bloc, get_it, equatable, pigeon (dev), bloc_test, mocktail, integration_test. `file_selector`, `shared_preferences`, `url_launcher` are added in Phase 3 when first used. `window_manager` was dropped (v0.6 pulls in a large native framework); window size/title are set natively, and the mini indicator will be re-evaluated in Phase 3.
- [x] Pigeon contract `packages/reclite_engine/pigeons/engine_api.dart`: `getCapabilities()`, `getDiskSpace(path)`, implemented in Swift and C++.
- [x] App shell: Material 3 theme (light/dark), GetIt DI, navigation rail (Record / History / Settings), readiness dashboard.
- [x] Strict `flutter_lints` + extra rules, `dart format`, GitHub Actions CI (analyze, test, Pigeon drift check, macOS + Windows builds).
- [x] macOS deployment target 13.0; App Sandbox off (direct distribution); mic + screen usage descriptions.
- [x] No black flash at launch (native window painted with the theme background until Flutter's first frame).
- [x] Release build: `RecLite.app` 39 MB; ~91 MB memory footprint at idle (macOS `footprint`).

**Done when:** App runs on macOS; calling `getCapabilities()` returns real data from Swift. ✅ Verified by `flutter test integration_test -d macos`. Windows C++ is compile-checked only in CI (no Windows machine yet).

### Phase 1 — macOS recording engine ✅ Built (2026-11-19)

- [x] List displays (SCShareableContent). Window capture moved to Phase 3; **area capture** added instead (drag-to-select overlay, red outline not recorded).
- [x] Screen capture (SCStream, NV12, GPU-scaled to ≤1440p, bounded queue, own windows excluded).
- [x] System audio via SCK.
- [x] AVAssetWriter H.264 + AAC, fragmented MP4 (fragment every **2 s**: a crash loses at most ~2 s).
- [x] SegmentedRecorder: pre-warm, exact boundary for video and audio, part seeded with last frame, background finalise, `.part` rename.
- [x] Pause / resume with timestamp offset (paused time not recorded, not counted toward a part).
- [x] Microphone via SCK (macOS 15+), mixer, level meters. macOS 13–14 mic support is still open.
- [x] `session.json` manifest, kept current as each part closes; crash recovery on launch.
- [x] Events to Flutter (status, levels, errors incl. non-fatal warnings).
- [x] Home screen: screen/area picker, audio card, REC bar with Pause/Resume/Stop, saved card, recovery banner.
- [x] Permission checks (screen, microphone).
- [x] Disk guard (warn < 2 GB, safe stop < 500 MB) and sleep prevention.

**Verified:**
- Real 3-part recording with a pause: parts were 20.000 / 20.000 / 7.347 s, with audio equal to video.
- Real SIGKILL test: 5 parts intact and part 6 recovered (16.1 s).
- Simulated recorder tests and 63 unit/widget tests pass.

**Still to verify:** the 1-hour memory soak test (Phase 4). The real disk-full stop has only been checked through its policy code.

### Phase 2 — Windows recording engine 🔶 Written, awaiting first Windows build (2026-11-19)

Same features as macOS Phase 1, written in C++ in `packages/reclite_engine/windows/`:

- [x] Monitors with friendly names; Windows Graphics Capture (cursor on, no yellow border on Windows 11, own windows excluded).
- [x] GPU BGRA → NV12 with crop (area) + scale via the D3D11 video processor; bounded frames in flight.
- [x] Media Foundation Sink Writer: hardware H.264 + AAC, fragmented MP4, `.part` → `.mp4` on finish.
- [x] WASAPI system-sound loopback + microphone (48 kHz float via AUTOCONVERTPCM), follows default-device changes; mixer + level meters (ported from macOS).
- [x] SegmentedRecorder port: 15-min parts, exact boundary, pause/resume, background finalise.
- [x] `session.json` (same format as macOS), crash recovery on launch, disk guard, keep PC awake.
- [x] Area overlay + red outline (excluded from capture).
- [x] CI: portable C++ unit tests (mixer, timeline, manifest) + Windows release build uploaded as `RecLite-windows-x64`.

**Verified so far:** portable C++ tests pass on macOS (clang) — 14 audio + 12 storage, also with exceptions disabled; the same tests read a real macOS `session.json`.
**Not verified yet:** the Windows build itself (first compile is in CI) and real recording on a Windows PC.

### Phase 3 — Product features (≈ 2 weeks)

- [ ] Source picker UI (displays/windows, later thumbnails).
- [ ] Storage: folder picker, remember folder, free-space display, disk monitor, safe stop.
- [ ] History screen (manifest scan, play, reveal, trash).
- [ ] Settings screen.
- [ ] Global shortcuts (hotkey_manager).
- [ ] Mini recording indicator + tray/menu-bar icon.
- [ ] Permission onboarding screens.
- [ ] Crash recovery on startup.
- [ ] Friendly error messages for every failure in §19.

**Done when:** All features in the spec work on both platforms.

### Phase 4 — Hardening and release prep (≈ 2 weeks)

- [ ] Performance profiling and fixes (see §23).
- [ ] Long recording tests (4–8 h).
- [ ] Crash/kill tests, disk-full tests, device-swap tests.
- [ ] Cross-platform QA on different hardware (Intel/Apple Silicon Mac; NVIDIA/Intel/AMD PCs).
- [ ] App icon, signing, notarisation, installer.

**Done when:** All acceptance criteria (§26) pass.

**Total rough estimate:** 9–11 weeks for one experienced developer.

### Future ideas (after v1)

- Configurable segment length in UI (engine already supports it).
- Region (rectangle) recording.
- Webcam overlay.
- Per-application audio (macOS SCK app filter; Windows process loopback).
- Separate audio tracks.
- Convert fragmented MP4 to standard MP4 / join parts.
- Linux support.

---

## 23. Testing Plan

### 23.1 Automated tests

| Area | Tool | What |
|---|---|---|
| Blocs/Cubits | `bloc_test` | Every state transition, error mapping |
| Repositories | `mocktail` | Correct calls to engine, manifest parsing |
| File naming | unit tests | Names, suffixes, never overwrite |
| Native segment logic | XCTest (Mac), GoogleTest (Windows) | Boundary maths, audio split, pause offsets |

### 23.2 Manual / scripted tests

| Test | How | Pass when |
|---|---|---|
| **Soak test** | Record 4–8 h with a video playing | Memory flat; all parts playable |
| **A/V sync** | Record a "flash + beep" test video | Drift < 40 ms in first and last part |
| **Segment gap** | Record a running clock with milliseconds | No missing time between Part N and N+1 |
| **Crash** | `kill -9` the app mid-part | Old parts fine; current part playable up to last ~5 s; recovery runs on next launch |
| **Power loss** | Force shutdown (VM) | Same as crash |
| **Disk full** | Record to a tiny disk image (`hdiutil create -size 2g ...` on Mac, small VHD on Windows) | Warning shown, clean stop, files playable |
| **Device change** | Plug/unplug headphones; change default output | Recording continues; audio follows device |
| **Silence (Windows)** | Record 10 min with no sound, then play sound | No drift after silence |
| **Pause across boundary** | Pause at 14:50, resume after 2 min | Part 1 is 15:00 of media; no glitch |
| **Multi-monitor** | Pick each monitor | Correct screen recorded |
| **Window closed** | Close the recorded window | Clean stop, files playable |
| **File validity** | `ffprobe` on every output | No errors; correct duration, codecs |

### 23.3 Profiling tools

- macOS: Instruments (Allocations, Leaks, Time Profiler), `footprint`, Activity Monitor.
- Windows: Visual Studio Diagnostic Tools, Windows Performance Recorder/Analyzer, Task Manager GPU view.
- Flutter: DevTools (memory, rebuild counts).

---

## 24. Distribution and Packaging

| | macOS | Windows |
|---|---|---|
| Format | `.dmg` (direct) or Mac App Store | MSIX (Store or direct) or Inno Setup `.exe` |
| Signing | Developer ID certificate | Code signing certificate (OV/EV) |
| Extra | **Notarisation** required for direct download | SmartScreen reputation builds over time with signed builds |
| Updates | Sparkle (direct) or App Store | MSIX auto-update or Store |
| Architectures | Universal (Apple Silicon + Intel) | x64 (ARM64 later) |

---

## 25. Open Decisions

These need an answer before or during Phase 0:

| # | Question | Options | Recommendation |
|---|---|---|---|
| 1 | Mac App Store or direct download? | Store (sandbox) / Direct (notarised) / Both | **Decided (default):** Direct first, sandbox off |
| 2 | Final product name | RecLite / backup name | **RecLite** (trademark search still to do, §2) |
| 3 | Default codec | H.264 / HEVC | **Decided:** H.264 default, HEVC optional (see §8.5) |
| 4 | Default resolution cap | 1080p / 1440p / Native | **1440p cap** (good balance) |
| 5 | Separate audio tracks in v1? | Yes / No | **No** — one mixed track in v1 |
| 6 | Windows dev machine | PC / Parallels VM / cloud VM | Real PC or x64 VM for encoder testing |
| 7 | Open source or closed? | — | Affects licence choices; decide early |

---

## 26. Acceptance Criteria (Definition of Done)

Version 1 is successful when:

- [ ] Recording works on **macOS 13+** and **Windows 10 2004+**.
- [ ] Screen and internal (system) audio are captured; microphone works when enabled.
- [ ] Output files are valid **MP4** (H.264 + AAC) and pass `ffprobe`.
- [ ] Each part is **15:00 of recorded time** (±1 s); last part is the remainder.
- [ ] Recording continues automatically between parts with **no lost frames or audio gap**.
- [ ] **Finished parts are always playable**, even after a crash or power loss.
- [ ] The current part survives a crash up to the last ~5 seconds.
- [ ] **Memory stays flat** during a 4-hour recording (engine < 100 MB).
- [ ] No raw video frames are stored in memory or sent to Flutter.
- [ ] Users can choose and the app remembers the output folder.
- [ ] Low disk space is detected and handled without corrupting files.
- [ ] Existing files are never overwritten.
- [ ] Pause/resume, stop, elapsed time, part number and status all work.
- [ ] History lists recordings and can play, reveal and delete (to Trash).
- [ ] Keyboard shortcuts work globally and can be changed.
- [ ] Every error in §19 shows a clear message and never damages finished parts.

---

## 27. Glossary

| Term | Simple meaning |
|---|---|
| **Flutter** | Google's toolkit for building app UIs from one codebase |
| **Native code** | Code written in the OS's own language (Swift on Mac, C++ on Windows) — fastest access to hardware |
| **ScreenCaptureKit (SCK)** | Apple's modern, efficient screen + audio capture API |
| **Windows Graphics Capture (WGC)** | Microsoft's modern screen capture API |
| **WASAPI loopback** | Windows feature to record "what you hear" from speakers |
| **Media Foundation** | Microsoft's media framework (encoding, MP4 writing) |
| **VideoToolbox** | Apple's hardware video encoder framework |
| **AVAssetWriter** | Apple API that encodes and writes MP4/MOV files |
| **Encoder** | Compresses raw video/audio into small data (H.264/AAC) |
| **Hardware encoder** | Encoder built into the graphics chip — fast and low CPU |
| **H.264 / HEVC** | Video compression formats. H.264 = most compatible; HEVC = smaller files |
| **AAC** | Common audio compression format used in MP4 |
| **MP4 / muxing** | MP4 is a container holding video + audio; "muxing" = putting them together in the file |
| **Fragmented MP4** | MP4 written in small chunks, each self-describing → survives crashes |
| **moov atom** | The "table of contents" of a normal MP4, written at the end |
| **Keyframe (IDR)** | A full picture frame; a video file must start with one to play |
| **Segment / Part** | One 15-minute MP4 file of a longer recording |
| **PTS / timestamp** | The time label on each frame or audio sample, used for sync |
| **A/V sync / drift** | Whether sound matches the picture; drift = slowly going out of sync |
| **Back-pressure** | When the next step is busy, the previous step slows down or drops data instead of piling it up |
| **Zero-copy** | Passing the same memory (e.g., GPU texture) along instead of copying it |
| **NV12 / BGRA** | Pixel formats. Screens give BGRA; encoders want NV12 |
| **Pigeon** | Flutter tool that generates type-safe code for talking to native code |
| **EventChannel** | Flutter channel for a stream of messages from native to Dart |
| **Bloc / Cubit** | Flutter state-management classes: input events → output states |
| **GetIt** | A simple registry to create and share services (dependency injection) |
| **Manifest (`session.json`)** | Small file describing a recording and its parts |
| **TCC** | macOS privacy permission system (screen, mic access) |
| **Notarisation** | Apple's malware check required for apps downloaded outside the App Store |
