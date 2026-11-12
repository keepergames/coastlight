# Phase 04 — Levels, Progression & Difficulty

- **Status:** done
- **Depends on:** 02
- **Can run in parallel with:** none

## What
A night configuration table and a spawner that scales the four difficulty dials per night.

## Why
Turns the single-vessel prototype into a climbing, level-based challenge.

## Scope (build only this)
1. `lib/game/night_config.dart`:
   - `class NightConfig { final int night, quota, maxVesselsAtOnce; final double vesselSpeed, beamReach; final int rockDensity; }`
   - A function `NightConfig configForNight(int night)` implementing the table in GDD section 6, clamping/scaling sensibly for nights past 7.
2. Update `CoveGame` (phase 02) to take a `NightConfig` (add an optional constructor param, default to night 1 so phase 03's `CoveGame()` still compiles) and drive: spawn cadence + `maxVesselsAtOnce`, vessel speed, beam reach (fog shortens the cone length), and rock density.

## Out of scope
No score/embers/timer/persistence (phase 05). No win/lose screen transitions yet. No audio/art polish (phase 06). Keep the default `CoveGame()` constructor working for phase 03.

## References
- docs/GDD.md — section 6 (progression table), section 1 (dials).
- docs/COMPLIANCE.md — keep all NO.

## Verify
`flutter analyze` clean. Higher night numbers visibly increase vessel count/speed/rocks and shorten beam reach. `CoveGame()` still constructs with no args.

## On completion
- Set Status to done with notes (config API, how dials are applied).
- Update the Phase 04 row in docs/IMPLEMENTATION_PLAN.md.

## Completion notes
**Config API** (`lib/game/night_config.dart`):
- `class NightConfig { final int night, quota, maxVesselsAtOnce; final double vesselSpeed, beamReach; final int rockDensity; }` (const ctor, all named-required).
- `NightConfig configForNight(int night)` implements the GDD §6 table by band: night 1, nights 2-3, nights 4-6, and night 7+. Inputs `< 1` clamp to night 1. Night 7+ keeps climbing then clamps: quota `14 + (n-7)*2`; speed `→ 96` cap; `beamReach → 0.45` floor; `rockDensity → 40` cap. `vesselSpeed` is px/s; `beamReach` is a multiple of screen height; `rockDensity` is rock-teeth count.

**How the four dials are applied** (`cove_game.dart`):
- `CoveGame({NightConfig? config})` defaults to `configForNight(1)`, so `CoveGame()` still compiles for phase 03.
- **Vessels at once + cadence:** `_trySpawn` gates on `children.whereType<Vessel>().length >= config.maxVesselsAtOnce`; spawn `TimerComponent` period `= 3.6 - 0.5 * maxVesselsAtOnce` (busier nights spawn more often).
- **Vessel speed:** drift uses `config.vesselSpeed` (was hardcoded 46).
- **Beam reach (fog):** `_beam.reach = size.y * config.beamReach` shortens the cone length.
- **Rock density:** `Rocks(teeth: config.rockDensity)` — `Rocks` gained an optional `teeth` param (default 16) driving the number of hazard teeth rendered.

No scoring/embers/timer/persistence, no win/lose transitions, no audio/art added. `flutter analyze`: no issues.
