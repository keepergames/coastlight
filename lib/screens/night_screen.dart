import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../app.dart';
import '../audio/fx.dart';
import '../data/catalog.dart';
import '../data/progress.dart';
import '../engine/bot.dart';
import '../engine/night_spec.dart';
import '../engine/seasons.dart';
import '../engine/sim.dart';
import '../game/night_painter.dart';
import '../theme/cove_theme.dart';
import '../widgets/glyphs.dart';
import 'result_screen.dart';

class NightArgs {
  const NightArgs({
    required this.mode,
    required this.spec,
    this.seed,
    this.day,
  });
  final PlayMode mode;
  final NightSpec spec;
  final int? seed;
  final String? day;
}

/// The Night Watch: one night of play.
class NightScreen extends StatefulWidget {
  const NightScreen({
    super.key,
    required this.args,
    this.autoplay = false,
    this.showResult = false,
  });

  final NightArgs args;

  /// Lets the KeeperBot play (tests and the store-video recording).
  final bool autoplay;

  /// With [autoplay], still go on to the result screen when the night ends.
  final bool showResult;

  @override
  State<NightScreen> createState() => _NightScreenState();
}

class _NightScreenState extends State<NightScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final CoveSim sim = CoveSim(widget.args.spec, seed: widget.args.seed);
  final NightVisuals fx = NightVisuals();
  final ValueNotifier<int> frame = ValueNotifier(0);
  late final Ticker _ticker;
  KeeperBot? _bot;
  Duration _last = Duration.zero;

  bool _paused = false;
  double _countIn = 0;
  double _intro = 0;
  bool _finishing = false;
  final Set<int> _lit = {};
  double _chartSoundGap = 0;
  int _shownEmbers = CoveSim.maxEmbers;

  NightSpec get spec => widget.args.spec;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.autoplay) _bot = KeeperBot();
    _ticker = createTicker(_tick)..start();
    Fx.music(Music.sea);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    frame.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && !sim.over) _pause();
  }

  void _tick(Duration elapsed) {
    final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _last = elapsed;
    fx.update(dt);
    _intro += dt;
    if (!_paused) {
      if (_countIn > 0) {
        _countIn -= dt;
      } else if (!sim.over) {
        _bot?.act(sim, dt);
        sim.step(dt);
        _react(dt);
      } else {
        sim.step(dt); // let fades finish
      }
    }
    if (_shownEmbers != sim.embers) setState(() => _shownEmbers = sim.embers);
    frame.value++;
  }

  void _react(double dt) {
    _chartSoundGap -= dt;
    for (final v in sim.vessels) {
      if (v.lit && !_lit.contains(v.id)) {
        _lit.add(v.id);
        if (_chartSoundGap <= 0) {
          Fx.play(Sfx.chart, volume: 0.5);
          _chartSoundGap = 0.35;
        }
      } else if (!v.lit) {
        _lit.remove(v.id);
      }
    }
    final beam =
        context.progress.equippedGood(Shelf.beam).beamColor ?? CoveColors.beam;
    for (final e in sim.drainEvents()) {
      switch (e.type) {
        case SimEventType.charted:
          Fx.play(Sfx.charted, volume: 0.7);
          Fx.soft();
          fx.burst(e.pos, beam, count: 10, speed: 80, size: 4);
        case SimEventType.home:
          Fx.play(Sfx.home, volume: 0.55);
          fx.homeBloom = 1;
          fx.burst(e.pos, CoveColors.harbor, count: 14, speed: 90);
          setState(() {});
        case SimEventType.lost:
          Fx.play(Sfx.lost, volume: 0.8);
          Fx.firm();
          fx.shake = 1;
          fx.burst(
            e.pos,
            const Color(0xFF1B2836),
            count: 16,
            speed: 60,
            size: 7,
          );
        case SimEventType.emberOut:
          Fx.play(Sfx.ember, volume: 0.7);
        case SimEventType.kindled:
          Fx.play(Sfx.kindle, volume: 0.8);
          Fx.soft();
          fx.burst(e.pos, beam, count: 20, speed: 140);
        case SimEventType.buoyOut:
          Fx.play(Sfx.buoyOut, volume: 0.6);
        case SimEventType.kept:
        case SimEventType.dark:
        case SimEventType.dawnShort:
          _finish();
        case SimEventType.spawn:
          break;
      }
    }
  }

  void _finish() {
    if (_finishing) return;
    _finishing = true;
    // A breath before the result, so the last boat can reach the harbour.
    Timer(const Duration(milliseconds: 1400), () {
      if (!mounted || (widget.autoplay && !widget.showResult)) return;
      final run = RunSummary.fromSim(
        widget.args.mode,
        sim,
        day: widget.args.day,
      );
      final reward = context.progress.record(run);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          settings: const RouteSettings(name: '/result'),
          builder: (_) =>
              ResultScreen(run: run, reward: reward, args: widget.args),
        ),
      );
    });
  }

  void _aim(Offset local, Size size) {
    if (_paused || sim.over || widget.autoplay) return;
    sim.aimAt(SeaView(size).toWorld(local));
  }

  void _pause() {
    if (_paused || sim.over) return;
    setState(() => _paused = true);
    Fx.play(Sfx.page, volume: 0.5);
  }

  void _resume() {
    setState(() {
      _paused = false;
      _countIn = context.progress.reduceMotion ? 0.6 : 2.4;
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.progress;
    final beam = p.equippedGood(Shelf.beam).beamColor ?? CoveColors.beam;
    final livery = p.equippedGood(Shelf.boats).asset ?? 'skiff';
    final reduce =
        p.reduceMotion ||
        (MediaQuery.maybeDisableAnimationsOf(context) ?? false);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (widget.autoplay) {
          Navigator.of(context).pop();
        } else if (_paused) {
          _resume();
        } else {
          _pause();
        }
      },
      child: Scaffold(
        body: LayoutBuilder(
          builder: (context, box) {
            final size = box.biggest;
            // Expand: the intro (the only unpositioned child) shrinks to nothing
            // once it fades, and must not take the sea with it.
            return Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fill(
                  child: Semantics(
                    label: 'The sea. Drag anywhere to sweep the beam.',
                    child: Listener(
                      behavior: HitTestBehavior.opaque,
                      onPointerDown: (e) => _aim(e.localPosition, size),
                      onPointerMove: (e) => _aim(e.localPosition, size),
                      child: RepaintBoundary(
                        child: CustomPaint(
                          size: size,
                          painter: NightPainter(
                            sim: sim,
                            fx: fx,
                            beamColor: beam,
                            livery: livery,
                            reduceMotion: reduce,
                            repaint: frame,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                _Hud(
                  sim: sim,
                  onPause: widget.autoplay ? null : _pause,
                  frame: frame,
                ),
                _Intro(
                  spec: spec,
                  mode: widget.args.mode,
                  frame: frame,
                  intro: () => _intro,
                ),
                if (_countIn > 0 && !_paused)
                  _CountIn(frame: frame, left: () => _countIn),
                if (_paused)
                  _KeepersRest(
                    onResume: _resume,
                    onDuty: () async {
                      await Navigator.of(context).pushNamed(Routes.duty);
                    },
                    onLeave: () => Navigator.of(context).popUntil(
                      (r) => r.settings.name == Routes.hub || r.isFirst,
                    ),
                    onRestart: widget.args.mode == PlayMode.endless
                        ? null
                        : () => Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              settings: const RouteSettings(name: Routes.night),
                              builder: (_) => NightScreen(args: widget.args),
                            ),
                          ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Hud extends StatelessWidget {
  const _Hud({required this.sim, required this.onPause, required this.frame});
  final CoveSim sim;
  final VoidCallback? onPause;
  final ValueNotifier<int> frame;

  @override
  Widget build(BuildContext context) {
    final best = context.progress.longestBest;
    return Positioned(
      left: 0,
      right: 0,
      top: 0,
      child: ValueListenableBuilder<int>(
        valueListenable: frame,
        builder: (context, _, _) {
          final endless = sim.spec.endless;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // The dawn band: the sky lightening along the top edge.
              if (!endless)
                Semantics(
                  label: 'Dawn in ${sim.secondsLeft.ceil()} seconds',
                  child: SizedBox(
                    height: 4 + MediaQuery.paddingOf(context).top,
                    child: Align(
                      alignment: Alignment.bottomLeft,
                      child: FractionallySizedBox(
                        widthFactor: math.max(0.001, sim.dawnProgress),
                        child: Container(
                          height: 4,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFF7E5E58), CoveColors.harbor],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                )
              else
                SizedBox(height: MediaQuery.paddingOf(context).top),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  CoveSpacing.lg,
                  CoveSpacing.sm,
                  CoveSpacing.xs,
                  0,
                ),
                child: Row(
                  children: [
                    Semantics(
                      label: '${sim.embers} embers left',
                      child: ExcludeSemantics(
                        child: Row(
                          children: [
                            for (var i = 0; i < CoveSim.maxEmbers; i++)
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 400),
                                child: Glyph(
                                  i < sim.embers
                                      ? GlyphKind.ember
                                      : GlyphKind.emberOut,
                                  key: ValueKey(i < sim.embers),
                                  size: 24,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: Semantics(
                          label: endless
                              ? '${sim.souls} souls brought home'
                              : '${sim.souls} of ${sim.spec.quota} souls brought home',
                          child: ExcludeSemantics(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Glyph(
                                  GlyphKind.hull,
                                  size: 18,
                                  color: CoveColors.harbor,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  endless
                                      ? '${sim.souls}'
                                      : '${sim.souls} / ${sim.spec.quota}',
                                  style: CoveText.number(20),
                                ),
                                if (endless && best > 0) ...[
                                  const SizedBox(width: 10),
                                  Text('best $best', style: CoveText.caption()),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 72,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: onPause == null
                            ? null
                            : IconButton(
                                tooltip: 'Pause',
                                onPressed: onPause,
                                constraints: const BoxConstraints(
                                  minWidth: 48,
                                  minHeight: 48,
                                ),
                                icon: const Glyph(GlyphKind.pause, size: 24),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              if (!endless && sim.secondsLeft < 15 && !sim.over)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    'Dawn in ${sim.secondsLeft.ceil()}',
                    textAlign: TextAlign.center,
                    style: CoveText.caption().copyWith(
                      color: CoveColors.harbor,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro({
    required this.spec,
    required this.mode,
    required this.frame,
    required this.intro,
  });
  final NightSpec spec;
  final PlayMode mode;
  final ValueNotifier<int> frame;
  final double Function() intro;

  @override
  Widget build(BuildContext context) {
    final hold = spec.tutorial != null && mode == PlayMode.story ? 7.0 : 3.2;
    final kicker = switch (mode) {
      PlayMode.story => 'Night ${spec.id} · ${seasons[spec.season].name}',
      PlayMode.daily => 'Bring ${spec.quota} home before dawn',
      PlayMode.endless => 'No dawn tonight. Keep them coming home.',
    };
    return IgnorePointer(
      child: ValueListenableBuilder<int>(
        valueListenable: frame,
        builder: (context, _, child) {
          final t = intro();
          final a = t < 0.5
              ? t / 0.5
              : (t > hold ? (1 - (t - hold) / 0.8) : 1.0);
          if (a <= 0) return const SizedBox.shrink();
          return Opacity(opacity: a.clamp(0.0, 1.0), child: child);
        },
        child: Align(
          alignment: const Alignment(0, 0.3),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: CoveSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  spec.name,
                  textAlign: TextAlign.center,
                  style: CoveText.headline(),
                ),
                const SizedBox(height: CoveSpacing.sm),
                Text(
                  kicker,
                  textAlign: TextAlign.center,
                  style: CoveText.label().copyWith(color: CoveColors.textMuted),
                ),
                if (spec.tutorial != null && mode == PlayMode.story) ...[
                  const SizedBox(height: CoveSpacing.xl),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 340),
                    child: Text(
                      spec.tutorial!,
                      textAlign: TextAlign.center,
                      style: CoveText.body().copyWith(color: CoveColors.harbor),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CountIn extends StatelessWidget {
  const _CountIn({required this.frame, required this.left});
  final ValueNotifier<int> frame;
  final double Function() left;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: ValueListenableBuilder<int>(
          valueListenable: frame,
          builder: (context, _, _) {
            final l = left();
            final n = (l / 0.8).ceil().clamp(1, 3);
            final frac = (l % 0.8) / 0.8;
            return Opacity(
              opacity: frac.clamp(0.0, 1.0),
              child: Text(
                '$n',
                style: CoveText.display().copyWith(
                  color: CoveColors.harbor,
                  fontSize: 64,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// The Keeper's Rest: the scene dims to candlelight; the choices sit on the left.
class _KeepersRest extends StatelessWidget {
  const _KeepersRest({
    required this.onResume,
    required this.onDuty,
    required this.onLeave,
    this.onRestart,
  });
  final VoidCallback onResume;
  final VoidCallback onDuty;
  final VoidCallback onLeave;
  final VoidCallback? onRestart;

  @override
  Widget build(BuildContext context) {
    Widget choice(String label, VoidCallback onTap, {bool primary = false}) =>
        Semantics(
          button: true,
          label: label,
          child: ExcludeSemantics(
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () {
                Fx.play(Sfx.tap);
                Fx.lightTap();
                onTap();
              },
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 64),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: CoveSpacing.md,
                    horizontal: CoveSpacing.sm,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      label,
                      style: CoveText.headline().copyWith(
                        color: primary ? CoveColors.beam : CoveColors.text,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: CoveMotion.page,
      curve: CoveMotion.ease,
      builder: (context, a, child) => Opacity(opacity: a, child: child),
      child: Container(
        color: CoveColors.lift.withValues(alpha: 0.9),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(CoveSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(flex: 3),
                Semantics(
                  header: true,
                  child: Text(
                    "The Keeper's Rest",
                    style: CoveText.label().copyWith(
                      color: CoveColors.textMuted,
                    ),
                  ),
                ),
                const SizedBox(height: CoveSpacing.lg),
                choice('Relight the watch', onResume, primary: true),
                choice('Reread the duty', onDuty),
                if (onRestart != null)
                  choice('Begin the night again', onRestart!),
                choice('Return to the lighthouse', onLeave),
                const Spacer(flex: 2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Convenience for screens that start a night.
void startNight(BuildContext context, NightArgs args) {
  Navigator.of(context).push(
    MaterialPageRoute(
      settings: const RouteSettings(name: Routes.night),
      builder: (_) => NightScreen(args: args),
    ),
  );
}
