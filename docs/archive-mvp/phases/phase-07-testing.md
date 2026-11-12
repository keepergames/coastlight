# Phase 07 — Testing & Bug Fixing

- **Status:** done
- **Depends on:** 06

> **Done notes:** `flutter analyze` clean; `flutter test` green (26 tests). Added `test/night_config_test.dart` (configForNight scaling/clamps), `test/game_state_test.dart` (scoring, streak multiplier, embers, win/lose, run progression), `test/widget_test.dart` (splash→menu boot + menu→Night Watch navigation), and `test/responsiveness_test.dart` (static + result screens at 360×640 and 430×930, ≥48dp touch targets). Bug fixed: the Keeper's Log left page and the Dawn tally now scroll, so a long run (many nights/souls) no longer overflows on small screens. Audio is guarded so tests never need real assets. Offline confirmed: no networking code in `lib/`; only the dev-only `debug/AndroidManifest.xml` INTERNET permission (standard Flutter, not shipped); no extra permissions introduced.
- **Can run in parallel with:** none

## What
Make the game stable and clean: static analysis, a few widget/unit tests, responsiveness checks, and an offline/permissions sanity pass.

## Why
Catch reflow and state bugs before release.

## Scope (build only this)
1. `flutter analyze` → fix all errors and warnings.
2. Replace the default counter test; add: a unit test for `configForNight` scaling, a unit test for scoring/embers in `game_state`, and a widget test that the menu navigates to the night screen.
3. Verify pause/resume integrity (timer + audio freeze), edge spawns, and that win/lose transitions fire correctly.
4. Responsiveness: confirm layouts hold on a small (~5") and large (~6.7") phone via different test surface sizes; touch targets >= 48dp.
5. Offline/permissions sanity: confirm no networking code and no extra permissions are introduced (deeper audit is the `game-privacy` skill later).

## Out of scope
No new features. No release/signing config (phase 08).

## References
- docs/GDD.md, docs/DESIGN_LANGUAGE.md — expected behavior and layout.
- docs/COMPLIANCE.md — offline, no data.

## Verify
`flutter analyze` reports no issues. `flutter test` passes. Manual run shows no crashes across the full flow.

## On completion
- Set Status to done with notes (tests added, bugs fixed).
- Update the Phase 07 row in docs/IMPLEMENTATION_PLAN.md.
