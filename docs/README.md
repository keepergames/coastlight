# Keeper of the Cove — Design Docs

**Pitch:** A calm one-thumb game. You keep a lighthouse on a rocky cove. Through the dark, lost boats drift toward the rocks; you sweep your beam to find them and hold it steady until each one turns for home. One beam, many boats, limited attention.

## Pillars
- **Gentle guardianship, not combat.** You guide; you never harm.
- **One beam, limited attention.** New seasons add choices, not new controls.
- **Calm, not empty.** The sea feels alive; failure is soft and retry is instant.
- **Earned, never sold. Private by default.** Offline, no ads, no purchases, no data.

## What is in the game
- 52 nights in 4 seasons: Still Water (beam), Fog Season (fog banks), Squall Coast (convoys), The Long Winter (bell buoys). Tutorials open each season; a named finale closes it.
- Daily Tide (date-seeded, streak calendar), The Longest Night (endless), 20 marks, Keeper's Log, the Chandlery (cosmetics for earned lamp oil).
- Painted seasons, hub and sprites from `tool/make_art.py`; sounds and music from `tool/make_sfx.py`; icon and store art from `tool/make_store_art.py`.

## Tech
- Flutter 3.47.9, Android only. Rules engine in pure Dart (`lib/engine/`), drawn with a `CustomPainter` on a `Ticker`.
- `shared_preferences` (one JSON save on the device) and `audioplayers` (bundled sounds). No network, no permissions.
- Font: Spectral, bundled (SIL OFL).

## Code map
| Path | What |
|------|------|
| `lib/engine/` | `sim.dart` rules, `seasons.dart` the 52 nights, `modes.dart` daily/endless, `bot.dart` the test keeper |
| `lib/data/` | `progress.dart` save, rewards, achievements; `catalog.dart` Chandlery goods |
| `lib/game/` | `night_painter.dart` renderer, `art.dart` image loading |
| `lib/screens/` | splash, hub, chart, night, result, daily, shop, log, settings, duty (how to play), promise (privacy) |
| `test/` | engine rules, every night winnable + difficulty ramp, progress/save, widget flows |
| `tool/` | art, sound, store art, level tuning, screenshot and video scripts |

## Documents
- [IMPROVEMENT_PLAN.md](IMPROVEMENT_PLAN.md) — audit and the plan this build follows.
- [GDD.md](GDD.md) — the game as built.
- [DESIGN_LANGUAGE.md](DESIGN_LANGUAGE.md) — palette, type, components, motion, screens.
- [COMPLIANCE.md](COMPLIANCE.md) — Play pre-submission audit (14/14 NO).
- [PRIVACY_POLICY.md](PRIVACY_POLICY.md) — the policy to publish at the publisher's /privacy-policy/ page.
- [TERMS_OF_SERVICE.md](TERMS_OF_SERVICE.md) — the terms to publish at the publisher's /terms-of-service/ page (Play Console trader-status form).
- [RELEASE.md](RELEASE.md) — signed builds through GitHub Actions.
- [archive-mvp/](archive-mvp) — the original MVP phase plan, kept for history.
