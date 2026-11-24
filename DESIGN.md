---
name: RecLite
description: Lightweight desktop screen recorder; film edge print inside a native Windows 11 / macOS shell.
colors:
  ground: "#F3F3F3"
  pane: "#F9F9F9"
  pane-raised: "#FFFFFF"
  seam: "#E5E5E5"
  seam-strong: "#CCCCCC"
  ink: "#1B1B1B"
  ink-muted: "#5C5C5C"
  ink-faint: "#8A8A8A"
  film-amber: "#A85400"
  on-accent: "#FFFFFF"
  tally: "#D42F3F"
  tally-ink: "#C2283A"
  success: "#2E7D32"
  warning: "#9D5D00"
  danger: "#C42B1C"
  ground-dark: "#202020"
  pane-dark: "#272727"
  pane-raised-dark: "#2D2D2D"
  seam-dark: "#3A3A3A"
  seam-strong-dark: "#4D4D4D"
  ink-dark: "#F3F3F3"
  ink-muted-dark: "#B0B0B0"
  ink-faint-dark: "#808080"
  film-amber-dark: "#F0A24B"
  on-accent-dark: "#202020"
  tally-dark: "#D93A47"
  tally-ink-dark: "#FF6B74"
  success-dark: "#6CCB5F"
  warning-dark: "#F2C94C"
  danger-dark: "#FF99A4"
typography:
  timecode:
    fontFamily: "Segoe UI Variable Text, Segoe UI (Windows); SF Pro (.AppleSystemUIFont, macOS)"
    fontSize: "40px"
    fontWeight: 300
    lineHeight: 1.1
    letterSpacing: "-0.5px"
    fontFeature: "tnum"
  headline:
    fontFamily: "Segoe UI Variable Text, Segoe UI; SF Pro"
    fontSize: "28px"
    fontWeight: 600
    lineHeight: 1.2
  title:
    fontFamily: "Segoe UI Variable Text, Segoe UI; SF Pro"
    fontSize: "20px"
    fontWeight: 600
    lineHeight: 1.3
  body:
    fontFamily: "Segoe UI Variable Text, Segoe UI; SF Pro"
    fontSize: "14px"
    fontWeight: 400
    lineHeight: 1.45
  body-strong:
    fontFamily: "Segoe UI Variable Text, Segoe UI; SF Pro"
    fontSize: "14px"
    fontWeight: 600
    lineHeight: 1.35
  caption:
    fontFamily: "Segoe UI Variable Text, Segoe UI; SF Pro"
    fontSize: "12px"
    fontWeight: 400
    lineHeight: 1.35
  edge-label:
    fontFamily: "Segoe UI Variable Text, Segoe UI; SF Pro"
    fontSize: "11px"
    fontWeight: 600
    lineHeight: 1.2
    letterSpacing: "1.1px"
    fontFeature: "tnum"
rounded:
  xs: "2px"
  sm: "4px"
  md: "6px"
  lg: "8px"
  xl: "10px"
spacing:
  xxs: "4px"
  xs: "8px"
  sm: "12px"
  md: "16px"
  lg: "20px"
  xl: "24px"
  xxl: "32px"
  xxxl: "40px"
  huge: "48px"
components:
  button-record:
    backgroundColor: "{colors.tally}"
    textColor: "#FFFFFF"
    rounded: "{rounded.sm}"
    height: "32px"
    padding: "0 16px"
  button-primary:
    backgroundColor: "{colors.film-amber}"
    textColor: "{colors.on-accent}"
    rounded: "{rounded.sm}"
    height: "32px"
    padding: "0 16px"
  button-secondary:
    backgroundColor: "{colors.pane-raised}"
    textColor: "{colors.ink}"
    rounded: "{rounded.sm}"
    height: "32px"
    padding: "0 16px"
  button-text:
    textColor: "{colors.film-amber}"
    rounded: "{rounded.sm}"
    height: "32px"
  select-box:
    backgroundColor: "{colors.pane-raised}"
    textColor: "{colors.ink}"
    rounded: "{rounded.sm}"
    height: "32px"
    padding: "0 8px 0 12px"
  pane:
    backgroundColor: "{colors.pane-raised}"
    rounded: "{rounded.lg}"
  pane-row:
    padding: "12px 16px"
    height: "52px"
  nav-item:
    textColor: "{colors.ink}"
    rounded: "{rounded.sm}"
    height: "36px"
    padding: "0 12px"
  part-strip:
    backgroundColor: "{colors.film-amber}"
    rounded: "{rounded.xs}"
    height: "6px"
---

# Design System: RecLite

## Overview

**Creative North Star: "Film Edge Print"**

The numbers carry the page: elapsed time, part number and file size read like the edge print along a strip of film, set inside a native shell of hairline-seamed panes. On Windows it is a Windows 11 app (Fluent metrics, Segoe UI Variable); on a Mac it is a Mac app (SF, smaller controls, rounder panels). Same tokens, two metric sets, chosen by `UiLook.current`.

It is a quiet tool. Neutral grey grounds, one amber accent for selection and progress, and tally red that appears only when the app is actually recording. Depth is one step: a raised pane on a ground, divided by 1 px seams. It refuses the Material card stack and the dark neon "studio" look.

**Key Characteristics:**
- Native per OS: every metric that differs between Windows 11 and macOS is a getter on `RecLiteTokens`, never an `if` in a screen.
- Hairline-seamed panes, not cards.
- Tabular figures for every number that changes or lines up.
- One signature: the PartStrip (duration drawn as segmented parts with minute ticks) on Record and History.
- Light and dark follow the system; both palettes are first-class.

## Colors

Neutral Windows 11 / macOS greys, one film-base amber, one tally red. Widgets read colours only through `context.tokens` (`lib/app/theme/reclite_theme.dart`); raw values live in `AppPalette` (`lib/app/theme/app_tokens.dart`). Frontmatter keys without a suffix are light; `-dark` keys are the dark theme.

### Primary
- **Film-Base Amber** (`film-amber` / `film-amber-dark`): selection, focus, switches (on track), selected nav icon, text buttons, progress, LevelMeter body, PartStrip fill, the info InfoBar. `accentTint` (amber at 12% light / 16% dark) is the selected-segment fill on Windows, the selected nav fill on Mac, focus and text selection.

### Secondary
- **Tally Red** (`tally` / `tally-dark`): the record action and the live state only: Start Recording and Stop buttons (white label), TallyDot, sidebar recording pill. **Tally Ink** (`tally-ink`) is the same red tuned for text and small marks on a pane: REC, the sidebar "Recording" label, the mini bar's timer. `tallyTint` backs the sidebar recording pill.

### Neutral
- **Ground** (`ground`): window background, sidebar, area around panes. Also the launch colour (`MainFlutterWindow.swift` must match).
- **Pane / Pane Raised** (`pane`, `pane-raised`): pane surfaces are `pane-raised`; `pane` is the History header row, disabled fields and Mac unselected segments.
- **Seam / Seam Strong** (`seam`, `seam-strong`): 1 px dividers and pane borders; `seam-strong` for control outlines, ticks, scrollbar thumb and the live transport border.
- **Ink / Ink Muted** (`ink`, `ink-muted`): text. Muted carries descriptions, captions, status lines, icons, paused state.
- **Ink Faint** (`ink-faint`): disabled and inactive marks only (disabled icons and labels, the paused PartStrip).
- **Status** (`success`, `warning`, `danger`): InfoBar severities, Recovered (warning) and Interrupted (danger) stamps, destructive confirmation.

### Named Rules
**The Tally Rule.** Red means "this records or is recording". Start, Stop, REC, the tally dot and the sidebar pill; nothing else is tally red. Errors use `danger`, never `tally`. The one shared use is the LevelMeter's top two segments (clipping), a metering convention.

**The One Accent Rule.** Amber marks what is selected, focused, on or progressing. It is never decoration, never a heading colour, never a background panel.

**The Faint Ink Rule.** `ink-faint` fails body-text contrast on purpose; it is for disabled or inactive marks only, never for text a user must read.

## Typography

**Windows:** Segoe UI Variable Text (fallback Segoe UI). **macOS:** SF Pro (`.AppleSystemUIFont`). No bundled or display faces.

**Character:** System faces at their native ramps, tight 1.15 to 1.25 steps for a tool. Letter-spacing is 0 except the timecode (-0.5) and edge labels (+1.1).

### Hierarchy
Frontmatter carries the Windows (Fluent) sizes; macOS values follow in the second figure.
- **Timecode** (`displaySmall`, 300, 40 / 34 px, 1.1, tabular): the live elapsed time in the transport pane. Only place a display size appears.
- **Headline** (`headlineSmall`, 600 / 700, 28 / 22 px, 1.2): page titles in PageScaffold.
- **Title** (`titleLarge`, 600, 20 / 15 px, 1.3): dialog titles, saved-recording summary.
- **Body** (`bodyLarge` / `bodyMedium`, 400, 14 / 13 px, 1.45): row labels, messages, nav labels. `titleSmall` / `titleMedium` are body size at 600 for pane titles and InfoBar titles.
- **Button label** (`labelLarge`, 600 / 500, 14 / 13 px).
- **Caption** (`bodySmall`, 400, 12 / 11 px, ink-muted): row descriptions, pane footers, Part N · size line.
- **Edge label** (`labelSmall`, 600, 11 / 10 px, +1.1 tracking, uppercase, tabular, ink-muted): EdgeLabel only.

### Named Rules
**The Tabular Rule.** Every number that ticks or aligns (timecode, part, size, History columns) uses `FontFeature.tabularFigures()`.

**The Edge Print Rule.** Tracked capitals are for measurements and column heads (`LENGTH`, `PARTS`, `RECOVERED`), the way numbers are printed on film edge. Never as an eyebrow or kicker above a heading.

## Layout

- **Window:** minimum 760 × 560 logical px (enforced natively in `win32_window.cpp` and `MainFlutterWindow.swift`).
- **Shell:** sidebar on `ground` (220 px, icon-only 60 px when window width < 940) beside the content layer. Nav items are 36 px (Windows) / 30 px (Mac) tall.
- **Page:** `PageScaffold`: title row (headline, optional one-line status under it, the page's main action at the right), then content. Content max width 880 px; reading width 640 px. Padding 32 / 24 / 32 px sides-top-bottom on Windows, 24 / 20 / 32 on Mac; title-to-content gap 24 (Windows) / 20 (Mac).
- **Spacing:** 4 px base scale (4, 8, 12, 16, 20, 24, 32, 40, 48). 16 px between panes and rows' horizontal padding; 8 px between a pane title and the pane.
- **History:** columns Recorded (flex), Length 72, Size 76, Parts 96 when the content is ≥ 700 px; below that, Size and Parts hide.
- **Density:** controls 32 px tall on Windows, 28 px on Mac; pane rows min 52 / 44 px; icon buttons 32 px square.

## Elevation & Depth

Flat, tonal layering. A `pane-raised` surface with a 1 px `seam` border on a `ground` is the only in-page depth step. No shadows on panes, buttons or rows (filled buttons have elevation 0). Shadows exist only on true overlays: dialogs (Material elevation 8, shadow `#00000040`) and pop-up menus (elevation 6), both also seamed.

### Named Rules
**The One Step Rule.** Ground, then pane. Nothing in the page floats above a pane; if something needs more emphasis, it gets a stronger seam (`seam-strong`, as on the live transport) or the accent, not a shadow.

## Shapes

Gently rounded, per OS: controls 4 px on Windows / 6 px on Mac (`controlRadius`); panes, InfoBars, dialogs, menus, snack bars 8 px / 10 px (`paneRadius`). Small marks use 2 px (PartStrip segments, outcome stamps) or 1 px (meter segments). Borders are always 1 px. Circles are reserved for the TallyDot.

## Components

### Buttons
- **Record (tally filled):** Start Recording and Stop only. Tally background, white label, record-dot or stop icon. While recording, Start keeps its slot but goes transparent with an ink-faint label (the transport owns the live controls).
- **Primary (amber filled):** one per view at most, for a non-recording main action. Disabled: `seam` fill, muted label.
- **Secondary (outlined):** `pane-raised` fill, `seam-strong` 1 px border, ink label. Pause/Resume, Open, Show in folder.
- **Text:** amber label, no fill; links and low-weight actions.
- **Icon:** 32 px square, 20 px muted icon, control radius.
- **Hover / pressed:** 8% / 16% overlay of the foreground colour; no splash (`NoSplash`).
- Standard density, height = `controlHeight`, horizontal padding 16 (Windows) / 12 (Mac).

### Pane and PaneRow
The default container. A titled group of rows (Windows Settings group / macOS grouped form): title in `titleSmall` above, one rounded `pane-raised` box with a `seam` border, rows divided by 1 px seams, optional footer caption. **PaneRow**: optional 20 px muted icon, label with optional caption description, control at the right, optional full-width `below`. Use it for every settings-like list; never stack separate cards.

### Segmented control and switch
- **Segmented (capture mode):** Windows: `pane-raised` segments, selected `accentTint` with amber icon. Mac: `pane` segments, selected `seam-strong` fill, amber icon. 1 px `seam-strong` outline.
- **Switch:** On = amber track, white thumb. Windows off = outlined track, muted thumb; Mac off = filled `seam-strong` track, white thumb, no icon. On but locked (while recording) keeps a 45% amber track so it never reads as off.

### Inputs
**SelectBox** is the drop-down (Windows ComboBox / Mac pop-up button): control height, `pane-raised` fill, `seam-strong` border, chevron at right, menu on `pane-raised` with pane radius. Disabled: `pane` fill, muted text.

### Navigation
Sidebar on `ground`: logo and name (56 px header), then Record / History / Settings / Help. Selected item: Windows `pressed` grey fill, Mac `accentTint` fill; selected icon amber, label weight 600 (Windows) / 500 (Mac). While recording, a TallyDot badges the Record icon and a tally-tinted pill ("Recording" / grey "Paused") sits at the bottom. Compact mode shows icons with tooltips.

### InfoBar
Windows-style inline message: severity colour at 9% over `pane-raised`, 32% border, icon, title, message, actions, optional dismiss. Used for recovery banners, warnings and errors. Severity info uses amber.

### Transport (live recording)
A pane with `seam-strong` border (back to `seam` while paused): TallyDot + REC / PAUSED in tracked bold, Pause/Resume and Stop at right (96 px wide each), the timecode, a live PartStrip, then the caption line "Part N · size" and "Next part in mm:ss".

### TallyDot and LevelMeter
- **TallyDot:** 12 px circle, solid tally while live, hollow muted ring while paused. Changes animate once.
- **LevelMeter:** 120 × 6 px, 24 segments with 2 px gaps; amber body, `warning` above 75%, `tally` above 92%; dimmed track when the source is off.

### PartStrip (signature)
A recording's length drawn as it is stored: one 6 px segment per MP4 part, 3 px gaps, 2 px radius, `seam` track, amber fill, and minute ticks below in `seam-strong` (every 5th tick long when a part is 10 minutes or more). `PartStrip.live` fills the current part as it records (ink-faint while paused). `PartStrip.recorded` draws full parts and fills the last to its real length; ticks show only for 4 or fewer parts. Use it wherever duration is shown as parts; do not substitute a plain progress bar.

### EdgeLabel and outcome stamps
EdgeLabel: tracked uppercase caption for column heads and measurements. Outcome stamps in History: EdgeLabel inside a 1 px border, 2 px radius, in `warning` (Recovered) or `danger` (Interrupted). Stamps stay on the record; they are never dismissed.

### EmptyState
Unfilled box with a `seam` border and pane radius, 32 px muted icon, title, muted description (max 420 px), optional action. Teaches what will appear and how.

### Mini recording bar
Compact window: `pane-raised` with a top seam, tally dot, REC in tally ink, timer, Pause/Stop. Muted while paused or stopping.

## Do's and Don'ts

### Do:
- **Do** read colours and per-OS metrics from `context.tokens` and spacing/sizes/motion from `AppSpacing` / `AppSize` / `AppMotion`; add a new per-OS difference as a getter on `RecLiteTokens`.
- **Do** group related settings into one Pane with seamed PaneRows.
- **Do** use tabular figures for every changing or aligned number.
- **Do** keep motion to one-shot transitions: 120 ms (page and status switches), 180 ms (sidebar width, tally dot, transport), 260 ms max, `easeOutCubic`.
- **Do** check both looks in both themes with `flutter test --update-goldens tool/screenshots/screens_test.dart` (PNGs in `build/screenshots` or `$SHOTS_DIR`).
- **Do** keep visible state stamped on records (Recovered, Interrupted).

### Don't:
- **Don't** use looping or repeating animations (no pulsing REC dot, no shimmer); tests rely on `pumpAndSettle`.
- **Don't** use tally red for anything that is not the record action or live recording state; errors are `danger`.
- **Don't** stack cards, add shadows to in-page surfaces, or nest panes.
- **Don't** use glows, gradients, or gradient text.
- **Don't** put an eyebrow or kicker above a heading; EdgeLabel is for data.
- **Don't** use `ink-faint` for readable text.
- **Don't** bundle display fonts or replace the system faces.
- **Don't** hard-code Windows or Mac metrics in a screen; use the token getters.

## App icon

A graphite desktop monitor on a light neutral plate, with a tally-red recording light cut into its lower-right corner. A faint ring around the light means "live", and the amber strip on the screen is the PartStrip. Below 40 px the strip and ring are dropped and the light grows, so it still reads at 16 px. Everything is drawn by `tool/icon/make_icon.py`: it writes `assets/reclite_icon.png` (in-app logo), `assets/reclite_icon.svg` (source), `windows/runner/resources/app_icon.ico` (16–256 px, also the installer and Windows tray icon) and the macOS `AppIcon.appiconset` (Apple 824/1024 grid). Change the geometry there and rerun it; don't edit the PNGs by hand.

The Windows tray uses three versions of the icon (`windows/runner/resources/tray_{idle,recording,paused}.ico`, loaded by `packages/reclite_engine/windows/ui/tray_icon.cpp`):
- Idle: the monitor alone.
- Recording: a large red light.
- Paused: a large amber light. Amber matches the macOS menu bar's paused state.

The tray light is about twice the app icon's, so the state reads at 16 px. The macOS menu bar keeps Apple's built-in record symbols, as Mac menu-bar icons are expected to be monochrome glyphs.
