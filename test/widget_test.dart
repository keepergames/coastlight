import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keeper_of_the_cove/app.dart';
import 'package:keeper_of_the_cove/audio/fx.dart';
import 'package:keeper_of_the_cove/data/progress.dart';
import 'package:keeper_of_the_cove/engine/seasons.dart';
import 'package:keeper_of_the_cove/engine/sim.dart';
import 'package:keeper_of_the_cove/screens/night_screen.dart';
import 'package:keeper_of_the_cove/screens/result_screen.dart';

/// Pumps frames for [d] without waiting for animations that never settle
/// (the hub's turning light and the sea run forever).
Future<void> pumpFor(WidgetTester tester, Duration d) async {
  final end = tester.binding.clock.now().add(d);
  while (tester.binding.clock.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Future<Progress> boot(WidgetTester tester, {Size size = const Size(412, 892), Progress? progress}) async {
  Fx.audioDisabled = true;
  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final p = progress ?? (Progress.memory()..seenDuty = true);
  await tester.pumpWidget(KeeperApp(progress: p, skipSplash: true));
  await pumpFor(tester, const Duration(milliseconds: 400));
  return p;
}

void main() {
  testWidgets('the hub shows the cove and its way in', (tester) async {
    await boot(tester);
    expect(find.text('Tend the Light'), findsWidgets);
    expect(find.text('Sea Chart'), findsOneWidget);
    expect(find.text('Chandlery'), findsOneWidget);
    expect(find.text('Daily Tide'), findsOneWidget);
    expect(find.text("Keeper's Log"), findsOneWidget);
    expect(find.text('The Longest Night'), findsOneWidget);
    expect(find.textContaining('Night 1, The First Light'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Tend the Light starts night 1; pause and return home', (tester) async {
    await boot(tester);
    await tester.tap(find.text('Tend the Light').last);
    await pumpFor(tester, const Duration(milliseconds: 800));
    expect(find.byType(NightScreen), findsOneWidget);
    expect(find.text('The First Light'), findsOneWidget);
    expect(find.text('0 / 4'), findsOneWidget);

    // Sweep the beam: dragging anywhere aims it.
    await tester.dragFrom(const Offset(206, 700), const Offset(-60, -300));
    await pumpFor(tester, const Duration(milliseconds: 300));

    await tester.tap(find.byTooltip('Pause'));
    await pumpFor(tester, const Duration(milliseconds: 500));
    expect(find.text('Relight the watch'), findsOneWidget);
    await tester.tap(find.text('Return to the lighthouse'));
    await pumpFor(tester, const Duration(milliseconds: 800));
    expect(find.byType(NightScreen), findsNothing);
    expect(find.text('Sea Chart'), findsOneWidget);
  });

  testWidgets('the keeper bot plays a real night screen without errors', (tester) async {
    await boot(tester);
    final nav = tester.state<NavigatorState>(find.byType(Navigator));
    nav.push(MaterialPageRoute(settings: const RouteSettings(name: Routes.night), builder: (_) => const _BotNight()));
    await pumpFor(tester, const Duration(seconds: 20));
    expect(find.byType(NightScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(find.textContaining(' / 4'), findsOneWidget);
    // The sea still fills the screen after the intro title has faded away.
    final sea = find.byWidgetPredicate((w) => w is CustomPaint && w.painter.runtimeType.toString() == 'NightPainter');
    expect(tester.getSize(sea), const Size(412, 892));
  });

  testWidgets('dawn shows lanterns, oil and Sail on after a kept night', (tester) async {
    final p = await boot(tester);
    final run = RunSummaryFake.kept();
    final reward = p.record(run);
    final nav = tester.state<NavigatorState>(find.byType(Navigator));
    nav.push(MaterialPageRoute(
      builder: (_) => ResultScreen(run: run, reward: reward, args: NightArgs(mode: PlayMode.story, spec: run.spec)),
    ));
    await pumpFor(tester, const Duration(seconds: 3));
    expect(find.text('Dawn'), findsOneWidget);
    expect(find.text('Sail on'), findsOneWidget);
    expect(find.bySemanticsLabel('3 of 3 lanterns'), findsWidgets);
    expect(find.textContaining('First Soul', findRichText: true), findsOneWidget);
    await tester.tap(find.text('Sail on'));
    await pumpFor(tester, const Duration(milliseconds: 800));
    expect(find.text('Two Lamps on the Water'), findsOneWidget);
  });

  testWidgets('the dark watch offers to light it again', (tester) async {
    final p = await boot(tester);
    final run = RunSummary(
      mode: PlayMode.story, spec: nightSpec(3), outcome: NightOutcome.dark,
      embers: 0, souls: 5, bestStreak: 3, seconds: 50,
    );
    final reward = p.record(run);
    final nav = tester.state<NavigatorState>(find.byType(Navigator));
    nav.push(MaterialPageRoute(
      builder: (_) => ResultScreen(run: run, reward: reward, args: NightArgs(mode: PlayMode.story, spec: run.spec)),
    ));
    await pumpFor(tester, const Duration(seconds: 2));
    expect(find.text('The Dark Watch'), findsOneWidget);
    expect(find.text('Light it again'), findsOneWidget);
    expect(find.text('Return to the lighthouse'), findsOneWidget);
  });

  testWidgets('every hub destination opens and comes back', (tester) async {
    await boot(tester);
    for (final (label, title) in [
      ('Sea Chart', 'Still Water'),
      ('Chandlery', 'Lamp glass'),
      ('Daily Tide', 'Ring the tide bell'),
      ("Keeper's Log", 'The watch so far'),
      ('Settings', 'Reduce motion'),
    ]) {
      await tester.tap(find.text(label).first);
      await pumpFor(tester, const Duration(milliseconds: 700));
      expect(find.text(title), findsWidgets, reason: label);
      expect(tester.takeException(), isNull, reason: label);
      await tester.tap(find.byTooltip('Back'));
      await pumpFor(tester, const Duration(milliseconds: 700));
      expect(find.text('Sea Chart'), findsOneWidget, reason: 'back from $label');
    }
  });

  testWidgets('settings switch sound off and the reset asks first', (tester) async {
    final p = await boot(tester);
    p.record(RunSummaryFake.kept());
    await tester.tap(find.text('Settings'));
    await pumpFor(tester, const Duration(milliseconds: 700));
    await tester.tap(find.text('Sound'));
    await pumpFor(tester, const Duration(milliseconds: 200));
    expect(p.sound, isFalse);

    await tester.scrollUntilVisible(find.text('Clear all progress'), 200);
    await tester.tap(find.text('Clear all progress'));
    await pumpFor(tester, const Duration(milliseconds: 500));
    expect(find.text('Clear the logbook?'), findsOneWidget);
    await tester.tap(find.text('Keep my progress'));
    await pumpFor(tester, const Duration(milliseconds: 500));
    expect(p.isKept(1), isTrue);

    await tester.tap(find.text('Clear all progress'));
    await pumpFor(tester, const Duration(milliseconds: 500));
    await tester.tap(find.text('Clear everything'));
    await pumpFor(tester, const Duration(milliseconds: 500));
    expect(p.isKept(1), isFalse);
  });

  testWidgets('the chandlery sells a beam glass for lamp oil', (tester) async {
    final p = await boot(tester);
    p.oil = 300;
    await tester.tap(find.text('Chandlery'));
    await pumpFor(tester, const Duration(milliseconds: 700));
    await tester.tap(find.text('Candle glass'));
    await pumpFor(tester, const Duration(milliseconds: 300));
    await tester.tap(find.text('Buy for 140 oil'));
    await pumpFor(tester, const Duration(milliseconds: 500));
    expect(p.owned, contains('beam_candle'));
    expect(p.oil, 160);
    expect(find.text('In use'), findsOneWidget);
  });

  testWidgets('the sea chart opens a night sheet and locked seasons say why', (tester) async {
    final p = await boot(tester);
    await tester.tap(find.text('Sea Chart'));
    await pumpFor(tester, const Duration(milliseconds: 900));
    expect(find.textContaining('to sail here'), findsWidgets);
    await tester.tap(find.bySemanticsLabel(RegExp('^Night 1, The First Light')));
    await pumpFor(tester, const Duration(milliseconds: 600));
    expect(find.text('Tend this night'), findsOneWidget);
    expect(p.nextNight, 1);
  });

  testWidgets('layouts hold at a small phone with large text', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await boot(tester, size: const Size(360, 640));
    expect(tester.takeException(), isNull);
    for (final label in ['Chandlery', "Keeper's Log", 'Daily Tide', 'Settings']) {
      await tester.tap(find.text(label).first);
      await pumpFor(tester, const Duration(milliseconds: 700));
      expect(tester.takeException(), isNull, reason: label);
      await tester.tap(find.byTooltip('Back'));
      await pumpFor(tester, const Duration(milliseconds: 700));
    }
  });
}

/// Night 1 played by the bot (exercises the full night screen without input).
class _BotNight extends StatelessWidget {
  const _BotNight();

  @override
  Widget build(BuildContext context) =>
      NightScreen(autoplay: true, args: NightArgs(mode: PlayMode.story, spec: nightSpec(1)));
}

class RunSummaryFake {
  static RunSummary kept() => RunSummary(
        mode: PlayMode.story,
        spec: nightSpec(1),
        outcome: NightOutcome.kept,
        embers: 3,
        souls: 4,
        bestStreak: 4,
        seconds: 40,
      );
}
