# Keeper of the Cove — Game Design Document (as built, v1.0)

**Light is safety, dark is danger.** A warm amber beam over a cold indigo sea. Nothing sharp, nothing loud.

## 1. Core loop
- The lamp sits at the bottom centre. **Drag anywhere** to turn the beam (it sweeps only over the sea).
- **Vessels** appear out of the dark at the top and drift toward the rock line.
- A boat inside the beam fills its **charting ring** (about 2.4 s of light). Out of the light the ring slowly drains. Full ring → the boat turns for the harbour on its own and counts as a **soul brought home**.
- An uncharted boat that reaches the rocks puts out one of three **embers**. No embers → **The Dark Watch** (night lost).
- Bring the night's **quota** home before **dawn** (the band along the top edge). Dawn first → **Dawn came early** (night lost).
- A kept night earns **lanterns** = embers still burning (1–3).

All rules live in `lib/engine/sim.dart` (fixed 1000 × 1600 world, deterministic for a seed).

## 2. Seasons and nights (52)
| Season | Nights | New mechanic | Finale |
|--------|--------|--------------|--------|
| Still Water | 1–10 | The beam, rings, rocks, embers | 10 · The First Fleet |
| Fog Season | 11–23 | Drifting fog banks: boats inside are faint and chart at 60 % speed | 23 · Night of Bells |
| Squall Coast | 24–37 | Convoys: only the lead can be charted; its line follows it home. If the lead is lost, the followers turn back out to sea and come in again as single boats | 37 · The Herring Fleet |
| The Long Winter | 38–52 | Bell buoys: hold the beam on a dark buoy ~1 s to kindle it; for 12 s its halo charts nearby boats on its own | 52 · Midwinter Night |

Tutorial and finale nights are hand-written; the rest follow each season's ramp (speed, arrival rate, beam reach, fog/convoys/buoys) with a fixed seed. Arrivals are unevenly spaced so two boats sometimes need you at once.

**Proof:** `test/levels_test.dart` plays every night with human-limited keeper bots (turn rate, reaction delay) and requires each to be kept; it also checks that a skilled keeper keeps fewer embers season by season.

## 3. Modes
- **Story:** the sea chart; night *n* opens when *n − 1* is kept.
- **Daily Tide:** one date-seeded night per day from the seasons reached; +20 lamp oil once per day; streak and 28-day calendar.
- **The Longest Night:** no dawn; every 22 s the sea gets busier (more boats, faster, fog, convoys, shorter beam) until the light goes out. Best count saved.

## 4. Progress and rewards
- **Lamp oil:** +1 per soul, +4 per newly earned lantern, +10 first keep of a night, +20 Daily Tide; the Longest Night pays 0.6 per soul.
- **Chandlery:** lamp glass (beam tint), tower paint, harbour liveries, keepsakes shown on the hub. Fixed prices, no randomness, nothing for real money.
- **20 marks** (achievements) and the **Keeper's Log** (stats, per-season lanterns).
- The hub changes: village windows light with kept seasons, kept boats ride at anchor, keepsakes appear.

## 5. Screens
First Light (splash) → The Lighthouse at Rest (hub: moon = Longest Night, lamp window = Tend the Light, chart = Sea Chart, boathouse = Chandlery, tide bell = Daily Tide, cottage window = Keeper's Log, brass plaque = Settings) → The Night Watch (play) with The Keeper's Rest (pause) → Dawn / The Dark Watch / Dawn came early. How to Play (The Keeper's Duty) opens on first launch and includes a practice sea. Settings holds sound, music, vibration, reduce motion, how to play, privacy (A Quiet Promise), open-source licences and Clear all progress (with confirmation).

## 6. Feel
Swell on a 2.6 s sine; ring bead and shimmer; charted chime and spark; harbour bloom and bell when a soul is home; soft foghorn, a guttering ember and a small shake when one is lost; lanterns pop in one by one at dawn. Reduce Motion removes the shake, the swell and moving light.

## 7. Copy sheet
| String | Use |
|--------|-----|
| Tend the Light | Start the next night |
| Sea Chart | Night select |
| The Keeper's Rest / Relight the watch | Pause / resume |
| Return to the lighthouse | Back to hub |
| Dawn / Sail on | Night kept / next night |
| The Dark Watch / Light it again | Night lost / retry |
| Dawn came early | Quota missed at dawn |
| embers · lanterns · lamp oil · souls brought home | Lives · rating · currency · score |
