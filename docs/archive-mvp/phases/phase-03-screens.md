# Phase 03 — Screens & Navigation Flow

- **Status:** done
- **Depends on:** 01
- **Can run in parallel with:** 02 (this owns `lib/screens/`, phase 02 owns `lib/game/`)

## What
Real layouts and navigation for every screen in the GDD, wired per the UI/UX flow.

## Why
Turns the route stubs into a navigable shell from First Light to game over.

## Scope (build only this)
1. Flesh out `lib/screens/` (created in phase 01) with theme-native layouts from the GDD:
   - `splash_screen.dart` — beam sweep over the etched title, auto-advance to `/menu`.
   - `menu_screen.dart` — "The Lighthouse at Rest": world-embedded taps (lit window → `/night`, logbook → `/log`, framed notes → `/duty`, plaque → `/promise`). No vertical button list.
   - `night_screen.dart` — "The Night Watch": embed the game with `GameWidget(game: CoveGame())` (import from `lib/game/cove_game.dart`), plus a lantern pause icon (top corner) and HUD placeholders (embers, lantern quota row, dawn band) as widgets. Leave score/embers wiring to phase 05 (use static placeholders).
   - Pause "The Keeper's Rest" — an overlay/dialog on the night screen with relight / return to lighthouse / reread duty.
   - `dawn_screen.dart` (win) and `dark_screen.dart` (lose) with "Sail on" / "Light it again".
   - `log_screen.dart` (logbook spread), `duty_screen.dart` (3 swipe sketches), `promise_screen.dart` (privacy copy from GDD).
2. Wire navigation exactly per the flow diagram in GDD section 5.

## Out of scope
No game logic (phase 02). Do not implement scoring, embers, dawn timer, or persistence (phase 05) — use placeholders. Final art/audio polish is phase 06. Import `CoveGame` but do not edit files under `lib/game/`.

## References
- docs/GDD.md — sections 4 (screens) and 5 (flow), copy sheet.
- docs/DESIGN_LANGUAGE.md — layout rules, buttons, spacing, responsiveness.
- docs/COMPLIANCE.md — privacy screen states offline/no data.

## Verify
`flutter analyze` clean. Every arrow in the GDD flow diagram navigates correctly both directions. The night screen shows the game widget with HUD placeholders.

## On completion
- Set Status to done with notes (screen files, navigation map).
- Update the Phase 03 row in docs/IMPLEMENTATION_PLAN.md.

## Done — notes
**Screen files (all in `lib/screens/`):**
- `splash_screen.dart` — beam-sweep ShaderMask over the etched title; auto-advances to `/menu`.
- `menu_screen.dart` — painted dusk lighthouse scene with an idling beam; world-embedded tap regions (lit window → `/night`, logbook → `/log`, framed notes → `/duty`, brass plaque → `/promise`). No button list.
- `night_screen.dart` — `GameWidget(game: CoveGame())` full-screen; HUD placeholders (dawn band, embers, quota lanterns) in top safe area; lantern pause icon → `KeepersRest` overlay.
- `dawn_screen.dart` / `dark_screen.dart` — win/lose with "Sail on" / "Light it again".
- `log_screen.dart` — swipeable logbook spread (PageView). `duty_screen.dart` — 3 swipe sketches. `promise_screen.dart` — privacy copy.
- `widgets/cove_widgets.dart` — shared `LampGlowButton` and `CovePanel`.

**Navigation map:**
- `/` splash → (auto, pushReplacement) → `/menu`
- `/menu` → pushNamed → `/night`, `/log`, `/duty`, `/promise` (back chevron pops to menu)
- `/night` → in-screen `KeepersRest` overlay → relight (close) / return to lighthouse (`/menu`) / reread duty (`/duty`)
- `/night` → (placeholder previews in pause, pushReplacement) → `/dawn` (quota met) / `/dark` (embers lost)
- `/dawn` → "Sail on" (pushReplacement) → `/night`; `/dark` → "Light it again" (pushReplacement) → `/night`

**Notes:** No game logic — all stats/HUD are static placeholders. Win/lose triggers are placeholder buttons in the pause overlay (real triggers come from phase 05). Did not touch `lib/game/` or `lib/theme/`. `app.dart` routes already covered every screen, so no route edits were needed. `CoveGame` import is the contract-correct `package:keeper_of_the_cove/game/cove_game.dart` (owned by phase 02).
