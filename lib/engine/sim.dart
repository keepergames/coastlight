import 'dart:math' as math;

import 'night_spec.dart';
import 'rng.dart';
import 'vec.dart';

enum VesselState { drifting, homeward, home, lost }

/// A lost soul on the water. A convoy is a lead vessel plus followers that
/// trail it; only the lead can be charted, and the line follows it home.
class Vessel {
  Vessel({
    required this.id,
    required this.pos,
    required this.vel,
    this.leaderId,
    this.followIndex = 0,
    this.followers = 0,
    required this.style,
    required this.phase,
  });

  final int id;
  Vec pos;
  Vec vel;

  /// 0..1 charting ring. Full = the vessel turns for the harbor.
  double chart = 0;
  VesselState state = VesselState.drifting;

  /// Set when this vessel trails a convoy lead.
  int? leaderId;
  int followIndex;

  /// For a lead: how many followers it had when it set out.
  int followers;

  bool lit = false;
  bool inFog = false;

  /// Cosmetic variety for the renderer (hull shape) and its sway offset.
  final int style;
  final double phase;

  /// Seconds since this vessel resolved (home/lost), for fade-outs.
  double resolvedFor = 0;

  /// Seconds left turning back out to sea (followers of a lost lead).
  double turnBack = 0;

  /// Drift speed to resume after turning back.
  double cruise = 0;

  bool get isFollower => leaderId != null;
  bool get isLead => followers > 0 && leaderId == null;
  bool get active =>
      state == VesselState.drifting || state == VesselState.homeward;

  /// Homeward vessels pass this point (clear of the rocks) before the harbor.
  bool _passedWaypoint = false;
}

class FogBank {
  FogBank({required this.pos, required this.radius, required this.vx});
  Vec pos;
  final double radius;
  final double vx;
}

class Buoy {
  Buoy(this.pos);
  final Vec pos;

  /// 0..1 while the beam is kindling it.
  double kindle = 0;

  /// Seconds of halo left once kindled.
  double active = 0;

  bool get lit => active > 0;
}

enum SimEventType {
  spawn,
  charted,
  home,
  lost,
  emberOut,
  kindled,
  buoyOut,
  kept,
  dark,
  dawnShort,
}

class SimEvent {
  const SimEvent(this.type, [this.pos = Vec.zero, this.count = 1]);
  final SimEventType type;
  final Vec pos;

  /// For [SimEventType.home]: souls brought home at once (convoys).
  final int count;
}

enum NightOutcome {
  /// Quota reached before dawn.
  kept,

  /// All embers out.
  dark,

  /// Dawn arrived with the quota unmet.
  dawnShort,
}

/// The whole game rules for one night. Deterministic for a given spec + seed.
class CoveSim {
  CoveSim(this.spec, {int? seed})
      : _rng = Rng(seed ?? spec.seed),
        reach = spec.beamReach * World.height {
    _setupFog();
    for (final (bx, by) in spec.buoys) {
      buoys.add(Buoy(Vec(bx * World.width, by * World.height)));
    }
    _waves = [...spec.waves]..sort((a, b) => a.at.compareTo(b.at));
    // First random arrival comes quickly so the sea is never empty for long.
    _spawnClock = spec.waves.isEmpty ? spec.spawnPeriod - 0.6 : 0;
  }

  static const double halfAngle = 0.15;
  static const double chartRate = 0.42;
  static const double leadChartRate = 0.29;
  static const double fogChartScale = 0.6;
  static const double decayRate = 0.12;
  static const double homeSpeed = 240;
  static const double kindleTime = 0.9;
  static const double buoyDuration = 12;
  static const double buoyRadius = 175;
  static const double buoyChartRate = 0.3;
  static const double followSpacing = 78;
  static const int maxEmbers = 3;

  /// Left end of the rock line; the harbor channel lies to its left.
  static const double rocksStartX = 270;

  final NightSpec spec;
  final Rng _rng;

  /// Beam reach in world units (fixed for story nights).
  double reach;

  double t = 0;
  double beamAngle = -math.pi / 2;
  int embers = maxEmbers;
  int souls = 0;
  int score = 0;
  int streak = 0;
  int bestStreak = 0;
  int lost = 0;
  NightOutcome? outcome;

  /// Counters for achievements and the Keeper's Log.
  int convoysHome = 0;
  int chartedInFog = 0;
  int buoysKindled = 0;

  final List<Vessel> vessels = [];
  final List<FogBank> fog = [];
  final List<Buoy> buoys = [];
  final List<SimEvent> _events = [];

  late List<Wave> _waves;
  int _waveIndex = 0;
  double _spawnClock = 0;
  double _gap = 1;
  int _nextId = 1;

  bool get over => outcome != null;

  /// 0..1 progress toward dawn (0 for endless).
  double get dawnProgress =>
      spec.endless ? 0 : (t / spec.dawnSeconds).clamp(0.0, 1.0);

  double get secondsLeft => spec.endless ? double.infinity : spec.dawnSeconds - t;

  /// Lanterns earned if the night ended now: one per ember still burning.
  int get lanterns => outcome == NightOutcome.kept ? embers : 0;

  Vec get lamp => const Vec(World.lampX, World.lampY);

  /// Endless difficulty stage (0 at start, +1 every 22 s).
  int get stage => spec.endless ? (t / 22).floor() : 0;

  /// Takes the events produced since the last call.
  List<SimEvent> drainEvents() {
    final out = List<SimEvent>.of(_events);
    _events.clear();
    return out;
  }

  // ---------------------------------------------------------------- input ---

  /// Sets the beam angle. The beam only sweeps the upper half (over the sea).
  void aim(double angle) {
    beamAngle = angle.clamp(-math.pi + 0.12, -0.12);
  }

  void aimAt(Vec worldPoint) {
    final d = worldPoint - lamp;
    if (d.length2 < 1) return;
    aim(d.angle);
  }

  bool illuminates(Vec p) {
    final d = p - lamp;
    final dist = d.length;
    if (dist == 0 || dist > reach) return false;
    return wrapAngle(d.angle - beamAngle).abs() <= halfAngle;
  }

  // ---------------------------------------------------------------- step ----

  /// Advances the night. Large [dt] is split so results do not depend on
  /// frame rate.
  void step(double dt) {
    var left = dt;
    while (left > 1e-9) {
      final h = math.min(left, 1 / 60);
      _tick(h);
      left -= h;
    }
  }

  void _tick(double dt) {
    // Resolved vessels keep fading for the renderer even after the night ends.
    for (final v in vessels) {
      if (!v.active) v.resolvedFor += dt;
    }
    vessels.removeWhere((v) => !v.active && v.resolvedFor > 1.6);
    if (over) return;

    t += dt;
    _applyEndlessRamp();
    _moveFog(dt);
    _spawn(dt);
    _updateBuoys(dt);
    _updateVessels(dt);

    if (embers <= 0) {
      _finish(NightOutcome.dark);
    } else if (!spec.endless && souls >= spec.quota) {
      _finish(NightOutcome.kept);
    } else if (!spec.endless && t >= spec.dawnSeconds) {
      _finish(NightOutcome.dawnShort);
    }
  }

  void _finish(NightOutcome o) {
    outcome = o;
    _events.add(SimEvent(switch (o) {
      NightOutcome.kept => SimEventType.kept,
      NightOutcome.dark => SimEventType.dark,
      NightOutcome.dawnShort => SimEventType.dawnShort,
    }));
  }

  // ------------------------------------------------------------- endless ----

  int get _maxAtOnce =>
      spec.endless ? math.min(spec.maxAtOnce + stage ~/ 2, 5) : spec.maxAtOnce;

  double get _spawnPeriod => spec.endless
      ? math.max(spec.spawnPeriod - stage * 0.18, 1.4)
      : spec.spawnPeriod;

  double get _speed =>
      spec.endless ? spec.speed * math.min(1 + stage * 0.05, 1.6) : spec.speed;

  double get _convoyChance => spec.endless
      ? (stage >= 3 ? math.min(0.12 + stage * 0.02, 0.3) : 0)
      : spec.convoyChance;

  int get _convoyMax => spec.endless ? (stage >= 3 ? 2 : 0) : spec.convoyMax;

  void _applyEndlessRamp() {
    if (!spec.endless) return;
    // Fog rolls in from stage 2; the beam shortens gently with each stage.
    final wantFog = stage >= 2 ? math.min(1 + (stage - 2) ~/ 3, 3) : 0;
    while (fog.length < wantFog) {
      fog.add(_newFog(_rng.range(-0.1, 1.1) * World.width));
    }
    reach = (spec.beamReach - stage * 0.012).clamp(0.62, 2.0) * World.height;
  }

  // ----------------------------------------------------------------- fog ----

  void _setupFog() {
    for (var i = 0; i < spec.fogBanks; i++) {
      final x = (i + 0.5) / spec.fogBanks * World.width +
          _rng.range(-80, 80);
      fog.add(_newFog(x));
    }
  }

  FogBank _newFog(double x) {
    final y = _rng.range(0.2, 0.62) * World.height;
    final dir = _rng.chance(0.5) ? 1.0 : -1.0;
    return FogBank(
      pos: Vec(x, y),
      radius: spec.fogRadius * _rng.range(0.85, 1.15),
      vx: dir * spec.fogSpeed * _rng.range(0.7, 1.3),
    );
  }

  void _moveFog(double dt) {
    for (final f in fog) {
      var x = f.pos.x + f.vx * dt;
      if (x > World.width + f.radius) x = -f.radius;
      if (x < -f.radius) x = World.width + f.radius;
      f.pos = Vec(x, f.pos.y);
    }
  }

  bool _inFog(Vec p) => fog.any((f) => f.pos.distanceTo(p) < f.radius);

  // --------------------------------------------------------------- spawn ----

  int get _activeGroups =>
      vessels.where((v) => v.state == VesselState.drifting && !v.isFollower).length;

  void _spawn(double dt) {
    while (_waveIndex < _waves.length && _waves[_waveIndex].at <= t) {
      final w = _waves[_waveIndex++];
      _launch(w.x, w.convoy, w.speedScale, w.aimX);
    }
    if (!spec.randomSpawns) return;
    _spawnClock += dt;
    if (_spawnClock < _spawnPeriod * _gap) return;
    if (_activeGroups >= _maxAtOnce) return;
    _spawnClock = 0;
    // Uneven spacing: sometimes two arrive close together and the keeper must
    // choose. The average still matches the spawn period.
    _gap = _rng.range(0.3, 1.7);
    final convoy = _convoyMax > 0 && _rng.chance(_convoyChance)
        ? 1 + _rng.nextInt(_convoyMax)
        : 0;
    _launch(_rng.range(0.14, 0.86), convoy, 1, null);
  }

  void _launch(double fx, int convoy, double speedScale, double? aimFx) {
    final start = Vec(fx * World.width, World.spawnY);
    final aimX = (aimFx ?? _rng.range(0.32, 0.92)) * World.width;
    final dir = (Vec(aimX, World.hazardY) - start).normalized();
    final speed = _speed * speedScale * (convoy > 0 ? 0.8 : 1.0);
    final lead = Vessel(
      id: _nextId++,
      pos: start,
      vel: dir * speed,
      followers: convoy,
      style: convoy > 0 ? 3 : _rng.nextInt(3),
      phase: _rng.range(0, 2 * math.pi),
    );
    vessels.add(lead);
    for (var i = 1; i <= convoy; i++) {
      vessels.add(Vessel(
        id: _nextId++,
        pos: start - dir * (followSpacing * i),
        vel: lead.vel,
        leaderId: lead.id,
        followIndex: i,
        style: _rng.nextInt(3),
        phase: _rng.range(0, 2 * math.pi),
      ));
    }
    _events.add(SimEvent(SimEventType.spawn, start, 1 + convoy));
  }

  // --------------------------------------------------------------- buoys ----

  void _updateBuoys(double dt) {
    for (final b in buoys) {
      if (b.lit) {
        b.active -= dt;
        if (b.active <= 0) {
          b.active = 0;
          b.kindle = 0;
          _events.add(SimEvent(SimEventType.buoyOut, b.pos));
        }
        continue;
      }
      if (illuminates(b.pos)) {
        b.kindle += dt / kindleTime;
        if (b.kindle >= 1) {
          b.kindle = 1;
          b.active = buoyDuration;
          buoysKindled++;
          _events.add(SimEvent(SimEventType.kindled, b.pos));
        }
      } else {
        b.kindle = math.max(0, b.kindle - dt * 0.8);
      }
    }
  }

  bool _inBuoyHalo(Vec p) =>
      buoys.any((b) => b.lit && b.pos.distanceTo(p) < buoyRadius);

  // ------------------------------------------------------------- vessels ----

  Vessel? _byId(int id) {
    for (final v in vessels) {
      if (v.id == id) return v;
    }
    return null;
  }

  void _updateVessels(double dt) {
    for (final v in List<Vessel>.of(vessels)) {
      if (!v.active) continue;
      v.inFog = _inFog(v.pos);
      if (v.isFollower) {
        _updateFollower(v, dt);
        continue;
      }
      if (v.state == VesselState.drifting) {
        _updateDrifting(v, dt);
      } else {
        _sailHome(v, dt);
      }
    }
  }

  void _updateDrifting(Vessel v, double dt) {
    v.lit = illuminates(v.pos);
    var rate = 0.0;
    if (v.lit) rate += v.isLead ? leadChartRate : chartRate;
    if (_inBuoyHalo(v.pos)) rate += buoyChartRate;
    if (v.inFog) rate *= fogChartScale;
    v.chart = (v.chart + (rate > 0 ? rate : -decayRate) * dt).clamp(0.0, 1.0);

    if (v.chart >= 1) {
      v.state = VesselState.homeward;
      v.lit = false;
      if (v.inFog) chartedInFog++;
      if (v.isLead) {
        final line = vessels.where((f) => f.leaderId == v.id && f.active).length;
        if (line == v.followers) convoysHome++;
      }
      _events.add(SimEvent(SimEventType.charted, v.pos, 1 + v.followers));
      for (final f in vessels.where((f) => f.leaderId == v.id && f.active)) {
        f.state = VesselState.homeward;
      }
      return;
    }

    // A slow wander so drift lines are not ruler-straight.
    final wander = math.sin(t * 0.7 + v.phase) * 10;
    v.pos = v.pos + v.vel * dt + Vec(wander * dt, 0);

    if (v.turnBack > 0) {
      v.turnBack -= dt;
      if (v.turnBack <= 0) {
        final aim = Vec(_rng.range(0.32, 0.9) * World.width, World.hazardY);
        v.vel = (aim - v.pos).normalized() * (v.cruise * 0.85);
      }
    }

    final off = v.pos.x < -60 || v.pos.x > World.width + 60;
    if (v.pos.y >= World.hazardY || off) _loseVessel(v);
  }

  void _updateFollower(Vessel f, double dt) {
    if (f.state == VesselState.homeward) {
      _sailHome(f, dt);
      return;
    }
    final lead = _byId(f.leaderId!);
    if (lead == null || lead.state == VesselState.lost) {
      // The lead was lost: its followers turn back out to sea for a moment,
      // then drift in again as single boats the keeper can still save.
      f.leaderId = null;
      f.chart = 0;
      f.state = VesselState.drifting;
      f.cruise = f.vel.length;
      f.turnBack = 2.2;
      final side = f.followIndex.isEven ? 1.0 : -1.0;
      f.vel = Vec(side * 0.55, -0.85).normalized() * (f.cruise * 0.7);
      return;
    }
    final target = lead.pos - lead.vel.normalized() * (followSpacing * f.followIndex);
    final to = target - f.pos;
    f.pos = f.pos + to * math.min(1, dt * 4);
    f.lit = false;
  }

  /// Charted vessels sail to a point clear of the rocks, then into the harbor.
  /// Followers already trail their lead, so they keep their place in line.
  void _sailHome(Vessel v, double dt) {
    const waypoint = Vec(World.harborX + 60, World.hazardY - 80);
    const harbor = Vec(World.harborX, World.harborY);
    final goal = v._passedWaypoint ? harbor : waypoint;
    final to = goal - v.pos;
    final stride = homeSpeed * dt;
    if (to.length <= stride) {
      v.pos = goal;
      if (v._passedWaypoint) {
        _bringHome(v);
      } else {
        v._passedWaypoint = true;
      }
      return;
    }
    v.vel = to.normalized() * homeSpeed;
    v.pos = v.pos + v.vel * dt;
  }

  void _bringHome(Vessel v) {
    v.state = VesselState.home;
    souls += 1;
    streak += 1;
    bestStreak = math.max(bestStreak, streak);
    score += 1 + streak ~/ 5;
    _events.add(SimEvent(SimEventType.home, v.pos));
  }

  void _loseVessel(Vessel v) {
    v.state = VesselState.lost;
    lost += 1;
    embers -= 1;
    streak = 0;
    _events.add(SimEvent(SimEventType.lost, v.pos));
    _events.add(SimEvent(SimEventType.emberOut, v.pos));
  }
}
