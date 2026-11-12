# Keeper of the Cove — Design Language

**Scene:** someone in bed or on a sofa at night, phone in one hand, lights low.
That scene decides the look: a dark sea that is easy on tired eyes, with warm
light as the only thing that pulls focus. **Light is safety, dark is danger.**

**Thesis:** the interface *is* the cove. Navigation happens by touching things
in the painted world (the lamp-room window, the sea chart, the logbook, the
tide bell, the boathouse), never by a stack of menu pills. Every screen is lit
by the beam: the one warm thing on screen is the thing to touch.

## Palette — five roles, plus two text tones

| Role | Token | Hex | Job (and only this job) |
|------|-------|-----|------|
| Night sea | `CoveColors.sea` | `#0B1626` | Ground of every screen; the dark |
| Tide | `CoveColors.lift` | `#152A3F` | Water highlights, fog, dimmed scene, dividers |
| Beam | `CoveColors.beam` | `#F4B860` | The beam, the primary action, the one live control |
| Harbor glow | `CoveColors.harbor` | `#FFD9A0` | Safety and reward: harbor windows, lanterns earned, lamp oil |
| Rust | `CoveColors.danger` | `#7E4A3B` | Rocks and a lost ember. Never bright red |
| Text | `CoveColors.text` | `#EAF1F8` | Primary copy |
| Text muted | `CoveColors.textMuted` | `#8AA0B4` | Secondary copy, locked things |
| Rule | `CoveColors.rule` | `#22384F` | 1 px dividers between list rows (a darker Tide) |

Rules:
- One beam-coloured thing per screen region. If two things glow, one is wrong.
- Season art may tint the sea (fog greys, squall green-black, winter blue-white)
  inside the painted backgrounds only. UI chrome never gets a season colour.
- Gradients only where they are physical: sky at dawn, light falloff of the
  beam and windows, water depth. No gradient buttons, no gradient text.

## Typography — Spectral only (bundled, OFL)

Spectral is a screen serif with the feel of a printed logbook. It is mapped to
the Material type roles so sizes are never hand-picked per screen.

| Role | Size (sp) | Weight | Use |
|------|-----------|--------|-----|
| Display | 40 | 600, +1.5 tracking | Title, night name on the dawn screen |
| Headline | 28 | 600 | Screen titles ("The Keeper's Log") |
| Title | 20 | 600 | Section heads, season names |
| Body | 16 | 400 | Copy |
| Label | 14 | 500, +0.6 tracking | HUD, scene labels, buttons |
| Caption | 12 | 500 | Small counts under icons |

Numbers in the HUD and stats use tabular figures (`FontFeature.tabularFigures`).

## Spacing

4-pt scale: 4 / 8 / 12 / 16 / 24 / 32 / 48. Screen margin 16 (24 on the hub).
More space above a heading than below it. Separate things with space and
alignment, not boxes.

## Components

- **Scene hotspots** (hub): the painted object itself is the button. A small
  engraved label (Label role, text muted → beam when focused) sits beside it, so
  nothing is hidden. Hotspots breathe with a soft halo on a 2.6 s swell.
- **Primary action**: text in the Beam colour on the night sea with a short
  beam-light underline that brightens on press. Never a filled pill.
- **Secondary action**: Text-colour label, no fill, no border.
- **Lists** (log, settings, achievements): rows divided by a 1 px Tide line and
  space. No cards, no outlines around groups.
- **Switches**: Material 3 `Switch`, themed (beam thumb on, tide track off).
- **Dialogs**: Material dialog on Tide with a fog-in fade; only for reset and
  leaving a night.
- **Icons**: drawn in code in the world's grammar (flame for embers, hull for
  vessels, lantern for ratings, oil drop for currency). No emoji, no stock set.

## Motion

- The swell: everything floating rocks on a 2.6 s sine. Vessels are offset so
  they never move in lockstep.
- Screen changes: Material fade-through, 300 ms, `easeOutCubic`.
- Feedback: charting ring fills with a shimmer; soul home = bloom + spark burst
  at the harbor; ember lost = 8 px shake (300 ms) and the flame gutters out;
  dawn = lanterns pop in one by one (180 ms apart) with a chime.
- **Reduce motion** (setting, and the system's disable-animations flag): no
  shake, no swell on UI, crossfades instead of slides; gameplay vessels still
  move because that is the game.

## Screens

| Screen | Composition |
|--------|-------------|
| First Light (splash) | Black. The beam sweeps once across the title, which lights where the beam passes. |
| The Lighthouse at Rest (hub) | Full-bleed painting, lighthouse on the right third, village across the cove on the left. Hotspots: window → Tend the Light; chart on the gallery rail → Sea Chart; logbook → Keeper's Log; tide bell on the jetty → Daily Tide; the moon → The Longest Night; boathouse → Chandlery; brass plaque → Settings. Bottom thumb zone: "Tend the Light" with the next night's name. Village windows light up as seasons are kept. |
| Sea Chart | A nautical chart of the coast, scrolled top to bottom. Four coves are the seasons; each night is a numbered sounding on a dashed sailing line, with 0–3 lantern ticks. Unreached coves lie under painted fog. |
| The Night Watch (play) | Full sea. HUD only in the top safe area: embers left, souls-home count centre, pause lantern right, dawn band along the top edge. Lower 60 % is free for the thumb. |
| The Keeper's Rest (pause) | Scene dims to Tide. Three left-aligned choices in Headline size: Relight the watch / Reread the duty / Return to the lighthouse. |
| Dawn (win) | Sky warms from the bottom; lanterns pop in; lamp oil counts up; "Sail on" primary, "Keep this night again" secondary. |
| The Dark Watch (lose) | Beam gutters out; only harbor windows glow. Souls brought home, "Light it again". |
| Daily Tide | Tide bell illustration, streak number in Display, 28-day row of tide marks (filled = kept, ring = missed, dot = today). |
| Chandlery | Live preview vignette of the lighthouse at the top; goods below by shelf (Beam, Paint, Boats, Keepsakes); each row: name, price with oil drop, state in words (Owned / In use / price). |
| Keeper's Log | Stats as logbook entries, then achievements as a list of marks (struck = earned). |
| Settings | Sound, Music, Vibration, Reduce motion; How to play; Privacy; Open-source licences; Reset progress. No credits screen: the app names no developer or company. |

## Responsiveness

Fractional regions and `LayoutBuilder` everywhere; the game world is a fixed
1000 × 1600 logical field scaled to fit width with the sea extended to fill
height. Safe-area insets respected top and bottom. Touch targets ≥ 48 dp with
8 dp gaps. Text follows the system font scale with layouts that wrap.
