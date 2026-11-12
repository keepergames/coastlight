import 'dart:async';

import 'package:flutter/material.dart';

import '../app.dart';
import '../audio/fx.dart';
import '../data/progress.dart';
import '../engine/modes.dart';
import '../engine/seasons.dart';
import '../engine/sim.dart';
import '../game/art.dart';
import '../theme/cove_theme.dart';
import '../widgets/controls.dart';
import '../widgets/glyphs.dart';
import 'night_screen.dart';

/// Dawn, The Dark Watch, or the end of a Longest Night.
class ResultScreen extends StatefulWidget {
  const ResultScreen({
    super.key,
    required this.run,
    required this.reward,
    required this.args,
  });

  final RunSummary run;
  final Reward reward;
  final NightArgs args;

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sky = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..forward();
  int _litLanterns = 0;
  int _oilShown = 0;
  final List<Timer> _timers = [];

  RunSummary get run => widget.run;
  Reward get reward => widget.reward;
  bool get _warm => run.kept || run.mode == PlayMode.endless;

  @override
  void initState() {
    super.initState();
    if (run.mode == PlayMode.endless) {
      Fx.play(Sfx.dawn, volume: 0.7);
    } else {
      Fx.play(run.kept ? Sfx.dawn : Sfx.dark, volume: 0.8);
    }
    var at = 700;
    for (var i = 1; i <= run.lanterns; i++) {
      _timers.add(
        Timer(Duration(milliseconds: at), () {
          if (!mounted) return;
          setState(() => _litLanterns = i);
          Fx.play(Sfx.lantern, volume: 0.7);
          Fx.soft();
        }),
      );
      at += 260;
    }
    // Lamp oil counts up after the lanterns.
    final steps = 18;
    for (var i = 1; i <= steps; i++) {
      _timers.add(
        Timer(Duration(milliseconds: at + 200 + i * 40), () {
          if (mounted) {
            setState(() => _oilShown = (reward.oil * i / steps).round());
          }
        }),
      );
    }
    if (reward.newAchievements.isNotEmpty || reward.newSeason != null) {
      _timers.add(
        Timer(
          Duration(milliseconds: at + 1200),
          () => Fx.play(Sfx.unlock, volume: 0.7),
        ),
      );
    }
  }

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    _sky.dispose();
    super.dispose();
  }

  void _play(NightArgs args) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        settings: const RouteSettings(name: Routes.night),
        builder: (_) => NightScreen(args: args),
      ),
    );
  }

  void _home() => Navigator.of(
    context,
  ).popUntil((r) => r.settings.name == Routes.hub || r.isFirst);

  @override
  Widget build(BuildContext context) {
    final p = context.progress;
    final spec = run.spec;
    final (title, line) = switch ((run.mode, run.outcome)) {
      (PlayMode.endless, _) => (
        'First light',
        'The longest night is over. ${run.souls} ${run.souls == 1 ? 'soul' : 'souls'} came home.',
      ),
      (PlayMode.daily, NightOutcome.kept) => (
        'The tide is kept',
        'Every boat you needed came home today.',
      ),
      (_, NightOutcome.kept) => (
        'Dawn',
        '${run.souls} souls came home. The night is kept.',
      ),
      (_, NightOutcome.dark) => (
        'The Dark Watch',
        'The light went out after ${run.souls} ${run.souls == 1 ? 'soul' : 'souls'}.',
      ),
      (_, NightOutcome.dawnShort) => (
        'Dawn came early',
        '${run.souls} of ${spec.quota} were home when the sun rose.',
      ),
    };
    final subtitle = switch (run.mode) {
      PlayMode.story => 'Night ${spec.id} · ${spec.name}',
      PlayMode.daily => 'Daily Tide',
      PlayMode.endless => 'The Longest Night',
    };

    final actions = <Widget>[];
    var primaryGoesHome = false;
    if (run.mode == PlayMode.story) {
      final hasNext = spec.id < nightCount;
      if (run.kept && hasNext) {
        actions.add(
          BeamAction(
            label: 'Sail on',
            large: true,
            detail: 'Night ${spec.id + 1}, ${nightName(spec.id + 1)}',
            onTap: () => _play(
              NightArgs(mode: PlayMode.story, spec: nightSpec(spec.id + 1)),
            ),
          ),
        );
        actions.add(
          QuietAction(
            flush: true,
            label: 'Keep this night again',
            onTap: () => _play(widget.args),
          ),
        );
      } else if (run.kept) {
        primaryGoesHome = true;
        actions.add(
          BeamAction(
            label: 'Return to the lighthouse',
            large: true,
            onTap: _home,
          ),
        );
      } else {
        actions.add(
          BeamAction(
            label: 'Light it again',
            large: true,
            onTap: () => _play(widget.args),
          ),
        );
      }
    } else if (run.mode == PlayMode.daily) {
      if (run.kept) {
        primaryGoesHome = true;
        actions.add(
          BeamAction(
            label: 'Return to the lighthouse',
            large: true,
            onTap: _home,
          ),
        );
      } else {
        actions.add(
          BeamAction(
            label: 'Ring the bell again',
            large: true,
            onTap: () => _play(
              NightArgs(
                mode: PlayMode.daily,
                spec: dailySpec(
                  DateTime.now(),
                  furthestSeason: p.furthestSeason,
                ),
                day: run.day,
              ),
            ),
          ),
        );
      }
    } else {
      actions.add(
        BeamAction(
          label: 'Keep watch again',
          large: true,
          onTap: () => _play(
            NightArgs(
              mode: PlayMode.endless,
              spec: endlessSpec,
              seed: DateTime.now().millisecondsSinceEpoch & 0xFFFFFF,
            ),
          ),
        ),
      );
    }
    if (!primaryGoesHome) {
      actions.add(QuietAction(flush: true, label: 'Return to the lighthouse', onTap: _home));
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _home();
      },
      child: Scaffold(
        body: Stack(
          children: [
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _sky,
                builder: (context, _) => CustomPaint(
                  painter: _SkyPainter(
                    season: spec.season,
                    warmth: _warm
                        ? Curves.easeOutCubic.transform(_sky.value)
                        : 0,
                    dark: !_warm,
                  ),
                ),
              ),
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, box) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                      CoveSpacing.xl,
                      CoveSpacing.xxxl,
                      CoveSpacing.xl,
                      CoveSpacing.xl,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight:
                            box.maxHeight - CoveSpacing.xxxl - CoveSpacing.xl,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Semantics(
                                header: true,
                                child: Text(title, style: CoveText.display()),
                              ),
                              const SizedBox(height: CoveSpacing.sm),
                              Text(
                                subtitle,
                                style: CoveText.label().copyWith(
                                  color: CoveColors.textMuted,
                                ),
                              ),
                              const SizedBox(height: CoveSpacing.xl),
                              Text(line, style: CoveText.body()),
                              if (run.kept && run.mode != PlayMode.endless) ...[
                                const SizedBox(height: CoveSpacing.xl),
                                Semantics(
                                  label: '${run.lanterns} of 3 lanterns',
                                  child: ExcludeSemantics(
                                    child: Row(
                                      children: [
                                        for (var i = 1; i <= 3; i++)
                                          AnimatedScale(
                                            scale: i <= _litLanterns ? 1 : 0.86,
                                            duration: const Duration(
                                              milliseconds: 260,
                                            ),
                                            curve: Curves.easeOutBack,
                                            child: Glyph(
                                              i <= _litLanterns
                                                  ? GlyphKind.lantern
                                                  : GlyphKind.lanternEmpty,
                                              size: 44,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: CoveSpacing.sm),
                                Text(
                                  run.lanterns == 3
                                      ? 'Every ember still burning.'
                                      : '${3 - run.lanterns} ${3 - run.lanterns == 1 ? 'ember' : 'embers'} lost to the dark.',
                                  style: CoveText.caption(),
                                ),
                              ],
                              const SizedBox(height: CoveSpacing.xl),
                              _Facts(
                                run: run,
                                reward: reward,
                                oilShown: _oilShown,
                                best: p.longestBest,
                              ),
                              if (reward.newSeason != null) ...[
                                const SizedBox(height: CoveSpacing.xl),
                                Text(
                                  '${reward.newSeason!.name} is open',
                                  style: CoveText.title().copyWith(
                                    color: CoveColors.harbor,
                                  ),
                                ),
                                const SizedBox(height: CoveSpacing.xs),
                                Text(
                                  reward.newSeason!.blurb,
                                  style: CoveText.body().copyWith(
                                    color: CoveColors.textMuted,
                                  ),
                                ),
                              ],
                              for (final a in reward.newAchievements) ...[
                                const SizedBox(height: CoveSpacing.lg),
                                Row(
                                  children: [
                                    const Glyph(
                                      GlyphKind.check,
                                      size: 20,
                                      color: CoveColors.harbor,
                                    ),
                                    const SizedBox(width: CoveSpacing.sm),
                                    Expanded(
                                      child: Text.rich(
                                        TextSpan(
                                          children: [
                                            TextSpan(
                                              text: a.name,
                                              style: CoveText.label().copyWith(
                                                color: CoveColors.harbor,
                                              ),
                                            ),
                                            TextSpan(
                                              text: '  ${a.line}',
                                              style: CoveText.caption(),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                          Padding(
                            padding: const EdgeInsets.only(
                              top: CoveSpacing.xxl,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: actions,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Facts extends StatelessWidget {
  const _Facts({
    required this.run,
    required this.reward,
    required this.oilShown,
    required this.best,
  });
  final RunSummary run;
  final Reward reward;
  final int oilShown;
  final int best;

  @override
  Widget build(BuildContext context) {
    final facts = <(String, String)>[
      ('Souls home', '${run.souls}'),
      ('Longest run without a loss', '${run.bestStreak}'),
      if (run.mode == PlayMode.endless)
        ('Best Longest Night', reward.newBest ? '$best, a new best' : '$best'),
      if (run.convoysHome > 0) ('Whole convoys home', '${run.convoysHome}'),
      if (run.buoysKindled > 0) ('Buoys kindled', '${run.buoysKindled}'),
    ];
    return Column(
      children: [
        for (final (k, v) in facts)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    k,
                    style: CoveText.body().copyWith(
                      color: CoveColors.textMuted,
                    ),
                  ),
                ),
                Text(v, style: CoveText.hud()),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Lamp oil earned',
                  style: CoveText.body().copyWith(color: CoveColors.textMuted),
                ),
              ),
              OilAmount(oilShown, size: 16),
            ],
          ),
        ),
      ],
    );
  }
}

/// The sky behind the result: dawn warms up from the horizon; the dark watch
/// stays black with only the harbour glowing.
class _SkyPainter extends CustomPainter {
  _SkyPainter({required this.season, required this.warmth, required this.dark});
  final int season;
  final double warmth;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final img = Art.sea(season);
    if (img != null) {
      paintCover(
        canvas,
        img,
        rect,
        paint: Paint()..filterQuality = FilterQuality.medium,
      );
    }
    canvas.drawRect(
      rect,
      Paint()..color = CoveColors.sea.withValues(alpha: dark ? 0.82 : 0.6),
    );
    if (dark) {
      final glow = Rect.fromCircle(
        center: Offset(size.width * 0.12, size.height * 0.92),
        radius: size.width * 0.5,
      );
      canvas.drawRect(
        rect,
        Paint()
          ..shader = RadialGradient(
            colors: [
              CoveColors.harbor.withValues(alpha: 0.18),
              CoveColors.harbor.withValues(alpha: 0),
            ],
          ).createShader(glow),
      );
      return;
    }
    // Dawn light rising from the bottom edge.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            const Color(0xFFE8A878).withValues(alpha: 0.55 * warmth),
            const Color(0xFF8E6A72).withValues(alpha: 0.3 * warmth),
            CoveColors.sea.withValues(alpha: 0),
          ],
          stops: const [0, 0.35, 0.8],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_SkyPainter old) =>
      old.warmth != warmth || old.dark != dark || old.season != season;
}
