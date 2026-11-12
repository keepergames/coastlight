# Keeper of the Cove — Improvement Plan (2026-11-12)

## 1. Audit — what the game is today

A calm one-thumb real-time game. A lighthouse sits at the bottom of the screen;
you drag to sweep its amber beam. Vessels drift down toward the rocks; holding
the beam on one fills its charting ring and it sails into the harbor. Three
embers (lives), a quota per night, a dawn timer.

| Area | State |
|------|-------|
| Core loop | Works. Logic lives inside Flame components (not testable without Flame). |
| Levels | `configForNight(n)`: 4 hand bands, then numbers climb forever. No chapters, no new mechanics, nothing to unlock. |
| Screens | Splash, menu (in-world taps), play, pause overlay, dawn, dark, log, how-to-play, privacy. No settings, credits, shop, stats, achievements, daily. |
| Retention | Only a "best run" record. Nothing pulls a player back tomorrow. |
| Art | All shapes (triangle boats, flat rocks). No images. |
| Sound | `SystemSound.click` only. Docs mention flame_audio placeholders that do not exist. |
| Tests | 26, green. `flutter analyze` clean. Flutter 3.47.9. |
| Android | applicationId `com.coastlight.keeper_of_the_cove`, label "Keeper of the Cove", no release permissions. Workflow exists (`COASTLIGHT_*` secrets) but uses v4 actions and an unpinned Flutter. |
| Risks found | **Keystore and its base64 were inside `docs/`** → moved to `android/app/` (gitignored), not regenerated. No trademark or clone problems with the name or concept. No dead concept to archive; old phase briefs move to `docs/archive-mvp/`. |

Names agree everywhere (app label, Dart package `keeper_of_the_cove`, docs).

## 2. Improved concept

**Keeper of the Cove** stays a gentle guardianship game, one beam and limited
attention, played across one year of a keeper's life. Four seasons are four
chapters. Each season adds one new thing to the sea and ends on a named night
you will remember.

How a night plays: vessels drift in from the dark. You sweep the beam, hold it
on a vessel until its ring fills, and it turns for the harbor. Lose one to the
rocks or the dark and an ember goes out. Bring the quota home before dawn and
you keep the lanterns for the embers you still hold (1–3).

## 3. Content — 52 nights in 4 seasons

Why these numbers: a night lasts 60–100 s, so this is an arcade-length round
and needs more levels than a slow puzzle. Chapters are deliberately uneven:
the first season is short so a new player reaches the first new mechanic in
about ten minutes; later seasons are longer because their mechanics combine.

| # | Season | Nights | New mechanic | Tutorials | Finale |
|---|--------|--------|--------------|-----------|--------|
| 1 | Still Water | 1–10 (10) | Beam, charting ring, rocks, embers | 1–2 | 10 · *The First Fleet* |
| 2 | Fog Season | 11–23 (13) | Drifting fog banks: vessels inside are hidden and chart at half speed | 11–12 | 23 · *Night of Bells* |
| 3 | Squall Coast | 24–37 (14) | Convoys: a lead boat with followers; chart the lead and the line follows it home, but the line is long and slow | 24–25 | 37 · *The Herring Fleet* |
| 4 | The Long Winter | 38–52 (15) | Bell buoys: sweep the beam over a dark buoy to kindle it; for a while its halo charts nearby vessels on its own | 38–40 | 52 · *Midwinter Night* |

Mix: tutorials and finales are hand-written specs; the rest are generated from a
per-season ramp with a fixed seed (so every build has the same nights). Finales
use scripted waves (e.g. *The First Fleet* sends three boats at once from three
directions).

**Every night is proven winnable by a test.** A `KeeperBot` with human limits
(beam turn rate 2.4 rad/s, 0.25 s reaction delay) plays every night in the pure
Dart simulation and must win with at least one ember. A slower bot must find
later seasons harder (difficulty ramp check).

## 4. Retention (all offline, no purchases)

- **Daily Tide** — one date-seeded night per day mixing unlocked mechanics;
  streak count and a 28-day calendar of lit and unlit days.
- **The Longest Night** — endless: the sea keeps getting busier until the last
  ember goes out. Best count saved.
- **20 achievements** (local), e.g. first soul home, clear a season with every
  lantern, 7-day Daily Tide streak, 100 souls in one Longest Night.
- **Keeper's Log** — stats: souls home, nights kept, lanterns, best streak,
  time at the lamp, per-season progress.
- **Chandlery (shop)** — cosmetics only, paid with **lamp oil** earned by
  playing (1 per soul, bonus per lantern). Fixed prices, no random rewards.
  Beam tints, lighthouse paint, harbor boat styles, and keepsakes that appear
  on the hub (wind vane, herb garden, a sleeping cat).
- Hints do not apply to a real-time game. Restart and pause are always free.

## 5. Hub

The lighthouse at dusk with the cove behind it. As seasons are kept, the
village across the cove lights up window by window, boats fill the harbor,
and bought keepsakes appear around the lamp room. A sea chart opens the
night list for each season.

## 6. Feel, art, sound

- Engine moved to pure Dart (`lib/engine/`), rendered with a `CustomPainter`
  on a `Ticker`. Flame is removed (smaller app, simpler tests).
- Painted backgrounds per season, a hub illustration, vessel/buoy/lighthouse
  sprites and the logo, all generated by scripts in `tool/` at phone resolution.
- Juice: ring fill shimmer, wake trails, a soft bloom and spark burst when a
  soul is home, gentle shake when an ember goes out, lantern pop-in on dawn.
- SFX synthesised in `tool/make_sfx.py` (beam hum, chart tick, soul home,
  ember out, dawn, unlock, purchase, menu) plus a looping sea-and-wind bed.
- Settings: sound, music, vibration, reduce motion, reset progress (confirm).
- Accessibility: never colour alone (ring shape + lantern count), Semantics
  labels, 48 dp targets.

## 7. Play readiness checklist

- [ ] Launcher icon from our own logo (adaptive)
- [ ] Store kit: 512 icon, 1024×500 feature graphic, ≥5 screenshots, 20–60 s video
- [ ] `STORE_LISTING.md` with Data Safety (no data) and content rating answers
- [ ] Privacy policy (doc + in-app screen) — **publisher details pending from the user**
- [ ] Compliance audit: 14/14 NO
- [ ] Privacy audit + `.gitignore` scrub
- [ ] Workflow: pinned Flutter 3.47.9, v5/v7 actions, Android toolchain matched to template
- [ ] Green GitHub Actions run with AAB + APK artifacts (after the user names a repo)

## 8. Roadmap

1. Engine + levels + bot proof (tests)
2. Save/progress, retention systems
3. Screens rebuilt to the design language
4. Art + sound scripts, wire assets
5. Web preview, critique, polish
6. Icon, toolchain, store kit, video
7. Privacy, compliance, CI, local git commit
