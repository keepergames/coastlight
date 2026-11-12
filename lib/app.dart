import 'package:flutter/material.dart';

import 'data/progress.dart';
import 'engine/modes.dart';
import 'engine/seasons.dart';
import 'screens/night_screen.dart';
import 'screens/chart_screen.dart';
import 'screens/daily_screen.dart';
import 'screens/duty_screen.dart';
import 'screens/hub_screen.dart';
import 'screens/log_screen.dart';
import 'screens/promise_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/shop_screen.dart';
import 'screens/splash_screen.dart';
import 'theme/cove_theme.dart';

/// Set only for the web preview used to record store screenshots and the
/// gameplay video (`--dart-define=KEEPER_PREVIEW=true`). Never set for the
/// Android release.
const bool keeperPreview = bool.fromEnvironment('KEEPER_PREVIEW');

class Routes {
  Routes._();

  static const splash = '/';
  static const hub = '/hub';
  static const chart = '/chart';
  static const night = '/night';
  static const daily = '/daily';
  static const shop = '/shop';
  static const log = '/log';
  static const settings = '/settings';
  static const duty = '/duty';
  static const promise = '/promise';
}

/// Hands the saved progress to every screen and rebuilds them when it changes.
class ProgressScope extends InheritedNotifier<Progress> {
  const ProgressScope({
    super.key,
    required Progress progress,
    required super.child,
  }) : super(notifier: progress);

  static Progress of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ProgressScope>()!.notifier!;
}

/// Lets the hub know when the player returns to it (to restart its music).
final RouteObserver<PageRoute<dynamic>> routeObserver =
    RouteObserver<PageRoute<dynamic>>();

extension ProgressContext on BuildContext {
  Progress get progress => ProgressScope.of(this);
}

class KeeperApp extends StatelessWidget {
  const KeeperApp({super.key, required this.progress, this.skipSplash = false});

  final Progress progress;

  /// Tests start on the hub directly.
  final bool skipSplash;

  @override
  Widget build(BuildContext context) {
    return ProgressScope(
      progress: progress,
      child: MaterialApp(
        title: 'Keeper of the Cove',
        debugShowCheckedModeBanner: false,
        theme: coveTheme,
        navigatorObservers: [routeObserver],
        initialRoute: skipSplash ? Routes.hub : Routes.splash,
        // Only the one starting screen: the default would also stack the
        // splash under /hub, and its timer would then replace the top screen.
        onGenerateInitialRoutes: (name) => [_route(RouteSettings(name: name))],
        onGenerateRoute: _route,
        builder: (context, child) {
          // Respect the player's text size, but keep layouts from breaking.
          final mq = MediaQuery.of(context);
          final scale = mq.textScaler.clamp(
            minScaleFactor: 0.9,
            maxScaleFactor: 1.35,
          );
          return MediaQuery(
            data: mq.copyWith(textScaler: scale),
            child: child!,
          );
        },
      ),
    );
  }

  static Route<dynamic> _route(RouteSettings settings) {
    if (keeperPreview && (settings.name ?? '').startsWith('/watch/')) {
      return MaterialPageRoute(
        settings: const RouteSettings(name: Routes.night),
        builder: (_) => _watch(settings.name!),
      );
    }
    final Widget page = switch (settings.name) {
      Routes.splash => const SplashScreen(),
      Routes.hub => const HubScreen(),
      Routes.chart => ChartScreen(initialSeason: settings.arguments as int?),
      Routes.daily => const DailyScreen(),
      Routes.shop => const ShopScreen(),
      Routes.log => const LogScreen(),
      Routes.settings => const SettingsScreen(),
      Routes.duty => const DutyScreen(),
      Routes.promise => const PromiseScreen(),
      _ => const HubScreen(),
    };
    return MaterialPageRoute(settings: settings, builder: (_) => page);
  }
}

/// Preview only: the keeper bot plays a night through to its result screen.
Widget _watch(String name) {
  final what = name.substring('/watch/'.length);
  final args = switch (what) {
    'endless' => const NightArgs(
      mode: PlayMode.endless,
      spec: endlessSpec,
      seed: 77,
    ),
    'daily' => NightArgs(
      mode: PlayMode.daily,
      spec: dailySpec(DateTime.now(), furthestSeason: 3),
      day: dayKey(DateTime.now()),
    ),
    _ => NightArgs(
      mode: PlayMode.story,
      spec: nightSpec(int.tryParse(what)?.clamp(1, nightCount) ?? 1),
    ),
  };
  return NightScreen(args: args, autoplay: true, showResult: true);
}
