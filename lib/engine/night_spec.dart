/// The fixed logical field every night is played on. The renderer scales it to
/// the screen; the engine never sees pixels, so results are the same on every
/// phone and in tests.
class World {
  World._();

  static const double width = 1000;
  static const double height = 1600;

  /// The lamp room, where the beam starts.
  static const double lampX = 500;
  static const double lampY = 1480;

  /// The rock line. An uncharted vessel that reaches it is lost.
  static const double hazardY = 1230;

  /// Where charted vessels sail to (the harbor mouth, bottom-left).
  static const double harborX = 150;
  static const double harborY = 1330;

  /// Vessels appear just above the top edge.
  static const double spawnY = -40;
}

/// What a night introduces. Used for tutorial copy and season rules.
enum Mechanic { beam, fog, convoy, buoy }

/// One scripted arrival (used by tutorials and finales).
class Wave {
  const Wave({
    required this.at,
    required this.x,
    this.convoy = 0,
    this.speedScale = 1,
    this.aimX,
  });

  /// Seconds after the night starts.
  final double at;

  /// Spawn x as a fraction of the world width (0..1).
  final double x;

  /// Number of followers behind the lead (0 = a lone vessel).
  final int convoy;

  /// Multiplier on the night's drift speed.
  final double speedScale;

  /// Where on the rock line it heads, as a fraction of width. Null = random.
  final double? aimX;
}

/// Everything that defines a night. Pure data: the simulation reads it.
class NightSpec {
  const NightSpec({
    required this.id,
    required this.season,
    required this.name,
    required this.quota,
    required this.dawnSeconds,
    required this.maxAtOnce,
    required this.spawnPeriod,
    required this.speed,
    required this.beamReach,
    this.rockTeeth = 14,
    this.fogBanks = 0,
    this.fogRadius = 150,
    this.fogSpeed = 22,
    this.convoyChance = 0,
    this.convoyMax = 0,
    this.buoys = const [],
    this.waves = const [],
    this.randomSpawns = true,
    this.tutorial,
    this.finale = false,
    this.seed = 1,
  });

  /// 1-based night number for story nights; 0 for daily/endless.
  final int id;

  /// 0..3 season index.
  final int season;

  final String name;

  /// Souls to bring home before dawn.
  final int quota;

  /// Length of the night. [double.infinity] for The Longest Night.
  final double dawnSeconds;

  /// Most vessels on the water at once from random spawns.
  final int maxAtOnce;

  /// Seconds between random spawn attempts.
  final double spawnPeriod;

  /// Drift speed in world units per second.
  final double speed;

  /// Beam reach as a fraction of [World.height].
  final double beamReach;

  /// Visual density of the rock line.
  final int rockTeeth;

  final int fogBanks;
  final double fogRadius;
  final double fogSpeed;

  /// Chance that a random spawn is a convoy, and its largest follower count.
  final double convoyChance;
  final int convoyMax;

  /// Bell buoy positions as fractions of the world (x, y).
  final List<(double, double)> buoys;

  /// Scripted arrivals, on top of random spawns when [randomSpawns] is true.
  final List<Wave> waves;
  final bool randomSpawns;

  /// One line shown at the start of a tutorial night.
  final String? tutorial;

  final bool finale;
  final int seed;

  bool get endless => dawnSeconds == double.infinity;

  Set<Mechanic> get mechanics => {
        Mechanic.beam,
        if (fogBanks > 0) Mechanic.fog,
        if (convoyChance > 0 || waves.any((w) => w.convoy > 0)) Mechanic.convoy,
        if (buoys.isNotEmpty) Mechanic.buoy,
      };

  NightSpec copyWith({
    int? id,
    String? name,
    int? quota,
    double? dawnSeconds,
    int? maxAtOnce,
    double? spawnPeriod,
    double? speed,
    double? beamReach,
    int? fogBanks,
    double? convoyChance,
    int? convoyMax,
    List<(double, double)>? buoys,
    int? seed,
  }) =>
      NightSpec(
        id: id ?? this.id,
        season: season,
        name: name ?? this.name,
        quota: quota ?? this.quota,
        dawnSeconds: dawnSeconds ?? this.dawnSeconds,
        maxAtOnce: maxAtOnce ?? this.maxAtOnce,
        spawnPeriod: spawnPeriod ?? this.spawnPeriod,
        speed: speed ?? this.speed,
        beamReach: beamReach ?? this.beamReach,
        rockTeeth: rockTeeth,
        fogBanks: fogBanks ?? this.fogBanks,
        fogRadius: fogRadius,
        fogSpeed: fogSpeed,
        convoyChance: convoyChance ?? this.convoyChance,
        convoyMax: convoyMax ?? this.convoyMax,
        buoys: buoys ?? this.buoys,
        waves: waves,
        randomSpawns: randomSpawns,
        tutorial: tutorial,
        finale: finale,
        seed: seed ?? this.seed,
      );
}
