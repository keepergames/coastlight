# Phase 06 — Art, Sound & Theme Polish

- **Status:** done
- **Depends on:** 03, 05
- **Can run in parallel with:** none

## Completion notes

**Theme/spacing:** `CoveColors`, Spectral type (`CoveText`), and the 4-pt
`CoveSpacing` scale were already applied across every screen and the game; left
intact and reused for all new polish.

**Motion / fog / glow (approach — all hand-drawn on canvas, no asset art):**
- New `Sea` component (priority -10, behind everything): translucent `lift`
  swell lines that bob on a slow 3s sine and shimmer sideways — the whole scene
  sways like water.
- `Vessel`: gentle ~2.6s rocking via the component `angle` (random per-vessel
  phase offset so they don't sway in lockstep).
- `Beam`: soft outer glow added (blurred cone pass under the crisp cone) plus a
  warm lamp-room bloom at the apex.
- New `Fog` component (priority 50, in front): blurred drifting fog banks whose
  count/opacity scale with `_fogDensity`, derived only from the night's
  `beamReach` (foggier nights look foggier). Purely visual — never touches the
  cone/lit test.
- Menu beam idle-sweep and the splash beam-sweep were already present (kept).
- Pause dialog (`KeepersRest`) now **fades in like fog** via a
  `TweenAnimationBuilder` opacity tween.
- **3-2-1 relight count-in:** "Relight the watch" now runs a 3→2→1 beam-flicker
  count-in (`_RelightCountIn`, opacity/scale pulse per number) while the game +
  dawn timer stay frozen, then continues exactly where it stopped.

**Audio (flame_audio, calm per COMPLIANCE):**
- Low ambient sea loop via `FlameAudio.bgm.play('ambient_sea_loop.ogg')` started
  in `CoveGame.onLoad`; pauses/resumes with the game (`pauseAmbient`/
  `resumeAmbient`, called from the night screen on pause and after the count-in)
  and stops in `CoveGame.onRemove`.
- Gentle chime via `FlameAudio.play('soul_home_chime.ogg')` fired when a vessel
  is charted home.
- All audio calls are guarded with try/catch so missing assets never crash.
- **Assets are PLACEHOLDERS.** Required real files (drop in to enable sound):
  - `assets/audio/ambient_sea_loop.ogg` — soft seamless-looping sea bed.
  - `assets/audio/soul_home_chime.ogg` — single warm, gentle chime.
  Registered via `assets/audio/` in `pubspec.yaml`; see `assets/audio/README.md`.

**Logbook wiring (carried over from Phase 05):** `lib/screens/log_screen.dart`
now loads persisted best stats with `BestStats.load()` in `initState`. Left page
lists nights survived as dated "Night I … kept till dawn" entries (capped at 20,
with an empty-state line before any save); right page tallies souls brought
home, nights survived, and longest safe streak.

**Verify:** `flutter analyze` → No issues found.

## What
Bring the prototype up to the design language: palette, motion, fog, beam glow, and gentle ambient audio.

## Why
Turns a working prototype into the calm, warm experience the GDD promises.

## Scope (build only this)
1. Apply `CoveColors`, Spectral type, and the 4-pt spacing consistently across every screen and the game.
2. Motion: slow 2-3s rocking on sea/vessels; the beam idles by sweeping slowly on the menu; fog overlay; soft outer glow on the beam and harbor; dialogs fade in like fog.
3. Audio via `flame_audio`: a low ambient sea loop and a gentle chime when a soul is brought home. Respect pause (audio stops/resumes). Add asset files under `assets/audio/` and register them in `pubspec.yaml`. If no audio assets are available, wire the code and leave clearly-named placeholder asset paths documented in notes.
4. Splash beam-sweep animation and the 3-2-1 relight count-in.

## Out of scope
No new gameplay, scoring, or difficulty logic. No release config (phase 08).

## References
- docs/DESIGN_LANGUAGE.md — all of it.
- docs/GDD.md — per-screen spatial descriptions, splash, resume count-in.
- docs/COMPLIANCE.md — audio must stay calm (no scary sounds).

## Verify
`flutter analyze` clean. Each screen matches the design language; rocking/fog/glow visible; ambient loop plays and the save chime fires; audio respects pause.

## On completion
- Set Status to done with notes (assets added, animation approach).
- Update the Phase 06 row in docs/IMPLEMENTATION_PLAN.md.
