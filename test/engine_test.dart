import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:keeper_of_the_cove/engine/bot.dart';
import 'package:keeper_of_the_cove/engine/modes.dart';
import 'package:keeper_of_the_cove/engine/night_spec.dart';
import 'package:keeper_of_the_cove/engine/rng.dart';
import 'package:keeper_of_the_cove/engine/seasons.dart';
import 'package:keeper_of_the_cove/engine/sim.dart';
import 'package:keeper_of_the_cove/engine/vec.dart';

/// A one-boat night that never spawns on its own.
NightSpec lone({List<Wave> waves = const [Wave(at: 0, x: 0.5, aimX: 0.5)], int quota = 1}) =>
    NightSpec(
      id: 0,
      season: 0,
      name: 'test',
      quota: quota,
      dawnSeconds: 60,
      maxAtOnce: 1,
      spawnPeriod: 99,
      speed: 80,
      beamReach: 1.0,
      randomSpawns: false,
      waves: waves,
    );

void main() {
  group('Rng', () {
    test('same seed gives the same sequence; values stay in range', () {
      final a = Rng(42), b = Rng(42);
      for (var i = 0; i < 200; i++) {
        final x = a.next();
        expect(x, b.next());
        expect(x, inInclusiveRange(0, 1));
      }
      expect(Rng(1).next(), isNot(Rng(2).next()));
    });

    test('imul32 matches a plain 32-bit multiply', () {
      expect(imul32(0x12345678, 0x9ABCDEF), (0x12345678 * 0x9ABCDEF) & 0xFFFFFFFF);
      expect(hashSeed('a'), hashSeed('a'));
      expect(hashSeed('a'), isNot(hashSeed('b')));
    });
  });

  group('beam', () {
    test('lights a point inside the cone and within reach only', () {
      final sim = CoveSim(lone());
      sim.aim(-math.pi / 2);
      expect(sim.illuminates(const Vec(World.lampX, 800)), isTrue);
      expect(sim.illuminates(const Vec(World.lampX + 400, 800)), isFalse);
      expect(sim.illuminates(const Vec(World.lampX, -400)), isFalse); // beyond reach
    });

    test('only sweeps over the sea (upper half)', () {
      final sim = CoveSim(lone());
      sim.aim(0.5);
      expect(sim.beamAngle, lessThan(0));
      sim.aim(-math.pi - 1);
      expect(sim.beamAngle, greaterThan(-math.pi));
    });
  });

  group('charting', () {
    test('a boat held in the beam is charted, sails home and counts as a soul', () {
      final sim = CoveSim(lone());
      final events = <SimEventType>[];
      while (!sim.over && sim.t < 40) {
        final v = sim.vessels.where((v) => v.state == VesselState.drifting);
        if (v.isNotEmpty) sim.aimAt(v.first.pos);
        sim.step(1 / 30);
        events.addAll(sim.drainEvents().map((e) => e.type));
      }
      expect(sim.outcome, NightOutcome.kept);
      expect(sim.souls, 1);
      expect(sim.embers, 3);
      expect(events, containsAllInOrder([SimEventType.spawn, SimEventType.charted, SimEventType.home, SimEventType.kept]));
    });

    test('an unlit boat reaches the rocks and an ember goes out', () {
      final sim = CoveSim(lone(quota: 5));
      sim.aim(-0.2); // point the beam away
      final events = <SimEventType>[];
      while (sim.lost == 0 && sim.t < 40) {
        sim.step(1 / 30);
        events.addAll(sim.drainEvents().map((e) => e.type));
      }
      expect(sim.lost, 1);
      expect(sim.embers, 2);
      expect(sim.streak, 0);
      expect(events, contains(SimEventType.emberOut));
    });

    test('the ring fades slowly when the light moves away', () {
      final sim = CoveSim(lone(quota: 5));
      Vessel boat() => sim.vessels.first;
      sim.step(0.1);
      for (var i = 0; i < 30; i++) {
        sim.aimAt(boat().pos);
        sim.step(1 / 30);
      }
      final lit = boat().chart;
      expect(lit, greaterThan(0.3));
      sim.aim(-0.2);
      sim.step(1);
      expect(boat().chart, lessThan(lit));
      expect(boat().chart, greaterThan(0));
    });

    test('three lost boats put the light out', () {
      final sim = CoveSim(lone(quota: 9, waves: const [
        Wave(at: 0, x: 0.3),
        Wave(at: 0.2, x: 0.5),
        Wave(at: 0.4, x: 0.7),
      ]));
      sim.aim(-0.2);
      sim.step(40);
      expect(sim.outcome, NightOutcome.dark);
      expect(sim.embers, 0);
    });

    test('dawn ends a night whose quota is not met', () {
      final spec = lone(quota: 99);
      final sim = CoveSim(spec);
      sim.step(spec.dawnSeconds + 1);
      expect(sim.outcome, anyOf(NightOutcome.dawnShort, NightOutcome.dark));
    });
  });

  group('convoys', () {
    test('lighting the lead brings the whole line home', () {
      final spec = lone(quota: 3, waves: const [Wave(at: 0, x: 0.5, convoy: 2, aimX: 0.5)]);
      final sim = CoveSim(spec);
      expect(sim.vessels, isEmpty);
      sim.step(0.05);
      expect(sim.vessels.length, 3);
      expect(sim.vessels.where((v) => v.isLead).length, 1);
      while (!sim.over && sim.t < 60) {
        final lead = sim.vessels.where((v) => v.isLead && v.state == VesselState.drifting);
        if (lead.isNotEmpty) sim.aimAt(lead.first.pos);
        sim.step(1 / 30);
      }
      expect(sim.outcome, NightOutcome.kept);
      expect(sim.souls, 3);
    });

    test('lighting a follower does not chart it', () {
      final sim = CoveSim(lone(quota: 3, waves: const [Wave(at: 0, x: 0.5, convoy: 2, aimX: 0.5)]));
      sim.step(0.05);
      final follower = sim.vessels.firstWhere((v) => v.isFollower);
      for (var i = 0; i < 60; i++) {
        sim.aimAt(follower.pos);
        sim.step(1 / 30);
      }
      expect(follower.chart, 0);
    });

    test('when the lead is lost, its followers turn back to sea', () {
      final sim = CoveSim(lone(quota: 9, waves: const [Wave(at: 0, x: 0.5, convoy: 2, aimX: 0.5)]));
      sim.aim(-0.2);
      while (sim.lost == 0 && sim.t < 60) {
        sim.step(1 / 30);
      }
      expect(sim.lost, 1);
      sim.step(0.1);
      final scattered = sim.vessels.where((v) => v.active && !v.isFollower && v.followers == 0);
      expect(scattered.length, 2);
      expect(scattered.every((v) => v.vel.y < 0), isTrue, reason: 'heading back out');
    });
  });

  group('fog and buoys', () {
    test('a boat inside fog charts more slowly', () {
      double chartAfter(int fog) {
        final spec = NightSpec(
          id: 0, season: 1, name: 'f', quota: 5, dawnSeconds: 60, maxAtOnce: 1,
          spawnPeriod: 99, speed: 1, beamReach: 1.0, randomSpawns: false,
          fogBanks: fog, fogRadius: 2000, fogSpeed: 0,
          waves: const [Wave(at: 0, x: 0.5, aimX: 0.5)],
        );
        final sim = CoveSim(spec);
        sim.step(0.02);
        for (var i = 0; i < 30; i++) {
          sim.aimAt(sim.vessels.first.pos);
          sim.step(1 / 30);
        }
        return sim.vessels.first.chart;
      }

      expect(chartAfter(1), lessThan(chartAfter(0) * 0.7));
    });

    test('a kindled buoy charts nearby boats on its own, then burns out', () {
      final spec = NightSpec(
        id: 0, season: 3, name: 'b', quota: 5, dawnSeconds: 90, maxAtOnce: 1,
        spawnPeriod: 99, speed: 1, beamReach: 1.0, randomSpawns: false,
        buoys: const [(0.5, 0.0)],
        waves: const [Wave(at: 0, x: 0.5, aimX: 0.5)],
      );
      final sim = CoveSim(spec);
      final buoy = sim.buoys.first;
      sim.aimAt(buoy.pos);
      final types = <SimEventType>[];
      sim.step(1.2);
      types.addAll(sim.drainEvents().map((e) => e.type));
      expect(buoy.lit, isTrue);
      expect(types, contains(SimEventType.kindled));
      sim.aim(-0.2); // look away: the halo keeps working
      sim.step(2);
      expect(sim.vessels.first.chart, greaterThan(0.3));
      sim.step(CoveSim.buoyDuration);
      types.addAll(sim.drainEvents().map((e) => e.type));
      expect(buoy.lit, isFalse);
      expect(types, contains(SimEventType.buoyOut));
    });
  });

  group('determinism and modes', () {
    test('the same night plays out identically', () {
      final a = playNight(allNights[20], KeeperBot());
      final b = playNight(allNights[20], KeeperBot());
      expect(a.souls, b.souls);
      expect(a.embers, b.embers);
      expect(a.seconds, b.seconds);
    });

    test('step size does not change the result', () {
      final spec = allNights[5];
      final a = CoveSim(spec), b = CoveSim(spec);
      for (var i = 0; i < 300; i++) {
        a.step(1 / 30);
      }
      for (var i = 0; i < 150; i++) {
        b.step(1 / 15);
      }
      expect(a.t, closeTo(b.t, 1e-6));
      expect(a.vessels.length, b.vessels.length);
      expect(a.embers, b.embers);
    });

    test('daily tide is stable per date and respects the seasons reached', () {
      final d = DateTime(2026, 11, 12);
      final a = dailySpec(d, furthestSeason: 0);
      final b = dailySpec(d, furthestSeason: 0);
      expect(a.seed, b.seed);
      expect(a.quota, b.quota);
      expect(a.name, 'Daily Tide');
      expect(a.mechanics, {Mechanic.beam});
      expect(dailySpec(DateTime(2026, 11, 13), furthestSeason: 0).seed, isNot(a.seed));
      expect(dayKey(d), '2026-11-12');
      // Every daily in a month can be kept.
      for (var i = 0; i < 30; i++) {
        final spec = dailySpec(d.add(Duration(days: i)), furthestSeason: 3);
        final kept = KeeperBot.styles().any((bot) => playNight(spec, bot).kept);
        expect(kept, isTrue, reason: 'daily ${dayKey(d.add(Duration(days: i)))}');
      }
    });

    test('the longest night has no dawn and grows busier until the light goes out', () {
      expect(endlessSpec.endless, isTrue);
      final sim = CoveSim(endlessSpec, seed: 7);
      final bot = KeeperBot();
      while (!sim.over && sim.t < 900) {
        bot.act(sim, 1 / 30);
        sim.step(1 / 30);
      }
      expect(sim.outcome, NightOutcome.dark, reason: 'endless must end eventually');
      expect(sim.souls, greaterThan(30), reason: 'a skilled keeper lasts a while');
      expect(sim.stage, greaterThan(2));
    });
  });
}
