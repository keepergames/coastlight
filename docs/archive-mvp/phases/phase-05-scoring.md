# Phase 05 — Scoring & Win/Lose + Persistence

- **Status:** done
- **Depends on:** 04
- **Can run in parallel with:** none

## What
Run state and rules: embers, the night quota, the dawn timer, scoring with a streak multiplier, win/lose transitions, and persisted best stats.

## Why
Completes the game's stakes and feeds the logbook.

## Scope (build only this)
1. `lib/game/game_state.dart`: a `ChangeNotifier` (or Flame-friendly state object) holding embers (start 3), souls-home this night, quota (from `NightConfig`), score, current streak + multiplier, dawn timer remaining, and current night number.
2. Wire `CoveGame` hooks (`onVesselSaved` / `onVesselLost` from phase 02) into `game_state`: saved → +score, +streak, +1 toward quota; lost → reset streak, -1 ember.
3. Win when souls-home reaches quota before the dawn timer fills → navigate to `/dawn`. Lose when embers hit 0 → navigate to `/dark`. Dawn timer counts down during play and pauses with the game.
4. Replace the HUD placeholders on the night screen with live values from `game_state` (embers, lantern quota row, dawn band). This is the only allowed edit to `lib/screens/night_screen.dart`.
5. Persist best run with `shared_preferences`: most souls home, nights survived, longest streak. Expose a small `BestStats` loader the log screen reads.
6. Wire `/dawn` "Sail on" to advance the night (increment night, new `NightConfig`, reset embers per design) and `/dark` "Light it again" to restart at night 1.

## Out of scope
No new mechanics. No audio/art polish (phase 06). Do not change difficulty math (phase 04) or game component internals beyond using the existing hooks.

## References
- docs/GDD.md — section 7 (scoring, win/lose), section 3 (pause freezes timer).
- docs/DESIGN_LANGUAGE.md — HUD styling.
- docs/COMPLIANCE.md — local persistence only, no network/accounts.

## Verify
`flutter analyze` clean. Saving vessels fills the quota and triggers Dawn; losing 3 triggers The Dark Watch; pause freezes the dawn timer; best stats survive an app restart and show in the logbook.

## On completion
- Set Status to done with notes (state API, prefs keys).
- Update the Phase 05 row in docs/IMPLEMENTATION_PLAN.md.

## Completion notes
- **State API:** `lib/game/game_state.dart` — `GameState extends ChangeNotifier`, single shared `GameState.instance` so state survives the night→dawn→night route hops within a run. Per-night fields: `config` (NightConfig), `embers` (start 3, `startingEmbers`), `soulsHome`, `quota` (from config), `streak`, `multiplier`, `dawnRemaining`/`dawnTotal` + `dawnProgress` getter (0→1 band fill), `outcome` (`NightOutcome.playing/won/lost`). Run accumulators: `score`, `runSoulsHome`, `nightsSurvived`, `runLongestStreak`. Methods: `startNewRun()`, `advanceNight()`, `consumeContinueOrStartRun()`, `registerSaved()`, `registerLost()`, `tick(dt)`. Scoring: save → `streak++`, `multiplier = (1 + streak~/3).clamp(1,5)`, `score += multiplier`; lost → streak/multiplier reset, `embers--`. Dawn deadline = `quota * 18s`.
- **Win/lose/pause wiring:** `night_screen.dart` creates `CoveGame(config: _state.config)` and binds `onVesselSaved`/`onVesselLost` to `registerSaved`/`registerLost`. A `Ticker` calls `_state.tick(dt)` each frame; pause sets `_game.paused = true` and stops the ticker (freezes drift + dawn timer per GDD §3). The screen listens to `GameState`: `outcome == won` → `/dawn`, `lost` → `/dark` (post-frame `pushReplacementNamed`). Quota met → won. Embers 0 → lost. Dawn timer reaching 0 before quota → lost (failed the deadline). Dawn "Sail on" calls `advanceNight()` then `/night` (continues run); The Dark Watch "Light it again" → `/night` (fresh run at night 1). HUD (embers / lantern quota row / dawn band) reads live `GameState` via a `ListenableBuilder`.
- **shared_preferences keys (best run, max across runs, local only):** `cove_best_souls_home`, `cove_best_nights_survived`, `cove_best_longest_streak`. `BestStats.load()` exposes them for the logbook (log screen left unwired here per the edit restriction — only night/dawn/dark were editable).
- **flutter analyze:** clean (No issues found).
