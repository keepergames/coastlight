import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app.dart';
import '../audio/fx.dart';
import '../data/progress.dart';
import '../engine/night_spec.dart';
import '../engine/seasons.dart';
import '../theme/cove_theme.dart';
import '../widgets/controls.dart';
import '../widgets/glyphs.dart';
import 'night_screen.dart';

const _ink = Color(0xFF9FB4C6);
const _paper = Color(0xFF10223A);

/// The Sea Chart: the year as a chart of the coast, read by lamplight.
class ChartScreen extends StatefulWidget {
  const ChartScreen({super.key, this.initialSeason});
  final int? initialSeason;

  @override
  State<ChartScreen> createState() => _ChartScreenState();
}

class _ChartScreenState extends State<ChartScreen> {
  final _keys = List.generate(seasons.length, (_) => GlobalKey());
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final p = context.progress;
      final s = widget.initialSeason ?? seasonOf(p.nextNight).index;
      if (s == 0) return;
      final ctx = _keys[s].currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 500),
          curve: CoveMotion.ease,
        );
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _open(Progress p, NightSpec n) {
    Fx.play(Sfx.page, volume: 0.6);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: CoveColors.lift,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _NightSheet(
        spec: n,
        lanterns: p.lanternsFor(n.id),
        kept: p.isKept(n.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.progress;
    return CovePage(
      title: 'Sea Chart',
      trailing: Padding(
        padding: const EdgeInsets.only(right: CoveSpacing.xs),
        child: Semantics(
          label: '${p.totalLanterns} of ${nightCount * 3} lanterns',
          child: ExcludeSemantics(
            child: Row(
              children: [
                const Glyph(GlyphKind.lantern, size: 18),
                const SizedBox(width: 4),
                Text(
                  '${p.totalLanterns} / ${nightCount * 3}',
                  style: CoveText.hud().copyWith(color: CoveColors.harbor),
                ),
              ],
            ),
          ),
        ),
      ),
      background: const ColoredBox(color: _paper),
      // Built all at once (52 nights is small) so the current season can be
      // scrolled into view on open.
      child: SingleChildScrollView(
        controller: _scroll,
        padding: EdgeInsets.fromLTRB(
          0,
          CoveSpacing.sm,
          0,
          MediaQuery.paddingOf(context).bottom + CoveSpacing.xxxl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final s in seasons)
              KeyedSubtree(
                key: _keys[s.index],
                child: _SeasonCove(
                  season: s,
                  progress: p,
                  onNight: (n) => _open(p, n),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SeasonCove extends StatelessWidget {
  const _SeasonCove({
    required this.season,
    required this.progress,
    required this.onNight,
  });
  final Season season;
  final Progress progress;
  final void Function(NightSpec) onNight;

  static const _row = 92.0;
  static const _cols = [0.22, 0.5, 0.78];

  @override
  Widget build(BuildContext context) {
    final open = progress.seasonOpen(season.index);
    final ids = season.nightIds.toList();
    final rows = (ids.length / 2).ceil();
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth;
        // Zig-zag: alternate along three columns so the line reads as a passage.
        Offset pos(int i) {
          final row = i ~/ 2 + (i.isOdd ? 0.5 : 0);
          const seq = [0, 1, 2, 1];
          return Offset(w * _cols[seq[i % 4]], 30 + row * _row);
        }

        final height = 60 + rows * _row;
        return Padding(
          padding: const EdgeInsets.only(top: CoveSpacing.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: CoveSpacing.xl),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Semantics(
                            header: true,
                            child: Text(
                              season.name,
                              style: CoveText.headline(),
                            ),
                          ),
                          const SizedBox(height: CoveSpacing.xs),
                          Text(
                            season.blurb,
                            style: CoveText.body().copyWith(
                              color: CoveColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: CoveSpacing.md),
                    Text(
                      '${progress.seasonKept(season.index)} / ${season.length}',
                      style: CoveText.hud(),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: height,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _ChartInk(
                          points: [for (var i = 0; i < ids.length; i++) pos(i)],
                          seed: season.index,
                        ),
                      ),
                    ),
                    for (var i = 0; i < ids.length; i++)
                      Positioned(
                        left: pos(i).dx - 36,
                        top: pos(i).dy - 26,
                        width: 72,
                        child: _Sounding(
                          spec: allNights[ids[i] - 1],
                          lanterns: progress.lanternsFor(ids[i]),
                          kept: progress.isKept(ids[i]),
                          open: progress.isUnlocked(ids[i]),
                          next:
                              ids[i] == progress.nextNight &&
                              !progress.yearComplete,
                          onTap: () => onNight(allNights[ids[i] - 1]),
                        ),
                      ),
                    if (!open)
                      Positioned.fill(
                        child: _FogOver(
                          text:
                              'Keep ${allNights[season.first - 2].name} to sail here.',
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Sounding extends StatelessWidget {
  const _Sounding({
    required this.spec,
    required this.lanterns,
    required this.kept,
    required this.open,
    required this.next,
    required this.onTap,
  });

  final NightSpec spec;
  final int lanterns;
  final bool kept;
  final bool open;
  final bool next;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ring = next
        ? CoveColors.beam
        : (kept ? CoveColors.harbor : (open ? _ink : CoveColors.textMuted));
    final state = kept
        ? 'kept, $lanterns of 3 lanterns'
        : (open ? (next ? 'next night' : 'open') : 'not reached');
    return Semantics(
      button: open,
      enabled: open,
      label:
          'Night ${spec.id}, ${spec.name}${spec.finale ? ', finale' : ''}, $state',
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: open ? onTap : null,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: kept
                      ? CoveColors.harbor.withValues(alpha: 0.14)
                      : _paper,
                  border: Border.all(
                    color: ring,
                    width: next || spec.finale ? 2.4 : 1.4,
                  ),
                  boxShadow: next
                      ? [
                          BoxShadow(
                            color: CoveColors.beam.withValues(alpha: 0.45),
                            blurRadius: 18,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  '${spec.id}',
                  style: CoveText.number(18).copyWith(
                    color: open ? CoveColors.text : CoveColors.textMuted,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              if (kept)
                LanternRow(lanterns, size: 14)
              else
                const SizedBox(height: 14),
            ],
          ),
        ),
      ),
    );
  }
}

class _FogOver extends StatelessWidget {
  const _FogOver({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF8DA0B3).withValues(alpha: 0.0),
            const Color(0xFF55687C).withValues(alpha: 0.82),
            const Color(0xFF55687C).withValues(alpha: 0.9),
          ],
          stops: const [0, 0.12, 1],
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(CoveSpacing.xl),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Glyph(GlyphKind.lock, size: 20),
              const SizedBox(width: CoveSpacing.sm),
              Flexible(
                child: Text(
                  text,
                  textAlign: TextAlign.center,
                  style: CoveText.body(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Chart furniture: the dashed sailing line, depth soundings and coastline.
class _ChartInk extends CustomPainter {
  _ChartInk({required this.points, required this.seed});
  final List<Offset> points;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final r = math.Random(seed * 13 + 1);
    // Coast along the left edge, with contour lines offshore.
    for (var k = 0; k < 3; k++) {
      final path = Path()..moveTo(0, 0);
      var x = 18.0 + k * 14;
      for (var y = 0.0; y <= size.height; y += 24) {
        x = (x + (r.nextDouble() - 0.5) * 10).clamp(
          8.0 + k * 14,
          34.0 + k * 14,
        );
        path.lineTo(x, y);
      }
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = k == 0 ? 1.4 : 0.8
          ..color = _ink.withValues(alpha: k == 0 ? 0.5 : 0.22),
      );
    }
    // Depth soundings: small numbers scattered over open water.
    final style = CoveText.caption().copyWith(
      color: _ink.withValues(alpha: 0.28),
      fontSize: 10,
    );
    for (var i = 0; i < size.height / 40; i++) {
      final p = Offset(
        60 + r.nextDouble() * (size.width - 90),
        r.nextDouble() * size.height,
      );
      if (points.any((q) => (q - p).distance < 50)) continue;
      final tp = TextPainter(
        text: TextSpan(text: '${3 + r.nextInt(28)}', style: style),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, p);
    }
    // The sailing line, dashed, through every night.
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..color = _ink.withValues(alpha: 0.55);
    for (var i = 0; i + 1 < points.length; i++) {
      final a = points[i], b = points[i + 1];
      final d = (b - a).distance;
      final dir = (b - a) / d;
      for (var s = 30.0; s < d - 30; s += 12) {
        canvas.drawLine(a + dir * s, a + dir * math.min(s + 6, d - 30), line);
      }
    }
  }

  @override
  bool shouldRepaint(_ChartInk old) =>
      old.points.length != points.length || old.seed != seed;
}

class _NightSheet extends StatelessWidget {
  const _NightSheet({
    required this.spec,
    required this.lanterns,
    required this.kept,
  });
  final NightSpec spec;
  final int lanterns;
  final bool kept;

  @override
  Widget build(BuildContext context) {
    final season = seasons[spec.season];
    final lines = <String>[
      'Bring ${spec.quota} home before dawn.',
      if (spec.fogBanks > 0) 'Fog banks: ${spec.fogBanks}.',
      if (spec.convoyChance > 0 || spec.waves.any((w) => w.convoy > 0))
        'Convoys sail tonight.',
      if (spec.buoys.isNotEmpty) 'Bell buoys: ${spec.buoys.length}.',
    ];
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          CoveSpacing.xl,
          0,
          CoveSpacing.xl,
          CoveSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Night ${spec.id} · ${season.name}${spec.finale ? ' · finale' : ''}',
              style: CoveText.label().copyWith(color: CoveColors.textMuted),
            ),
            const SizedBox(height: CoveSpacing.xs),
            Text(spec.name, style: CoveText.headline()),
            const SizedBox(height: CoveSpacing.md),
            for (final l in lines) Text(l, style: CoveText.body()),
            if (kept) ...[
              const SizedBox(height: CoveSpacing.md),
              Row(
                children: [
                  LanternRow(lanterns, size: 20),
                  const SizedBox(width: CoveSpacing.sm),
                  Text(
                    lanterns == 3 ? 'Every lantern lit' : 'Best so far',
                    style: CoveText.caption(),
                  ),
                ],
              ),
            ],
            const SizedBox(height: CoveSpacing.lg),
            BeamAction(
              label: kept ? 'Keep this night again' : 'Tend this night',
              onTap: () {
                final nav = Navigator.of(context);
                nav.pop();
                nav.push(
                  MaterialPageRoute(
                    settings: const RouteSettings(name: Routes.night),
                    builder: (_) => NightScreen(
                      args: NightArgs(mode: PlayMode.story, spec: spec),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
