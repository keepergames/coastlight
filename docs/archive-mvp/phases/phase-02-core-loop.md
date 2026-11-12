# Phase 02 — Core Mechanic & Gameplay Loop

- **Status:** done
- **Depends on:** 01
- **Can run in parallel with:** 03 (this owns `lib/game/`, phase 03 owns `lib/screens/`)

## What
The playable core in Flame: a lighthouse that casts a draggable beam, vessels that drift toward the rocks, charting a vessel home by holding the beam on it, and losing it to the rocks/dark.

## Why
This is the entire fun. Prove it in isolation before screens, difficulty, or scoring wrap it.

## Scope (build only this)
1. `lib/game/cove_game.dart`: `class CoveGame extends FlameGame with DragCallbacks` (or pan input). Default constructor must work with no args so `GameWidget(game: CoveGame())` is valid for phase 03.
2. `lib/game/components/`:
   - `lighthouse.dart` — fixed bottom-center component.
   - `beam.dart` — a cone/triangle from the lighthouse at an angle controlled by drag. Use a point-in-cone test for "is this vessel lit"; do NOT implement real lighting.
   - `vessel.dart` — drifts from a dark edge toward the cove mouth; has a `chartProgress` (0..1) that rises while lit and falls slowly while unlit; on full, turns and sails into harbor (despawn = saved); on reaching rocks or leaving screen unlit, despawn = lost. Expose `VoidCallback onSaved` / `onLost` hooks.
   - `harbor.dart` — the lit safe zone vessels sail into.
   - `rocks.dart` — the hazard line at the cove mouth.
3. Drag handling in `CoveGame` updates the beam angle. Spawn a single vessel on a timer for now (difficulty comes in phase 04).
4. Expose simple hooks on `CoveGame`: `void Function()? onVesselSaved` and `void Function()? onVesselLost` so later phases can wire scoring without editing internals.

## Out of scope
No difficulty table/scaling (phase 04). No score/embers/timer/persistence (phase 05). No Flutter screens or navigation (phase 03). Minimal placeholder shapes are fine; visual polish is phase 06.

## References
- docs/GDD.md — sections 1, 2, 6 (mechanic, what scales later).
- docs/DESIGN_LANGUAGE.md — use `CoveColors` for placeholder shapes.
- docs/COMPLIANCE.md — guiding only, no harm depicted.

## Verify
Run the game (embed `CoveGame` in a temporary `GameWidget`, or via phase 03's screen once available). Dragging sweeps the beam; holding it on a vessel fills its ring and sends it to harbor; ignoring a vessel lets it reach the rocks and despawn. `flutter analyze` clean.

## On completion
- Set Status to done with notes (component files, the `CoveGame` hook names).
- Update the Phase 02 row in docs/IMPLEMENTATION_PLAN.md.

### Completion notes
- `lib/game/cove_game.dart`: `class CoveGame extends FlameGame with DragCallbacks`, no-arg constructor. Hooks: `void Function()? onVesselSaved` and `void Function()? onVesselLost`. Drag (`onDragStart`/`onDragUpdate`) aims the beam; a `TimerComponent` spawns one vessel at a time.
- `lib/game/components/`: `lighthouse.dart` (fixed bottom-center, exposes `apex`), `beam.dart` (amber cone, point-in-cone `illuminates()` test — no real lighting), `vessel.dart` (`chartProgress` rises while lit / decays while dark, sails to harbor when full, lost at rocks/off-screen; `onSaved`/`onLost` VoidCallbacks), `harbor.dart` (lit safe zone, `safePoint`), `rocks.dart` (hazard line, `hazardY`).
- `flutter analyze`: No issues found.
