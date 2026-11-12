import 'night_spec.dart';
import 'sim.dart';
import 'vec.dart';

/// A keeper that plays with human limits: the beam turns at most [turnRate]
/// rad/s and the target is only re-chosen every [reaction] seconds.
///
/// Policy: light the boat nearest the rocks; when nothing is close to the
/// rocks, kindle a dark buoy that has boats around it. Simple and robust,
/// which is also how most people play.
///
/// Used by tests to prove every night can be kept, by the How to Play demo,
/// and by the store-video recording.
class KeeperBot {
  KeeperBot({this.turnRate = 2.4, this.reaction = 0.25, this.useBuoys = true});

  /// A distracted keeper: reacts late, turns slowly and ignores the buoys.
  /// Used to check that later seasons really are harder.
  KeeperBot.casual() : this(turnRate: 1.3, reaction: 0.7, useBuoys: false);

  /// An unhurried keeper in between the two.
  KeeperBot.steady() : this(turnRate: 1.9, reaction: 0.4);

  /// The styles used to prove a night can be kept within human limits.
  static List<KeeperBot> styles() =>
      [KeeperBot(), KeeperBot.steady(), KeeperBot.casual()];

  final double turnRate;
  final double reaction;
  final bool useBuoys;

  double _clock = 0;
  double? _targetAngle;

  void act(CoveSim sim, double dt) {
    _clock -= dt;
    if (_clock <= 0) {
      _clock = reaction;
      _targetAngle = _choose(sim);
    }
    final goal = _targetAngle;
    if (goal == null) return;
    final diff = wrapAngle(goal - sim.beamAngle);
    final maxStep = turnRate * dt;
    sim.aim(sim.beamAngle + diff.clamp(-maxStep, maxStep));
  }

  double _angleTo(CoveSim sim, Vec p) => (p - sim.lamp).angle;

  double? _choose(CoveSim sim) {
    final boats = sim.vessels
        .where((v) => v.state == VesselState.drifting && !v.isFollower)
        .toList();
    final reachable =
        boats.where((v) => v.pos.distanceTo(sim.lamp) <= sim.reach - 10).toList();

    Vessel? nearest;
    for (final v in reachable) {
      if (nearest == null || v.pos.y > nearest.pos.y) nearest = v;
    }

    final calm = nearest == null || nearest.pos.y < World.hazardY - 520;
    if (useBuoys && calm) {
      for (final b in sim.buoys) {
        if (b.lit || b.pos.distanceTo(sim.lamp) > sim.reach) continue;
        final near = boats.any((v) => v.pos.distanceTo(b.pos) < CoveSim.buoyRadius * 1.5);
        if (near) return _angleTo(sim, b.pos);
      }
    }

    if (nearest != null) return _angleTo(sim, nearest.pos + nearest.vel * 0.15);
    // Nothing in reach yet: wait where the next boat will arrive.
    Vessel? next;
    for (final v in boats) {
      if (next == null || v.pos.y > next.pos.y) next = v;
    }
    return next == null ? null : _angleTo(sim, next.pos);
  }
}

/// Result of a full bot playthrough.
class BotRun {
  const BotRun(this.outcome, this.embers, this.souls, this.seconds);
  final NightOutcome? outcome;
  final int embers;
  final int souls;
  final double seconds;

  bool get kept => outcome == NightOutcome.kept;
}

/// Plays [spec] start to finish with [bot]. Endless nights stop at [limit].
BotRun playNight(NightSpec spec, KeeperBot bot, {int? seed, double limit = 600}) {
  final sim = CoveSim(spec, seed: seed);
  const dt = 1 / 30;
  while (!sim.over && sim.t < limit) {
    bot.act(sim, dt);
    sim.step(dt);
  }
  return BotRun(sim.outcome, sim.embers, sim.souls, sim.t);
}
