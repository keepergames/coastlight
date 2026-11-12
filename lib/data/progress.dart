import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../engine/modes.dart';
import '../engine/night_spec.dart';
import '../engine/seasons.dart';
import '../engine/sim.dart';
import 'catalog.dart';

enum PlayMode { story, daily, endless }

/// What happened in one finished night, as the screens report it.
class RunSummary {
  const RunSummary({
    required this.mode,
    required this.spec,
    required this.outcome,
    required this.embers,
    required this.souls,
    required this.bestStreak,
    required this.seconds,
    this.convoysHome = 0,
    this.chartedInFog = 0,
    this.buoysKindled = 0,
    this.day,
  });

  factory RunSummary.fromSim(PlayMode mode, CoveSim sim, {String? day}) => RunSummary(
        mode: mode,
        spec: sim.spec,
        outcome: sim.outcome ?? NightOutcome.dark,
        embers: sim.embers,
        souls: sim.souls,
        bestStreak: sim.bestStreak,
        seconds: sim.t,
        convoysHome: sim.convoysHome,
        chartedInFog: sim.chartedInFog,
        buoysKindled: sim.buoysKindled,
        day: day,
      );

  final PlayMode mode;
  final NightSpec spec;
  final NightOutcome outcome;
  final int embers;
  final int souls;
  final int bestStreak;
  final double seconds;
  final int convoysHome;
  final int chartedInFog;
  final int buoysKindled;

  /// Day key for a Daily Tide.
  final String? day;

  bool get kept => outcome == NightOutcome.kept;
  int get lanterns => kept ? embers : 0;
}

/// What the result screen shows: what changed because of this night.
class Reward {
  Reward({
    required this.oil,
    required this.lanterns,
    required this.previousLanterns,
    required this.firstKeep,
    required this.newAchievements,
    this.newSeason,
    this.newBest = false,
  });

  final int oil;
  final int lanterns;
  final int previousLanterns;
  final bool firstKeep;
  final List<Achievement> newAchievements;

  /// Set when this night opened a new season.
  final Season? newSeason;

  /// The Longest Night: a new best count.
  final bool newBest;
}

class Achievement {
  const Achievement(this.id, this.name, this.line, this.test);
  final String id;
  final String name;
  final String line;
  final bool Function(Progress p, RunSummary? run) test;
}

bool _seasonKept(Progress p, int s) => seasons[s].nightIds.every(p.isKept);
bool _seasonBright(Progress p, int s) => seasons[s].nightIds.every((id) => p.lanternsFor(id) == 3);

final List<Achievement> achievements = [
  Achievement('first_soul', 'First Soul', 'Bring a boat home.', (p, r) => p.soulsHome >= 1),
  Achievement('first_night', 'The Watch Begins', 'Keep your first night.', (p, r) => p.nightsKept >= 1),
  Achievement('still_water', 'Still Water', 'Keep every night of Still Water.', (p, r) => _seasonKept(p, 0)),
  Achievement('fog_season', 'Through the Fog', 'Keep every night of Fog Season.', (p, r) => _seasonKept(p, 1)),
  Achievement('squall_coast', 'Squall Coast', 'Keep every night of Squall Coast.', (p, r) => _seasonKept(p, 2)),
  Achievement('long_winter', 'Keeper of the Year', 'Keep every night of The Long Winter.', (p, r) => _seasonKept(p, 3)),
  Achievement('bright_still', 'Every Lamp Lit', 'Earn all three lanterns on every night of Still Water.', (p, r) => _seasonBright(p, 0)),
  Achievement('bright_year', 'A Year Without Dark', 'Earn all three lanterns on all 52 nights.', (p, r) => p.totalLanterns == nightCount * 3),
  Achievement('flawless_finale', 'Not One Ember', 'Keep a season finale without losing an ember.', (p, r) => r != null && r.kept && r.spec.finale && r.embers == 3),
  Achievement('convoy', 'The Whole Line', 'Bring a whole convoy home.', (p, r) => p.convoysHome >= 1),
  Achievement('convoy_25', 'Pilot of Fleets', 'Bring 25 whole convoys home.', (p, r) => p.convoysHome >= 25),
  Achievement('fog_50', 'Seeing in Fog', 'Chart 50 boats inside fog banks.', (p, r) => p.chartedInFog >= 50),
  Achievement('buoys_25', 'Bell Ringer', 'Kindle 25 bell buoys.', (p, r) => p.buoysKindled >= 25),
  Achievement('streak_20', 'Steady Hand', 'Bring 20 boats home in a row in one night.', (p, r) => p.bestStreak >= 20),
  Achievement('souls_100', 'A Hundred Souls', 'Bring 100 boats home.', (p, r) => p.soulsHome >= 100),
  Achievement('souls_1000', 'A Thousand Souls', 'Bring 1,000 boats home.', (p, r) => p.soulsHome >= 1000),
  Achievement('daily_1', 'The Tide Bell', 'Keep a Daily Tide.', (p, r) => p.dailyKept.isNotEmpty),
  Achievement('daily_7', 'A Week of Tides', 'Keep the Daily Tide seven days in a row.', (p, r) => p.bestDailyStreak >= 7),
  Achievement('longest_60', 'Through the Small Hours', 'Bring 60 boats home in one Longest Night.', (p, r) => p.longestBest >= 60),
  Achievement('chandler', 'Dressing the Tower', 'Buy something at the Chandlery.', (p, r) => p.owned.any((id) => !goodById(id).isDefault)),
];

Achievement achievementById(String id) => achievements.firstWhere((a) => a.id == id);

/// Everything the game remembers, stored on the device as one JSON record.
class Progress extends ChangeNotifier {
  Progress._(this._prefs);

  static const storageKey = 'cove_save_v1';

  final SharedPreferences? _prefs;

  // Story.
  Map<int, int> lanterns = {};

  // Currency and Chandlery.
  int oil = 0;
  Set<String> owned = _defaultOwned();

  static Set<String> _defaultOwned() =>
      {for (final s in Shelf.values) if (defaultFor(s).isNotEmpty) defaultFor(s)};
  Map<Shelf, String> equipped = {for (final s in Shelf.values) if (isExclusive(s)) s: defaultFor(s)};
  Set<String> shownKeepsakes = {};

  // Stats.
  int soulsHome = 0;
  int nightsKept = 0;
  int nightsPlayed = 0;
  int embersLost = 0;
  int convoysHome = 0;
  int chartedInFog = 0;
  int buoysKindled = 0;
  int bestStreak = 0;
  double secondsAtLamp = 0;
  int longestBest = 0;
  int longestPlays = 0;

  // Daily Tide.
  Set<String> dailyKept = {};
  int bestDailyStreak = 0;

  // Achievements.
  Set<String> unlocked = {};

  // Settings.
  bool sound = true;
  bool music = true;
  bool vibration = true;
  bool reduceMotion = false;

  // First-run.
  bool seenDuty = false;

  /// Loads saved progress (or a fresh save when there is none).
  static Future<Progress> load() async {
    final prefs = await SharedPreferences.getInstance();
    final p = Progress._(prefs);
    final raw = prefs.getString(storageKey);
    if (raw != null) {
      try {
        p._fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {
        // A damaged save starts fresh rather than crashing the lighthouse.
      }
    }
    return p;
  }

  /// An in-memory save for tests and previews.
  @visibleForTesting
  factory Progress.memory() => Progress._(null);

  // ------------------------------------------------------------- queries ---

  bool isKept(int id) => lanterns.containsKey(id);
  int lanternsFor(int id) => lanterns[id] ?? 0;
  bool isUnlocked(int id) => id == 1 || isKept(id - 1) || isKept(id);
  int get totalLanterns => lanterns.values.fold(0, (a, b) => a + b);
  int seasonLanterns(int s) => seasons[s].nightIds.fold(0, (a, id) => a + lanternsFor(id));
  int seasonKept(int s) => seasons[s].nightIds.where(isKept).length;
  bool seasonOpen(int s) => isUnlocked(seasons[s].first);

  /// The night "Tend the Light" plays: the first unkept open night.
  int get nextNight {
    for (var id = 1; id <= nightCount; id++) {
      if (!isKept(id)) return id;
    }
    return nightCount;
  }

  bool get yearComplete => lanterns.length == nightCount;

  /// Highest season the keeper has reached (0..3).
  int get furthestSeason {
    var s = 0;
    for (final season in seasons) {
      if (seasonOpen(season.index)) s = season.index;
    }
    return s;
  }

  /// Seasons whose every night is kept: the village lights grow with these.
  int get seasonsKept => seasons.where((s) => s.nightIds.every(isKept)).length;

  bool dailyDone(DateTime today) => dailyKept.contains(dayKey(today));

  /// Consecutive kept days ending today (or yesterday, if today is not yet kept).
  int dailyStreak(DateTime today) {
    var day = DateTime(today.year, today.month, today.day);
    if (!dailyKept.contains(dayKey(day))) day = day.subtract(const Duration(days: 1));
    var n = 0;
    while (dailyKept.contains(dayKey(day))) {
      n++;
      day = day.subtract(const Duration(days: 1));
    }
    return n;
  }

  Good equippedGood(Shelf s) => goodById(equipped[s] ?? defaultFor(s));

  // ------------------------------------------------------------- actions ---

  /// Records a finished night and returns what it earned.
  Reward record(RunSummary run) {
    final before = Set<String>.of(unlocked);
    final seasonsBefore = {for (final s in seasons) s.index: seasonOpen(s.index)};
    var prevLanterns = 0;
    var firstKeep = false;
    var newBest = false;

    nightsPlayed++;
    soulsHome += run.souls;
    embersLost += 3 - run.embers;
    convoysHome += run.convoysHome;
    chartedInFog += run.chartedInFog;
    buoysKindled += run.buoysKindled;
    bestStreak = math.max(bestStreak, run.bestStreak);
    secondsAtLamp += run.seconds;
    if (run.kept) nightsKept++;

    var earned = run.souls;
    switch (run.mode) {
      case PlayMode.story:
        if (run.kept) {
          final id = run.spec.id;
          prevLanterns = lanternsFor(id);
          firstKeep = !isKept(id);
          lanterns[id] = math.max(prevLanterns, run.lanterns);
          earned += 4 * math.max(0, run.lanterns - prevLanterns);
          if (firstKeep) earned += 10;
        }
      case PlayMode.daily:
        if (run.kept && run.day != null && !dailyKept.contains(run.day)) {
          dailyKept.add(run.day!);
          earned += 20;
          final d = DateTime.parse(run.day!);
          bestDailyStreak = math.max(bestDailyStreak, dailyStreak(d));
        }
      case PlayMode.endless:
        longestPlays++;
        if (run.souls > longestBest) {
          newBest = longestBest > 0;
          longestBest = run.souls;
        }
        earned = (run.souls * 0.6).round();
    }
    oil += earned;

    final fresh = _checkAchievements(run).where((a) => !before.contains(a.id)).toList();
    Season? opened;
    for (final s in seasons) {
      if (!seasonsBefore[s.index]! && seasonOpen(s.index)) opened = s;
    }
    _save();
    return Reward(
      oil: earned,
      lanterns: run.lanterns,
      previousLanterns: prevLanterns,
      firstKeep: firstKeep,
      newAchievements: fresh,
      newSeason: opened,
      newBest: newBest,
    );
  }

  List<Achievement> _checkAchievements(RunSummary? run) {
    final out = <Achievement>[];
    for (final a in achievements) {
      if (!unlocked.contains(a.id) && a.test(this, run)) {
        unlocked.add(a.id);
        out.add(a);
      }
    }
    return out;
  }

  bool canAfford(Good g) => oil >= g.price;

  /// Buys [g] with lamp oil. Returns newly earned achievements, or null when
  /// it could not be bought.
  List<Achievement>? buy(Good g) {
    if (owned.contains(g.id) || !canAfford(g)) return null;
    oil -= g.price;
    owned.add(g.id);
    if (isExclusive(g.shelf)) {
      equipped[g.shelf] = g.id;
    } else {
      shownKeepsakes.add(g.id);
    }
    final fresh = _checkAchievements(null);
    _save();
    return fresh;
  }

  /// Puts an owned good in use (or toggles a keepsake on the hub).
  void use(Good g) {
    if (!owned.contains(g.id)) return;
    if (isExclusive(g.shelf)) {
      equipped[g.shelf] = g.id;
    } else if (!shownKeepsakes.remove(g.id)) {
      shownKeepsakes.add(g.id);
    }
    _save();
  }

  void setSettings({bool? sound, bool? music, bool? vibration, bool? reduceMotion}) {
    this.sound = sound ?? this.sound;
    this.music = music ?? this.music;
    this.vibration = vibration ?? this.vibration;
    this.reduceMotion = reduceMotion ?? this.reduceMotion;
    _save();
  }

  void markDutySeen() {
    if (seenDuty) return;
    seenDuty = true;
    _save();
  }

  /// Clears all progress. Settings are kept.
  Future<void> reset() async {
    final keepSound = sound, keepMusic = music, keepVibration = vibration, keepReduce = reduceMotion;
    _fromJson(Progress._(null)._toJson());
    sound = keepSound;
    music = keepMusic;
    vibration = keepVibration;
    reduceMotion = keepReduce;
    _save();
  }

  // --------------------------------------------------------- persistence ---

  void _save() {
    notifyListeners();
    _prefs?.setString(storageKey, jsonEncode(_toJson()));
  }

  Map<String, dynamic> _toJson() => {
        'v': 1,
        'lanterns': {for (final e in lanterns.entries) '${e.key}': e.value},
        'oil': oil,
        'owned': owned.toList(),
        'equipped': {for (final e in equipped.entries) e.key.name: e.value},
        'keepsakes': shownKeepsakes.toList(),
        'souls': soulsHome,
        'kept': nightsKept,
        'played': nightsPlayed,
        'embersLost': embersLost,
        'convoys': convoysHome,
        'fog': chartedInFog,
        'buoys': buoysKindled,
        'streak': bestStreak,
        'seconds': secondsAtLamp,
        'longestBest': longestBest,
        'longestPlays': longestPlays,
        'daily': dailyKept.toList(),
        'dailyBest': bestDailyStreak,
        'unlocked': unlocked.toList(),
        'sound': sound,
        'music': music,
        'vibration': vibration,
        'reduceMotion': reduceMotion,
        'seenDuty': seenDuty,
      };

  void _fromJson(Map<String, dynamic> j) {
    int i(String k) => (j[k] as num?)?.toInt() ?? 0;
    Set<String> set(String k) => {...((j[k] as List?) ?? const []).cast<String>()};
    lanterns = {
      for (final e in ((j['lanterns'] as Map?) ?? const {}).entries)
        int.parse(e.key as String): (e.value as num).toInt().clamp(1, 3),
    };
    oil = i('oil');
    owned = {..._defaultOwned(), ...set('owned')}..removeWhere((id) => !catalog.any((g) => g.id == id));
    final eq = (j['equipped'] as Map?) ?? const {};
    for (final s in Shelf.values.where(isExclusive)) {
      final id = eq[s.name] as String?;
      equipped[s] = id != null && owned.contains(id) ? id : defaultFor(s);
    }
    shownKeepsakes = set('keepsakes').intersection(owned);
    soulsHome = i('souls');
    nightsKept = i('kept');
    nightsPlayed = i('played');
    embersLost = i('embersLost');
    convoysHome = i('convoys');
    chartedInFog = i('fog');
    buoysKindled = i('buoys');
    bestStreak = i('streak');
    secondsAtLamp = (j['seconds'] as num?)?.toDouble() ?? 0;
    longestBest = i('longestBest');
    longestPlays = i('longestPlays');
    dailyKept = set('daily');
    bestDailyStreak = i('dailyBest');
    unlocked = set('unlocked');
    sound = j['sound'] as bool? ?? true;
    music = j['music'] as bool? ?? true;
    vibration = j['vibration'] as bool? ?? true;
    reduceMotion = j['reduceMotion'] as bool? ?? false;
    seenDuty = j['seenDuty'] as bool? ?? false;
  }
}
