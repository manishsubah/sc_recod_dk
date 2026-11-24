# Product

<!-- impeccable:product-schema 1 -->

## Platform

adaptive

Desktop, not mobile: one Flutter app on **Windows 10 (2004)+ / Windows 11** (main platform) and **macOS 13+**. The UI should feel native on each OS: Windows 11 (Fluent) on Windows, macOS conventions on Mac.

## Users

Creators and professionals who record tutorials, demos, presentations, meetings and online classes on their desktop. They care about control and quality: what is captured (full screen, an area, or one window), whether system sound and microphone are coming through, and that long recordings are safe.

## Product Purpose

RecLite records the desktop screen with system sound and microphone to standard MP4 files, splits long sessions into parts automatically, and keeps recordings safe if the app or PC stops unexpectedly. Success: start quickly, record for hours without thinking about it, and find the file afterwards.

## Positioning

*From the project plan (docs/PLAN.md); not re-confirmed in the interview.* A lightweight, native-powered recorder: low memory and CPU, hardware encoding, 15-minute MP4 parts with crash-safe writing and recovery, files stay on the user's PC with no account or cloud.

## Operating Context

- Started right before a meeting, class or demo; then mostly hidden while the user works in other apps (mini recording bar, tray icon, global shortcuts Ctrl+Alt+R / Ctrl+Alt+P).
- The main window must not appear in recordings (it is excluded from capture).
- Recordings are reviewed later from History, opened in the system player or file manager.

## Capabilities and Constraints

- **Record:** choose a screen, then Full screen / Area (drag a rectangle) / Window; System sound and Microphone switches with live level meters; Start, Pause/Resume, Stop; live timer, part number and size; "Recording saved" summary; recovery banner after an interrupted recording.
- **History:** past recordings with date, length, size, parts, source and a "Recovered" badge; Play, Show in folder, Move to Recycle Bin/Trash.
- **Settings:** save folder, split length, quality, frame rate, mouse pointer, theme (System / Light / Dark), global shortcuts.
- **Help:** About, open-source licenses, quick guide, support links.
- **Desktop extras:** mini recording bar, tray icon.
- **Binding constraint for the current work:** UI redesign only. No change to recording behaviour, engine code (Swift/C++), the Pigeon contract or Bloc/Cubit logic. Mac-only gaps stay as implemented.
- Minimum window size 760 × 560.

## Brand Commitments

- Name **RecLite** and its camera logo stay. A new colour palette is allowed.
- Light and dark themes, following the system by default.

## Evidence on Hand

- Current UI screenshots: `docs/screenshots/` (record, recording, history, settings, help). These are the look being replaced.
- No testimonials, user numbers or benchmarks exist; don't invent them.

## Product Principles

1. Recording is the job: the path to Start is short and the live recording state is unmistakable.
2. Trust over flash: show clearly what will be captured and that sound is coming through.
3. Stay out of the way while recording: quiet, compact, hideable.
4. Feel at home on each OS rather than like a web page in a window.
