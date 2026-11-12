# Keeper of the Cove — Compliance audit

Audited 12 November 2026 against the 14 Google Play pre-submission questions.
Every answer must be **NO**. Scope: all Dart code in `lib/`, every UI string,
all 52 night names and tutorial lines, the art and sound scripts in `tool/`
and their outputs in `assets/`, `pubspec.yaml` dependencies and the Android
release manifest.

| # | Question | Answer | Evidence / where checked |
|---|----------|--------|--------------------------|
| 1 | Violence, blood or gore? | **NO** | No combat. The beam only guides (`lib/engine/sim.dart`). A boat that reaches the rocks fades into the dark with a soft puff of shadow particles (`night_painter.dart` `_vessel`, `burst`); nothing breaks, sinks dramatically or dies on screen. Copy says "lost to the dark", never wreck/death. |
| 2 | Scary or horrifying content or sounds? | **NO** | Calm night palette, no creatures or jump scares. Sounds (`tool/make_sfx.py`) are bells, a distant muffled foghorn (low-passed, 1.6 s), a breath of air, gentle chords. Ember loss = 8 px, 0.3 s shake, disabled by Reduce Motion. Night name "Ghost Lanterns" renamed to "Faint Lanterns" to remove any doubt. |
| 3 | Sexual content, nudity or revealing attire? | **NO** | No people are depicted at all: lighthouse, boats, sea, cottages, a sleeping cat. |
| 4 | Gambling (real, simulated or themed)? | **NO** | No loot boxes, wheels, dice, cards or chance-based rewards. Lamp oil is earned by fixed rules (`Progress.record`); every Chandlery item has a fixed price (`lib/data/catalog.dart`). The seeded RNG only places boats and fog. |
| 5 | Offensive language? | **NO** | All strings reviewed (screens, 52 night names, tutorials, 20 achievements, shop lines, policy). Quiet, logbook-style English only. |
| 6 | Drugs, alcohol or tobacco references? | **NO** | None. "Sea Smoke" (night 12) is the meteorological name for fog over cold water. "Lamp oil" is the lighthouse's fuel and an in-game currency. |
| 7 | Crude humour (bodily functions)? | **NO** | None in sound, animation or text. |
| 8 | Digital purchases, cash-convertible rewards or NFTs? | **NO** | No IAP, no billing library, no crypto, no ads. Lamp oil cannot be bought, sold or exchanged; it only unlocks cosmetics. Dependencies: `audioplayers`, `shared_preferences` only. |
| 9 | User communication (chat, voice, sharing)? | **NO** | Single-player and fully offline. No accounts, chat, sharing or networking code. The privacy screen offers copy-to-clipboard only. |
| 10 | Precise location sharing? | **NO** | No location code or packages. The release manifest (`android/app/src/main/AndroidManifest.xml`) declares no permissions; plugin manifests (audioplayers_android, shared_preferences_android) add none. INTERNET appears only in debug/profile manifests, which Flutter needs for development and which are not in the release build. |
| 11 | Nazi symbols or propaganda? | **NO** | No symbols, flags or historical references. Art is lighthouse, sea, boats, a village. |
| 12 | Korean historical distortion / anti-national content? | **NO** | No historical or national content. |
| 13 | Terrorism advocacy? | **NO** | None. The only goal is guiding boats safely home. |
| 14 | Realistic crime descriptions or techniques? | **NO** | None. |

**Result: 14 / 14 NO. Cleared for submission.**

Re-run this audit after any new content (nights, shop items, sounds, text) or dependency.
