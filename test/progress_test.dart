import 'package:flutter_test/flutter_test.dart';
import 'package:keeper_of_the_cove/data/catalog.dart';
import 'package:keeper_of_the_cove/data/progress.dart';
import 'package:keeper_of_the_cove/engine/modes.dart';
import 'package:keeper_of_the_cove/engine/seasons.dart';
import 'package:keeper_of_the_cove/engine/sim.dart';
import 'package:shared_preferences/shared_preferences.dart';

RunSummary storyRun(int id, {int embers = 3, bool kept = true, int souls = 10}) => RunSummary(
      mode: PlayMode.story,
      spec: nightSpec(id),
      outcome: kept ? NightOutcome.kept : NightOutcome.dark,
      embers: kept ? embers : 0,
      souls: souls,
      bestStreak: souls,
      seconds: 60,
    );

void main() {
  test('a fresh keeper starts on night 1 with the default goods', () {
    final p = Progress.memory();
    expect(p.nextNight, 1);
    expect(p.isUnlocked(1), isTrue);
    expect(p.isUnlocked(2), isFalse);
    expect(p.oil, 0);
    expect(p.equippedGood(Shelf.beam).id, 'beam_amber');
    expect(p.furthestSeason, 0);
  });

  test('keeping a night saves lanterns, opens the next and pays lamp oil', () {
    final p = Progress.memory();
    final r = p.record(storyRun(1, embers: 2));
    expect(p.isKept(1), isTrue);
    expect(p.lanternsFor(1), 2);
    expect(p.isUnlocked(2), isTrue);
    expect(p.nextNight, 2);
    expect(r.firstKeep, isTrue);
    expect(r.oil, 10 + 4 * 2 + 10); // souls + lanterns + first keep
    expect(p.oil, r.oil);
    expect(r.newAchievements.map((a) => a.id), containsAll(['first_soul', 'first_night']));
  });

  test('replaying only pays the lanterns you improve on', () {
    final p = Progress.memory();
    p.record(storyRun(1, embers: 2));
    final before = p.oil;
    final r = p.record(storyRun(1, embers: 3, souls: 4));
    expect(p.lanternsFor(1), 3);
    expect(r.firstKeep, isFalse);
    expect(r.oil, 4 + 4);
    expect(p.oil, before + 8);
    final worse = p.record(storyRun(1, embers: 1, souls: 4));
    expect(p.lanternsFor(1), 3, reason: 'best lanterns are kept');
    expect(worse.oil, 4);
  });

  test('a lost night keeps nothing but still pays for souls brought home', () {
    final p = Progress.memory();
    final r = p.record(storyRun(1, kept: false, souls: 3));
    expect(p.isKept(1), isFalse);
    expect(r.oil, 3);
    expect(p.embersLost, 3);
  });

  test('keeping a season finale opens the next season and announces it', () {
    final p = Progress.memory();
    Reward? last;
    for (var id = 1; id <= 10; id++) {
      last = p.record(storyRun(id));
    }
    expect(last!.newSeason?.name, 'Fog Season');
    expect(p.seasonOpen(1), isTrue);
    expect(p.furthestSeason, 1);
    expect(p.seasonsKept, 1);
    expect(p.unlocked, containsAll(['still_water', 'bright_still']));
  });

  test('daily tide: one bonus per day and a streak across days', () {
    final p = Progress.memory();
    RunSummary daily(DateTime d) => RunSummary(
          mode: PlayMode.daily,
          spec: dailySpec(d, furthestSeason: 0),
          outcome: NightOutcome.kept,
          embers: 3,
          souls: 12,
          bestStreak: 12,
          seconds: 70,
          day: dayKey(d),
        );
    final d1 = DateTime(2026, 11, 10);
    expect(p.record(daily(d1)).oil, 12 + 20);
    expect(p.record(daily(d1)).oil, 12, reason: 'the bonus is paid once a day');
    p.record(daily(DateTime(2026, 11, 11)));
    p.record(daily(DateTime(2026, 11, 12)));
    expect(p.dailyStreak(DateTime(2026, 11, 12)), 3);
    expect(p.dailyStreak(DateTime(2026, 11, 13)), 3, reason: 'today not yet played keeps the streak');
    expect(p.dailyStreak(DateTime(2026, 11, 15)), 0);
    expect(p.bestDailyStreak, 3);
    expect(p.dailyDone(DateTime(2026, 11, 12)), isTrue);
  });

  test('the longest night keeps the best count', () {
    final p = Progress.memory();
    RunSummary run(int souls) => RunSummary(
          mode: PlayMode.endless,
          spec: endlessSpec,
          outcome: NightOutcome.dark,
          embers: 0,
          souls: souls,
          bestStreak: souls,
          seconds: 100,
        );
    expect(p.record(run(40)).newBest, isFalse, reason: 'first run is not "a new best"');
    expect(p.longestBest, 40);
    expect(p.record(run(30)).newBest, isFalse);
    expect(p.record(run(65)).newBest, isTrue);
    expect(p.longestBest, 65);
    expect(p.unlocked, contains('longest_60'));
  });

  test('the chandlery sells for oil, equips, and never sells twice', () {
    final p = Progress.memory();
    final glass = goodById('beam_candle');
    expect(p.buy(glass), isNull, reason: 'cannot afford yet');
    p.oil = 500;
    final fresh = p.buy(glass);
    expect(fresh, isNotNull);
    expect(fresh!.map((a) => a.id), contains('chandler'));
    expect(p.oil, 500 - glass.price);
    expect(p.equippedGood(Shelf.beam).id, 'beam_candle');
    expect(p.buy(glass), isNull, reason: 'already owned');
    p.use(goodById('beam_amber'));
    expect(p.equippedGood(Shelf.beam).id, 'beam_amber');
    final cat = goodById('keep_cat');
    p.buy(cat);
    expect(p.shownKeepsakes, contains('keep_cat'));
    p.use(cat);
    expect(p.shownKeepsakes, isNot(contains('keep_cat')), reason: 'keepsakes toggle on and off');
  });

  test('prices are fixed and every shelf has a free default', () {
    for (final s in Shelf.values.where(isExclusive)) {
      expect(goodById(defaultFor(s)).price, 0);
    }
    expect(catalog.where((g) => g.price > 0).every((g) => g.price >= 50), isTrue);
    expect(catalog.map((g) => g.id).toSet().length, catalog.length);
  });

  test('reset clears progress and purchases but keeps settings', () async {
    final p = Progress.memory();
    p.record(storyRun(1));
    p.oil = 400;
    p.buy(goodById('paint_tide'));
    p.setSettings(sound: false, reduceMotion: true);
    await p.reset();
    expect(p.isKept(1), isFalse);
    expect(p.oil, 0);
    expect(p.owned.contains('paint_tide'), isFalse);
    expect(p.equippedGood(Shelf.paint).id, 'paint_rust');
    expect(p.unlocked, isEmpty);
    expect(p.sound, isFalse);
    expect(p.reduceMotion, isTrue);
  });

  test('progress survives a restart and a damaged save starts fresh', () async {
    SharedPreferences.setMockInitialValues({});
    final a = await Progress.load();
    a.record(storyRun(1, embers: 2));
    a.oil += 300;
    a.buy(goodById('keep_vane'));
    a.setSettings(music: false);
    await Future<void>.delayed(Duration.zero);

    final b = await Progress.load();
    expect(b.lanternsFor(1), 2);
    expect(b.owned, contains('keep_vane'));
    expect(b.shownKeepsakes, contains('keep_vane'));
    expect(b.music, isFalse);
    expect(b.oil, a.oil);

    SharedPreferences.setMockInitialValues({Progress.storageKey: '{not json'});
    final c = await Progress.load();
    expect(c.nextNight, 1);
  });

  test('there are twenty achievements with unique ids', () {
    expect(achievements.length, 20);
    expect(achievements.map((a) => a.id).toSet().length, 20);
  });
}
