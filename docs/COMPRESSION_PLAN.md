# Smaller recordings — plan

Status: **proposal, for review** (2026-11-21). Nothing here is implemented yet.

Goal: make recordings much smaller — especially long 720p/1080p screen recordings —
without visibly lower quality, keep RecLite light on CPU, and show users the saving.

---

## 1. Where we are today

**Video:** H.264, hardware encoder, **constant bitrate (CBR)**:
`bitrate = width × height × fps × 0.08`, clamped to 0.4–16 Mbit/s
(`windows/writer/segment_writer.cpp` `VideoBitrate`, macOS `SegmentWriter.bitrate`).
Keyframe every 2 s. **Audio:** AAC, 48 kHz stereo, 160 kbit/s.

| Output | Video bitrate | Size per hour (video + audio) |
|---|---|---|
| 720p, 30 fps | 2.2 Mbit/s | ≈ 1.07 GB |
| 1080p, 30 fps | 5.0 Mbit/s | ≈ 2.3 GB |
| 1080p, 60 fps | 10.0 Mbit/s | ≈ 4.6 GB |

**The problem, measured on this PC:** CBR spends the full bitrate even when the screen
does not change.

| Recording | Screen | Size | Rate |
|---|---|---|---|
| 22:54, 46.8 s, 1080p | completely still | 29.5 MB | 5.0 Mbit/s |
| 23:06, 13.7 s, 1080p | mostly still | 8.2 MB | 4.8 Mbit/s |

Screen recordings are mostly still (slides, documents, code, meetings), so this is the
biggest waste.

Two platform details matter:

- **Windows** writes a constant 30/60 fps stream: when the screen is still, the last
  picture is repeated (needed because Media Foundation's encoder ignores timestamps;
  see `SegmentWriter::FillTo`). With CBR, those repeats cost full bitrate.
- **macOS** drops unchanged frames already (ScreenCaptureKit sends only changed frames;
  AVAssetWriter's H.264 uses an *average* bitrate). macOS may already be smaller than
  Windows for still screens — Phase A measures it instead of assuming.

**RAM is not the issue:** frames stream to disk, memory stays flat however long the
recording is. What limits long recordings is **disk space**, which is what this plan
reduces. (The disk-space warning already uses the measured write rate, so it adapts
automatically.)

---

## 2. Options considered

| # | Technique | Expected saving (screen content) | Verdict |
|---|---|---|---|
| 1 | **Quality-based variable bitrate** with a peak cap | Largest: often **3–6× smaller** for mostly-still screens; little change for full-motion video | **Do — new default** |
| 2 | **HEVC (H.265)** | ≈ 30–50 % smaller than H.264 at the same quality | **Do — as an option** (playback caveat on Windows, §5) |
| 3 | Longer keyframe interval (2 s → 4 s) | ≈ 5–15 % | Maybe — trade-off with crash safety; decide from Phase A data |
| 4 | Leaner audio (160 → 128 kbit/s; mono when only the mic is recorded) | 15–30 MB per hour | Small — do with Phase B, low risk |
| 5 | "Shrink" an existing recording from History | 50–80 % on old files | Later (Phase E) |
| — | AV1 | ≈ 20–30 % below HEVC | **No** for now: hardware encoders only on very new GPUs |
| — | Software encoding (x264/x265) | Good compression | **No**: high CPU use, against "lightweight" |
| — | App-side "data structures" (diffing frames ourselves) | — | **No**: the encoder already detects unchanged blocks and codes only differences; it just needs the right rate control |

Numbers in this table are typical published/industry figures for screen content, not
yet measured on RecLite. **Phase A replaces them with measurements.**

---

## 3. Phases

### Phase A — Measure (≈ 1 day, invisible to users)

**What we build**

- Engine switches (debug only, not in the UI) for: rate control (CBR / peak-constrained
  VBR / quality VBR), quality level, peak cap, codec (H.264 / HEVC), keyframe interval.
- A benchmark harness that feeds **the exact same frames** into the real `SegmentWriter`
  for each setting (like the writer harness used to fix the timing bug), so sizes and
  quality are directly comparable. Recording the live screen twice would never produce
  identical content.
- Three test clips, 2 minutes each, 720p and 1080p:
  1. still document/slides with occasional changes,
  2. typing, scrolling and window switching,
  3. a playing video (worst case).
- Quality measured with ffmpeg (**VMAF** and **SSIM**, already installed): each encode is
  compared with the original frames.

**Output:** a table in this document — size per hour and quality score for every
setting × clip × resolution, on this PC (Intel Iris Xe).

**Done when:** we can pick defaults from data: the smallest setting whose quality is
indistinguishable from today's on clips 1–2 (target VMAF ≥ 93, or within 1 point of
today's CBR) and acceptable on clip 3.

**Decision for you after Phase A:** approve the default settings and the HEVC option.

### Phase B — Better default for everyone (≈ 2–3 days)

**What we build**

- **Windows:** set rate control through `ICodecAPI` on the encoder (already used for
  the keyframe interval):
  `CODECAPI_AVEncCommonRateControlMode` = Quality (or PeakConstrainedVBR),
  `CODECAPI_AVEncCommonQuality`, `CODECAPI_AVEncCommonMaxBitRate` (peak cap ≈ today's
  CBR rate, so fast motion stays sharp). Check `IsSupported`/`IsModifiable` first.
- **Fallback chain** when the GPU's encoder does not support a mode:
  quality VBR → peak-constrained VBR → today's CBR. The manifest records what was used.
- **macOS:** tune `AVVideoAverageBitRateKey` / data-rate limits per Phase A results
  (macOS may need less change, see §1).
- Audio: 128 kbit/s stereo; 96 kbit/s mono when only the microphone is recorded.
- The "Recording saved" card shows the real size as today; nothing else changes in the UI.

**Done when:** a still-screen 720p recording is well under 1 GB/h on this PC; Phase A
quality targets hold; all existing tests and the real-recording integration tests pass;
a 30-minute mixed recording plays cleanly with audio in sync.

### Phase C — "File size" setting (≈ 2 days)

**What we build**

- Settings → Recording → **File size**, plain words instead of codec names:

  | Choice | Video | For |
  |---|---|---|
  | **Smaller** | HEVC + quality VBR | Long recordings, archiving |
  | **Balanced** (default) | H.264 + quality VBR | Most people |
  | **Most compatible** | H.264 + today's CBR | Old players, strict upload rules |

- Live estimate under the choice, e.g. "≈ 250 MB per hour at 720p", from Phase A data
  for the chosen quality/fps.
- **Smaller** only appears when the PC has a hardware HEVC encoder (the engine already
  detects this: `hasHardwareHevcEncoder`), with a one-line note about playback (§5).
- Contract change: `EngineRecordingRequest` gets `videoCodec` and `rateControl`
  fields; regenerate Pigeon; both engines honour them; `session.json` records the codec.

**Done when:** each choice produces the expected codec/size on Windows; estimates are
within ±30 % of real recordings of the Phase A clips; tests cover the setting and the
request fields.

### Phase D — Show the saving (≈ 1 day)

**What we build**

- "Recording saved" card: *"312 MB — about 70 % smaller than a standard recording."*
- History: the same per recording, and a total ("RecLite has saved 14 GB").
- **Honest comparison:** "standard" = what today's constant-bitrate formula would have
  written for the same duration, resolution and fps (+ audio). It is computed, not
  guessed, and the wording says "about".

**Done when:** the percentage matches real file sizes for the Phase A clips; recordings
made with "Most compatible" show no saving claim.

### Phase E — Shrink existing recordings (later, optional, ≈ 3–4 days)

- History → **Make smaller**: re-encodes a recording in the background (HEVC and/or a
  lower resolution), keeps the original until the new file is verified, then moves the
  original to the Recycle Bin/Trash.
- Windows: Media Foundation transcode; macOS: AVAssetExportSession (HEVC presets).
- Only worth doing after B–D are in use.

---

## 4. Files that change (Phases B–D)

| Area | Files |
|---|---|
| Contract | `packages/reclite_engine/pigeons/engine_api.dart` (+ regenerated files) |
| Windows engine | `windows/writer/segment_writer.*` (rate control, codec, audio), `windows/engine/recording_engine.cpp` (request → writer settings), `windows/engine/capabilities_probe.cpp` (VBR support check) |
| macOS engine | `Writer/SegmentWriter.swift`, `Engine/RecordingEngine.swift`, `Engine/CapabilitiesProbe.swift` |
| Manifest | `storage/session_manifest.*`, `Storage/SessionManifest.swift` (codec, rate-control mode) |
| Dart | `recording_options.dart`, settings repository/cubit/page, recording config, saved card, History page |
| Tests | settings/readiness/recording tests, engine harness benchmark, integration tests |

---

## 5. Issues and risks

| # | Issue | Impact | How we handle it |
|---|---|---|---|
| 1 | **GPU encoders differ.** Intel (Quick Sync), NVIDIA (NVENC) and AMD (AMF) Media Foundation encoders do not all support "quality" rate control or report it consistently | VBR silently not applied, or setup fails on some PCs | Query support before use; fallback chain (Phase B); record the mode in the manifest; **test on at least one NVIDIA and one AMD PC before release** |
| 2 | **Variable bitrate spikes** on fast motion (games, video) | Files larger than expected in motion-heavy recordings | Peak cap at about today's CBR rate, so VBR is never bigger than today in practice |
| 3 | **HEVC playback on Windows**: the built-in Films & TV / Media Player needs Microsoft's "HEVC Video Extensions" (about $1 in the Store); VLC, browsers and Macs play it | Users can't play "Smaller" files in the default player | Keep H.264 the default; explain in one line next to "Smaller" |
| 4 | **HEVC in MP4 tag (`hvc1` vs `hev1`)**: Apple players require `hvc1`; Windows' MP4 writer may use the other | Windows-made HEVC files might not play in QuickTime/iPhone | Check in Phase A with ffprobe; if needed fix the tag or restrict HEVC |
| 5 | **HEVC size rules**: some hardware HEVC encoders need width/height multiples of 8 or 16; area/window recordings can be any even size | Encoder fails to start for odd-sized areas | Round area output to the encoder's alignment, or fall back to H.264 for that recording |
| 6 | **Crash safety vs keyframe interval**: a longer interval can lose more on a crash | Longer interval = up to 4 s lost instead of 2 s | Only change if Phase A shows a real saving; keep 2 s otherwise |
| 7 | **Windows repeats frames on a still screen** (constant frame rate) | Under VBR repeats should cost almost nothing — must be confirmed | Phase A clip 1 measures exactly this |
| 8 | **Quality perception**: "smaller" must not look worse on text | Blurry text = bad reviews | Objective VMAF/SSIM targets on text-heavy clips + a visual check |
| 9 | **Estimates vs reality**: size depends on what is on screen | Estimates can be off | Show ranges ("≈ 150–350 MB per hour"), word as "about" |
| 10 | **Audio mono** | System sound must stay stereo | Mono only when the microphone is the only source |
| 11 | **Existing files and History** | Old recordings have no codec/mode in the manifest | Treat missing fields as "H.264, CBR"; no migration needed |
| 12 | **macOS untested here** | Swift changes can't be compiled on this PC | Same as other Phase 3 Swift work: build and run Phase A clips on a Mac before release |

---

## 6. Decisions needed from you

1. **After this review:** start Phase A (measurement only)?
2. **After Phase A:** approve the default (expected: "Balanced" = H.264 + quality VBR) and
   whether to offer HEVC ("Smaller").
3. **Phase D wording:** OK to show "about X % smaller than a standard recording"?
4. **Phase E:** build "Make smaller" in History now or later?
