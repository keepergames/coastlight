import 'night_spec.dart';
import 'rng.dart';
import 'seasons.dart';

/// A day key like `2026-11-12` in local time.
String dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Today's Daily Tide. The same date gives the same night on every device.
/// [furthestSeason] is the highest season the player has reached (0..3), so a
/// new player never meets a mechanic they have not been taught.
NightSpec dailySpec(DateTime date, {required int furthestSeason}) {
  final key = dayKey(date);
  final rng = Rng(hashSeed('daily-$key'));
  final top = seasons[furthestSeason.clamp(0, 3)];
  // Pick an ordinary (generated) night from the unlocked range.
  final pool = <int>[
    for (var id = 3; id <= top.last; id++)
      if (!_special.contains(id)) id,
  ];
  final base = nightSpec(pool[rng.nextInt(pool.length)]);
  return base.copyWith(
    id: 0,
    name: 'Daily Tide',
    seed: hashSeed('daily-seed-$key'),
  );
}

const _special = {10, 11, 12, 23, 24, 25, 37, 38, 39, 40, 52};

/// The Longest Night: no dawn, the sea keeps getting busier.
const NightSpec endlessSpec = NightSpec(
  id: 0,
  season: 0,
  name: 'The Longest Night',
  quota: 1 << 30,
  dawnSeconds: double.infinity,
  maxAtOnce: 2,
  spawnPeriod: 2.8,
  speed: 60,
  beamReach: 0.98,
  rockTeeth: 20,
  seed: 4242,
);
