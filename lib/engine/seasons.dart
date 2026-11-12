import 'dart:math' as math;

import 'night_spec.dart';
import 'rng.dart';

/// One chapter of the keeper's year.
class Season {
  const Season({
    required this.index,
    required this.name,
    required this.blurb,
    required this.mechanic,
    required this.first,
    required this.last,
  });

  final int index;
  final String name;
  final String blurb;
  final Mechanic mechanic;

  /// First and last night ids (inclusive).
  final int first;
  final int last;

  int get length => last - first + 1;
  Iterable<int> get nightIds => Iterable.generate(length, (i) => first + i);
}

const List<Season> seasons = [
  Season(
    index: 0,
    name: 'Still Water',
    blurb: 'Calm autumn nights. Learn the beam.',
    mechanic: Mechanic.beam,
    first: 1,
    last: 10,
  ),
  Season(
    index: 1,
    name: 'Fog Season',
    blurb: 'Banks of fog roll across the cove and hide the boats inside.',
    mechanic: Mechanic.fog,
    first: 11,
    last: 23,
  ),
  Season(
    index: 2,
    name: 'Squall Coast',
    blurb: 'Fishing fleets sail in convoy. Light the lead and the line follows.',
    mechanic: Mechanic.convoy,
    first: 24,
    last: 37,
  ),
  Season(
    index: 3,
    name: 'The Long Winter',
    blurb: 'Kindle the bell buoys. Their halos guide boats while you work.',
    mechanic: Mechanic.buoy,
    first: 38,
    last: 52,
  ),
];

const int nightCount = 52;

const List<String> _names = [
  // Still Water
  'The First Light', 'Two Lamps on the Water', 'Slack Tide', 'Mackerel Sky',
  'The Quiet Bell', 'A Lantern Each', 'Rising Swell', 'Cold Stars',
  'Long Shadows', 'The First Fleet',
  // Fog Season
  'Grey Morning Coming', 'Sea Smoke', 'The Lost Horn', 'Wool on the Water',
  'Half-Seen Sails', 'The Drifting Wall', 'Breath of the Bay',
  'Faint Lanterns', 'Thick as Milk', 'Bells in the Murk', 'The Blind Hour',
  'Fogbound', 'Night of Bells',
  // Squall Coast
  'Follow the Leader', 'Three in a Line', 'Whitecaps', "The Pilot's Path",
  'Sudden Squall', 'Rope and Wake', 'Salt Spray', 'Running Before the Wind',
  'The Long Line', 'Black Water', 'Gale Warning', 'Lines in the Storm',
  'Storm Lanterns', 'The Herring Fleet',
  // The Long Winter
  'First Frost', 'Ringing the Buoy', 'Two Bells Burning', 'Ice on the Rail',
  'The Hollow Moon', 'Snow on the Swell', 'Frozen Stars', 'Northern Lights',
  'Brittle Night', 'The Iron Sea', 'Longest Shadow', 'Hearth Glow',
  'Before the Thaw', "Winter's Edge", 'Midwinter Night',
];

Season seasonOf(int nightId) =>
    seasons.firstWhere((s) => nightId >= s.first && nightId <= s.last);

String nightName(int id) => _names[id - 1];

double _lerp(double a, double b, double t) => a + (b - a) * t;

/// Souls needed for a night of about [seconds] at one arrival per
/// [spawnPeriod] (convoys bring [convoy] extra boats per arrival on average).
int _quotaFor(double seconds, double spawnPeriod, {double convoy = 0}) =>
    (seconds / spawnPeriod * (1 + convoy)).round();

/// Dawn gives a careful player room to spare over the night's natural length.
double _dawnFor(double seconds) => 20 + seconds * 1.4;

/// The night with id 1..52.
NightSpec nightSpec(int id) {
  assert(id >= 1 && id <= nightCount);
  return _handWritten(id) ?? _generated(id);
}

final List<NightSpec> allNights =
    List.unmodifiable(List.generate(nightCount, (i) => nightSpec(i + 1)));

/// Generated nights follow their season's ramp, with a little seeded variety.
NightSpec _generated(int id) {
  final s = seasonOf(id);
  final p = (id - s.first) / math.max(1, s.length - 1); // 0..1 through season
  final rng = Rng(hashSeed('cove-night-$id'));
  final jitter = rng.range(-0.04, 0.04);
  final t = (p + jitter).clamp(0.0, 1.0);

  // Each night aims for a natural length; quota and dawn follow from it.
  final seconds = _lerp(62, 92, t);
  switch (s.index) {
    case 0:
      final spawn = _lerp(3.6, 2.6, t);
      return NightSpec(
        id: id,
        season: 0,
        name: nightName(id),
        quota: _quotaFor(seconds, spawn),
        dawnSeconds: _dawnFor(seconds),
        maxAtOnce: t < 0.4 ? 3 : 4,
        spawnPeriod: spawn,
        speed: _lerp(88, 140, t),
        beamReach: _lerp(0.82, 0.66, t),
        rockTeeth: _lerp(12, 18, t).round(),
        seed: hashSeed('seed-$id'),
      );
    case 1:
      final spawn = _lerp(4.0, 3.1, t);
      return NightSpec(
        id: id,
        season: 1,
        name: nightName(id),
        quota: _quotaFor(seconds, spawn),
        dawnSeconds: _dawnFor(seconds),
        maxAtOnce: 4,
        spawnPeriod: spawn,
        speed: _lerp(98, 134, t),
        beamReach: _lerp(0.76, 0.64, t),
        rockTeeth: _lerp(16, 22, t).round(),
        fogBanks: t < 0.3 ? 1 : (t < 0.75 ? 2 : 3),
        fogRadius: _lerp(140, 175, t),
        fogSpeed: _lerp(18, 30, t),
        seed: hashSeed('seed-$id'),
      );
    case 2:
      final spawn = _lerp(4.2, 3.2, t);
      final chance = _lerp(0.3, 0.45, t);
      final max = t < 0.5 ? 2 : 3;
      final avg = chance * (max + 1) / 2;
      return NightSpec(
        id: id,
        season: 2,
        name: nightName(id),
        quota: _quotaFor(seconds, spawn, convoy: avg),
        dawnSeconds: _dawnFor(seconds),
        maxAtOnce: 4,
        spawnPeriod: spawn,
        speed: _lerp(96, 128, t),
        beamReach: _lerp(0.74, 0.64, t),
        rockTeeth: _lerp(18, 26, t).round(),
        fogBanks: t > 0.55 ? 1 : 0,
        fogRadius: 150,
        convoyChance: chance,
        convoyMax: max,
        seed: hashSeed('seed-$id'),
      );
    default:
      final spawn = _lerp(3.4, 2.85, t);
      final chance = _lerp(0.15, 0.3, t);
      return NightSpec(
        id: id,
        season: 3,
        name: nightName(id),
        quota: _quotaFor(seconds, spawn, convoy: chance * 1.5),
        dawnSeconds: _dawnFor(seconds),
        maxAtOnce: 5,
        spawnPeriod: spawn,
        speed: _lerp(114, 148, t),
        beamReach: _lerp(0.72, 0.6, t),
        rockTeeth: _lerp(22, 30, t).round(),
        fogBanks: t > 0.3 ? (t > 0.7 ? 2 : 1) : 0,
        fogRadius: 150,
        convoyChance: chance,
        convoyMax: 2,
        buoys: t < 0.5 ? _twoBuoys : _threeBuoys,
        seed: hashSeed('seed-$id'),
      );
  }
}

const _oneBuoy = [(0.5, 0.42)];
const _twoBuoys = [(0.3, 0.44), (0.72, 0.4)];
const _threeBuoys = [(0.26, 0.5), (0.5, 0.3), (0.76, 0.48)];

/// Tutorials and finales are written by hand.
NightSpec? _handWritten(int id) {
  switch (id) {
    case 1:
      return NightSpec(
        id: 1,
        season: 0,
        name: nightName(1),
        quota: 4,
        dawnSeconds: 80,
        maxAtOnce: 1,
        spawnPeriod: 4,
        speed: 58,
        beamReach: 0.95,
        rockTeeth: 10,
        randomSpawns: false,
        waves: const [
          Wave(at: 0.5, x: 0.5, aimX: 0.6),
          Wave(at: 9, x: 0.3),
          Wave(at: 18, x: 0.7),
          Wave(at: 27, x: 0.45),
          Wave(at: 38, x: 0.6),
          Wave(at: 48, x: 0.35),
        ],
        tutorial: 'Drag anywhere to sweep the beam. Hold it on a boat until its ring fills.',
        seed: 101,
      );
    case 2:
      return NightSpec(
        id: 2,
        season: 0,
        name: nightName(2),
        quota: 7,
        dawnSeconds: 60,
        maxAtOnce: 2,
        spawnPeriod: 3.4,
        speed: 64,
        beamReach: 0.9,
        rockTeeth: 11,
        waves: const [
          Wave(at: 1, x: 0.25, aimX: 0.4),
          Wave(at: 1.5, x: 0.78, aimX: 0.8, speedScale: 1.15),
        ],
        tutorial: 'Two boats at once. Light the one nearer the rocks first.',
        seed: 102,
      );
    case 10:
      return NightSpec(
        id: 10,
        season: 0,
        name: nightName(10),
        quota: 18,
        dawnSeconds: 82,
        maxAtOnce: 3,
        spawnPeriod: 2.1,
        speed: 96,
        beamReach: 0.76,
        rockTeeth: 18,
        waves: const [
          Wave(at: 2, x: 0.15),
          Wave(at: 2.5, x: 0.5, speedScale: 0.9),
          Wave(at: 3, x: 0.85),
          Wave(at: 34, x: 0.2),
          Wave(at: 34.5, x: 0.8),
          Wave(at: 66, x: 0.3),
          Wave(at: 66.5, x: 0.55),
          Wave(at: 67, x: 0.8),
        ],
        tutorial: 'The fleet comes home together tonight. Keep every lamp lit.',
        finale: true,
        seed: 110,
      );
    case 11:
      return NightSpec(
        id: 11,
        season: 1,
        name: nightName(11),
        quota: 11,
        dawnSeconds: 72,
        maxAtOnce: 2,
        spawnPeriod: 2.6,
        speed: 76,
        beamReach: 0.82,
        rockTeeth: 15,
        fogBanks: 1,
        fogRadius: 190,
        fogSpeed: 14,
        tutorial: 'Fog hides boats and halves your light. Catch them before they slip inside.',
        seed: 111,
      );
    case 12:
      return NightSpec(
        id: 12,
        season: 1,
        name: nightName(12),
        quota: 13,
        dawnSeconds: 76,
        maxAtOnce: 2,
        spawnPeriod: 2.5,
        speed: 80,
        beamReach: 0.8,
        rockTeeth: 16,
        fogBanks: 2,
        fogRadius: 150,
        fogSpeed: 18,
        tutorial: 'Two banks tonight. Watch the gaps between them.',
        seed: 112,
      );
    case 23:
      return NightSpec(
        id: 23,
        season: 1,
        name: nightName(23),
        quota: 24,
        dawnSeconds: 92,
        maxAtOnce: 3,
        spawnPeriod: 1.8,
        speed: 108,
        beamReach: 0.7,
        rockTeeth: 22,
        fogBanks: 3,
        fogRadius: 170,
        fogSpeed: 24,
        waves: const [
          Wave(at: 40, x: 0.2),
          Wave(at: 40.5, x: 0.8),
          Wave(at: 85, x: 0.35),
          Wave(at: 85.5, x: 0.65),
        ],
        tutorial: 'Every bell in the cove is ringing. Listen, and light them home.',
        finale: true,
        seed: 123,
      );
    case 24:
      return NightSpec(
        id: 24,
        season: 2,
        name: nightName(24),
        quota: 14,
        dawnSeconds: 76,
        maxAtOnce: 2,
        spawnPeriod: 2.8,
        speed: 80,
        beamReach: 0.8,
        rockTeeth: 18,
        convoyChance: 0.35,
        convoyMax: 2,
        waves: const [
          Wave(at: 1, x: 0.5, convoy: 2, aimX: 0.6),
        ],
        tutorial: 'A convoy. Light the lead boat and the line follows it home.',
        seed: 124,
      );
    case 25:
      return NightSpec(
        id: 25,
        season: 2,
        name: nightName(25),
        quota: 17,
        dawnSeconds: 80,
        maxAtOnce: 2,
        spawnPeriod: 2.7,
        speed: 82,
        beamReach: 0.78,
        rockTeeth: 19,
        convoyChance: 0.4,
        convoyMax: 2,
        tutorial: 'Lose a lead and its line scatters. Each boat then needs its own light.',
        seed: 125,
      );
    case 37:
      return NightSpec(
        id: 37,
        season: 2,
        name: nightName(37),
        quota: 36,
        dawnSeconds: 96,
        maxAtOnce: 3,
        spawnPeriod: 2.0,
        speed: 110,
        beamReach: 0.7,
        rockTeeth: 26,
        fogBanks: 1,
        convoyChance: 0.45,
        convoyMax: 3,
        waves: const [
          Wave(at: 2, x: 0.3, convoy: 3),
          Wave(at: 50, x: 0.7, convoy: 3),
          Wave(at: 100, x: 0.45, convoy: 3),
        ],
        tutorial: 'The herring fleet is running for home. Bring the whole line in.',
        finale: true,
        seed: 137,
      );
    case 38:
      return NightSpec(
        id: 38,
        season: 3,
        name: nightName(38),
        quota: 18,
        dawnSeconds: 80,
        maxAtOnce: 2,
        spawnPeriod: 2.4,
        speed: 84,
        beamReach: 0.78,
        rockTeeth: 20,
        buoys: _oneBuoy,
        tutorial: 'Sweep over the dark bell buoy to kindle it. Its halo charts boats on its own.',
        seed: 138,
      );
    case 39:
      return NightSpec(
        id: 39,
        season: 3,
        name: nightName(39),
        quota: 20,
        dawnSeconds: 86,
        maxAtOnce: 3,
        spawnPeriod: 2.3,
        speed: 86,
        beamReach: 0.76,
        rockTeeth: 21,
        buoys: _twoBuoys,
        tutorial: 'A halo burns out after a while. Kindle it again when boats come near.',
        seed: 139,
      );
    case 40:
      return NightSpec(
        id: 40,
        season: 3,
        name: nightName(40),
        quota: 22,
        dawnSeconds: 90,
        maxAtOnce: 3,
        spawnPeriod: 2.3,
        speed: 88,
        beamReach: 0.76,
        rockTeeth: 22,
        buoys: _twoBuoys,
        convoyChance: 0.2,
        convoyMax: 2,
        tutorial: 'Halos chart convoy leads too. Let the buoys work while you aim elsewhere.',
        seed: 140,
      );
    case 52:
      return NightSpec(
        id: 52,
        season: 3,
        name: nightName(52),
        quota: 42,
        dawnSeconds: 106,
        maxAtOnce: 4,
        spawnPeriod: 1.7,
        speed: 116,
        beamReach: 0.66,
        rockTeeth: 30,
        fogBanks: 2,
        convoyChance: 0.3,
        convoyMax: 3,
        buoys: _threeBuoys,
        waves: const [
          Wave(at: 60, x: 0.2, convoy: 2),
          Wave(at: 60.5, x: 0.8, convoy: 2),
          Wave(at: 120, x: 0.5, convoy: 3),
        ],
        tutorial: 'The longest night of the year. Every light you have, all at once.',
        finale: true,
        seed: 152,
      );
  }
  return null;
}
