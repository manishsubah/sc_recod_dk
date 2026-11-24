---
version: 1
slug: "lib-app-router-app-shell-dart"
primary_target: "lib/app/router/app_shell.dart"
related_targets: ["lib/features"]
---

## Scope
Whole RecLite app UI (Flutter desktop): app shell + Record, History, Settings, Help, mini recording bar. Mode: Operate. Build path: code-led (no image generation).

## Audience & task
Creators/professionals recording tutorials, demos, meetings. Task: confirm what will be captured and that sound is live, start fast, watch the recording safely, find the file later.

## Constraints
UI only: no change to engine, Pigeon contract, Bloc/Cubit logic, or behaviour. Keep visible labels the tests and users rely on (Start Recording, Ready to Record, REC/PAUSED, Recording saved…). Native feel per OS is user-pinned: Windows 11 conventions on Windows, macOS conventions on Mac; light + dark follow the system; RecLite name/logo kept. User asked for independent decisions (no approval round).

## Direction contract
THESIS: A recorder whose numbers carry the page: time, parts and size read like edge print along a film strip, inside a native Windows/Mac shell of hairline-seamed panes. Refuses the Material card stack and the dark neon "studio" opposite.
OWN-WORLD: Neutral native grounds (Mica-like gray / Mac window gray), panes divided by 1 px seams, one step of elevation. Film-base amber accent for selection, focus, switches and part strips; tally red only for recording. System UI faces (Segoe UI Variable / SF), tabular figures everywhere, small tracked uppercase edge labels (PART 02 · 15:00).
STORY: See screen, capture mode and live sound at a glance; press Start (top right); watch big timecode and the part strip roll toward the next part; stop, open or reveal the file; later find it in History by date with its part strip and stamped state.
FIRST VIEWPORT: Left native sidebar (logo, Record/History/Settings/Help, red dot while recording). Content: title "Record" with a one-line status beneath (Ready to Record · folder · free space); Start Recording top right. Source pane (Screen picker, Full screen/Area/Window) and Audio pane (System sound, Microphone with meters). When live: transport pane on top with 40 px timecode, REC/PAUSED tally, Part N · size, part strip, Pause/Stop.
FORM: Grounded candidate 6 of 7 (reel-can label & film edge print), translated through the user's native-per-OS pin; signature move = the part strip (duration drawn as segmented strip with edge ticks) on Record and History. seed: db693c01a65bc754. Raises — from dark-first console: hairline seams instead of cards, destructive action isolated; from data-sublime field: tabular numerics in aligned columns; from ticket wallet: states stamp onto the record (Recovered/Interrupted) and never disappear.
FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance
