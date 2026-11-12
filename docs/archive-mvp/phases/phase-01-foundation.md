# Phase 01 — Theme & App Foundation

- **Status:** done
- **Depends on:** none
- **Can run in parallel with:** none (everything depends on this)

## What
The shared theme module, the app shell with named routes, and empty screen stubs the rest of the game plugs into.

## Why
Establishes the palette, fonts, spacing, and navigation contract so phases 02 and 03 can build against stable shared pieces.

## Scope (build only this)
1. `lib/theme/cove_theme.dart`:
   - `CoveColors` with the palette from DESIGN_LANGUAGE.md (sea `#0B1626`, lift `#152A3F`, beam `#F4B860`, harbor `#FFD9A0`, danger `#7E4A3B`, text `#EAF1F8`, textMuted `#8AA0B4`).
   - `CoveSpacing` with the 4-pt scale.
   - `CoveText` helpers using `google_fonts` Spectral (display, title, body, hud) with sizes/weights from the design doc.
   - A `ThemeData` (`coveTheme`) wiring colors + text.
2. `lib/main.dart`: `runApp(const KeeperApp())`.
3. `lib/app.dart`: `KeeperApp` = `MaterialApp` using `coveTheme`, `initialRoute: '/'`, and a `routes` map with these named routes pointing at the stubs below: `/` splash, `/menu`, `/night` gameplay, `/rest` pause (or handled as overlay), `/log`, `/duty`, `/promise`, `/dawn`, `/dark`.
4. `lib/screens/` stubs (one file each, simple `Scaffold` with the themed background and the screen's title text): `splash_screen.dart`, `menu_screen.dart`, `night_screen.dart`, `log_screen.dart`, `duty_screen.dart`, `promise_screen.dart`, `dawn_screen.dart`, `dark_screen.dart`. Use the exact theme-native titles from the GDD copy sheet.

## Out of scope
No game logic (phase 02), no real screen layouts/navigation behavior beyond routes existing (phase 03), no audio/animation polish (phase 06).

## References
- docs/DESIGN_LANGUAGE.md — palette, typography, spacing.
- docs/GDD.md — copy sheet for screen titles.
- docs/COMPLIANCE.md — keep all checks NO.

## Verify
`flutter analyze` passes with no errors. `flutter run` (or build) launches to the splash stub without crashing.

## On completion
- Set Status to done with notes (files added, route names).
- Update the Phase 01 row in docs/IMPLEMENTATION_PLAN.md.

## Completion notes
- **Files added:**
  - `lib/theme/cove_theme.dart` — `CoveColors`, `CoveSpacing`, `CoveText` (Spectral via google_fonts), `coveTheme` `ThemeData`.
  - `lib/main.dart` — `runApp(const KeeperApp())`.
  - `lib/app.dart` — `KeeperApp` `MaterialApp` using `coveTheme`, `initialRoute: '/'`, named routes.
  - `lib/screens/` stubs: `splash_screen.dart`, `menu_screen.dart`, `night_screen.dart`, `log_screen.dart`, `duty_screen.dart`, `promise_screen.dart`, `dawn_screen.dart`, `dark_screen.dart`.
  - Updated `test/widget_test.dart` to launch `KeeperApp` (removed stale `MyApp` reference).
- **Named routes:** `/` (First Light / splash), `/menu` (The Lighthouse at Rest), `/night` (The Night Watch), `/log` (The Keeper's Log), `/duty` (The Keeper's Duty), `/promise` (A Quiet Promise), `/dawn` (Dawn), `/dark` (The Dark Watch). `/rest` (pause) intentionally deferred — handled as an overlay in a later phase.
- **Verify:** `flutter analyze` → No issues found.
