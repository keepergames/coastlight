import 'package:flutter_test/flutter_test.dart';
import 'package:keeper_of_the_cove/engine/bot.dart';
import 'package:keeper_of_the_cove/engine/night_spec.dart';
import 'package:keeper_of_the_cove/engine/seasons.dart';

void main() {
  test('there are 52 nights in 4 seasons that cover them exactly', () {
    expect(allNights.length, nightCount);
    expect(nightCount, 52);
    expect(seasons.length, 4);
    var expected = 1;
    for (final s in seasons) {
      expect(s.first, expected);
      expected = s.last + 1;
    }
    expect(expected, nightCount + 1);
    for (var i = 0; i < allNights.length; i++) {
      expect(allNights[i].id, i + 1);
      expect(allNights[i].season, seasonOf(i + 1).index);
    }
  });

  test('every night has a unique name and sane dials', () {
    final names = allNights.map((n) => n.name).toSet();
    expect(names.length, nightCount);
    for (final n in allNights) {
      expect(n.quota, greaterThan(0), reason: n.name);
      expect(n.dawnSeconds, inInclusiveRange(30, 200), reason: n.name);
      expect(n.beamReach, inInclusiveRange(0.55, 1.1), reason: n.name);
      expect(n.speed, inInclusiveRange(40, 160), reason: n.name);
    }
  });

  test('each season introduces its one mechanic and the first nights teach it', () {
    for (final s in seasons) {
      final first = allNights[s.first - 1];
      expect(first.mechanics, contains(s.mechanic), reason: s.name);
      expect(first.tutorial, isNotNull, reason: '${s.name} opens with a tutorial');
      final finale = allNights[s.last - 1];
      expect(finale.finale, isTrue, reason: '${s.name} ends on a finale');
      // No mechanic appears before the season that teaches it.
      for (final later in seasons.where((o) => o.index > s.index)) {
        for (final id in s.nightIds) {
          expect(allNights[id - 1].mechanics, isNot(contains(later.mechanic)),
              reason: 'night $id uses ${later.mechanic} too early');
        }
      }
    }
  });

  test('every night can be kept by a keeper with human limits', () {
    for (final spec in allNights) {
      final runs = [for (final bot in KeeperBot.styles()) playNight(spec, bot)];
      final best = runs.where((r) => r.kept).toList();
      expect(best, isNotEmpty, reason: '${spec.id} ${spec.name} was never kept');
      expect(best.map((r) => r.embers).reduce((a, b) => a > b ? a : b),
          greaterThanOrEqualTo(1));
      // Kept nights finish before dawn with time to spare for a real player.
      for (final r in best) {
        expect(r.seconds, lessThan(spec.dawnSeconds), reason: spec.name);
      }
    }
  });

  test('seasons get harder: a skilled keeper keeps fewer embers later on', () {
    const seeds = [11, 22, 33, 44];
    final avg = <double>[];
    for (final s in seasons) {
      var embers = 0, runs = 0;
      for (final id in s.nightIds) {
        for (final seed in seeds) {
          embers += playNight(allNights[id - 1], KeeperBot(), seed: seed).embers;
          runs++;
        }
      }
      avg.add(embers / runs);
    }
    for (var i = 1; i < avg.length; i++) {
      expect(avg[i], lessThanOrEqualTo(avg[i - 1] + 0.03), reason: 'season $i: $avg');
    }
    expect(avg.last, lessThan(avg.first - 0.1), reason: '$avg');
  });

  test('story nights are long enough to feel like a night (35-120 s)', () {
    for (final spec in allNights.where((n) => n.id > 2)) {
      final r = playNight(spec, KeeperBot());
      if (!r.kept) continue;
      expect(r.seconds, inInclusiveRange(35, 120), reason: spec.name);
    }
  });

  test('the shapes of mechanic dials match their seasons', () {
    expect(allNights.where((n) => n.season == 0).every((n) => n.fogBanks == 0), isTrue);
    expect(allNights.where((n) => n.season == 1).every((n) => n.fogBanks > 0), isTrue);
    expect(allNights.where((n) => n.season == 3).every((n) => n.buoys.isNotEmpty), isTrue);
    expect(nightSpec(1).mechanics, {Mechanic.beam});
  });
}
