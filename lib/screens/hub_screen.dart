import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../app.dart';
import '../audio/fx.dart';
import '../data/catalog.dart';
import '../data/progress.dart';
import '../engine/modes.dart';
import '../engine/seasons.dart';
import '../game/art.dart';
import '../theme/cove_theme.dart';
import '../widgets/controls.dart';
import '../widgets/glyphs.dart';
import 'night_screen.dart';

/// Positions in the hub painting (fractions of 1080 x 1920), shared with
/// tool/make_art.py.
class HubSpots {
  HubSpots._();
  static const towerX = 0.70, towerTop = 0.165, towerWidth = 0.30;
  static const window = Offset(0.70, 0.244);
  static const chart = Offset(0.795, 0.305);
  static const logbook = Offset(0.509, 0.724);
  static const bell = Offset(0.425, 0.708);
  static const moon = Offset(0.2, 0.12);
  static const boathouse = Offset(0.148, 0.636);
  static const plaque = Offset(0.70, 0.735);
}

/// The Lighthouse at Rest: the whole menu is the painted cove.
class HubScreen extends StatefulWidget {
  const HubScreen({super.key});

  @override
  State<HubScreen> createState() => _HubScreenState();
}

class _HubScreenState extends State<HubScreen>
    with SingleTickerProviderStateMixin, RouteAware {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 24),
  )..repeat();

  @override
  void initState() {
    super.initState();
    Fx.music(Music.hub);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) routeObserver.subscribe(this, route);
  }

  @override
  void didPopNext() => Fx.music(Music.hub);

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _clock.dispose();
    super.dispose();
  }

  void _tend(Progress p) {
    if (p.yearComplete) {
      Navigator.of(context).pushNamed(Routes.chart, arguments: 3);
      return;
    }
    startNight(
      context,
      NightArgs(mode: PlayMode.story, spec: nightSpec(p.nextNight)),
    );
  }

  void _longest() {
    startNight(
      context,
      NightArgs(
        mode: PlayMode.endless,
        spec: endlessSpec,
        seed: DateTime.now().millisecondsSinceEpoch & 0xFFFFFF,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.progress;
    final reduce =
        p.reduceMotion ||
        (MediaQuery.maybeDisableAnimationsOf(context) ?? false);
    final next = nightSpec(p.nextNight);
    final season = seasons[next.season];

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, box) {
          final size = box.biggest;
          // The thumb zone at the bottom holds the primary action; the scene is
          // placed so every hotspot sits above it, whatever the phone's shape.
          final label = p.yearComplete ? 'Read the chart' : 'Tend the Light';
          final detail = p.yearComplete
              ? 'Every night of the year is kept'
              : 'Night ${next.id}, ${next.name} · ${season.name}';
          final thumb = _thumbHeight(context, size.width, label, detail);
          final img = _sceneRect(size, thumb);
          Offset at(Offset f) =>
              Offset(img.left + f.dx * img.width, img.top + f.dy * img.height);
          final paint = p.equippedGood(Shelf.paint).asset ?? 'rust';

          return Stack(
            children: [
              Positioned.fill(
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: _HubPainter(
                      image: img,
                      clock: _clock,
                      reduceMotion: reduce,
                      seasonsKept: p.seasonsKept,
                      nightsKept: p.nightsKept,
                      beam:
                          p.equippedGood(Shelf.beam).beamColor ??
                          CoveColors.beam,
                      towerPaint: paint,
                      keepsakes: p.shownKeepsakes,
                    ),
                  ),
                ),
              ),
              // Hotspots: the things in the scene, each with an engraved label.
              _Spot(
                at: at(HubSpots.moon),
                label: 'The Longest Night',
                labelSide: _Side.below,
                semantics:
                    'The moon. Play The Longest Night, an endless watch.',
                onTap: _longest,
                screen: size,
              ),
              _Spot(
                at: at(HubSpots.window),
                label: '',
                labelSide: _Side.left,
                radius: 34,
                semantics:
                    'The lamp room window. Tend the Light, night ${next.id}.',
                onTap: () => _tend(p),
                screen: size,
              ),
              _Spot(
                at: at(HubSpots.chart),
                label: 'Sea Chart',
                labelSide: _Side.below,
                semantics: 'The sea chart. Choose a night.',
                onTap: () => Navigator.of(context).pushNamed(Routes.chart),
                screen: size,
              ),
              _Spot(
                at: at(HubSpots.boathouse),
                label: 'Chandlery',
                labelSide: _Side.above,
                radius: 40,
                semantics: 'The boathouse. Chandlery, spend lamp oil.',
                onTap: () => Navigator.of(context).pushNamed(Routes.shop),
                screen: size,
              ),
              _Spot(
                at: at(HubSpots.bell),
                label: p.dailyDone(DateTime.now())
                    ? 'Daily Tide, rung'
                    : 'Daily Tide',
                labelSide: _Side.left,
                semantics: "The tide bell. Today's Daily Tide.",
                onTap: () => Navigator.of(context).pushNamed(Routes.daily),
                screen: size,
                quiet: p.dailyDone(DateTime.now()),
              ),
              _Spot(
                at: at(HubSpots.logbook),
                label: "Keeper's Log",
                labelSide: _Side.above,
                semantics:
                    "The logbook in the cottage window. The Keeper's Log.",
                onTap: () => Navigator.of(context).pushNamed(Routes.log),
                screen: size,
              ),
              _Spot(
                at: at(HubSpots.plaque),
                label: 'Settings',
                labelSide: _Side.right,
                semantics: 'The brass plaque. Settings, help and privacy.',
                onTap: () => Navigator.of(context).pushNamed(Routes.settings),
                screen: size,
              ),
              // Lamp oil, top right.
              Positioned(
                top: MediaQuery.paddingOf(context).top + CoveSpacing.md,
                right: CoveSpacing.hubMargin,
                child: OilAmount(p.oil, size: 18),
              ),
              // The thumb zone: the one primary action.
              Positioned(
                left: CoveSpacing.hubMargin,
                right: CoveSpacing.hubMargin,
                bottom: MediaQuery.paddingOf(context).bottom + CoveSpacing.lg,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: BeamAction(
                        label: label,
                        large: true,
                        detail: detail,
                        onTap: () => _tend(p),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: CoveSpacing.md),
                      child: Semantics(
                        label: '${p.totalLanterns} lanterns earned',
                        child: ExcludeSemantics(
                          child: Row(
                            children: [
                              const Glyph(GlyphKind.lantern, size: 18),
                              const SizedBox(width: 4),
                              Text(
                                '${p.totalLanterns}',
                                style: CoveText.hud().copyWith(
                                  color: CoveColors.harbor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Height of the bottom thumb zone, measured with the real text so a
  /// wrapped detail line or large system text never covers the scene.
  double _thumbHeight(
    BuildContext context,
    double width,
    String label,
    String detail,
  ) {
    final scaler = MediaQuery.textScalerOf(context);
    final textWidth = width - CoveSpacing.hubMargin * 2 - 64;
    TextPainter measure(String text, TextStyle style) => TextPainter(
      text: TextSpan(text: text, style: style),
      textScaler: scaler,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: textWidth);
    final head = measure(label, CoveText.headline()).height;
    final sub = measure(detail, CoveText.label()).height;
    return head +
        sub +
        6 +
        2 +
        8 +
        16 +
        CoveSpacing.lg +
        CoveSpacing.md +
        MediaQuery.paddingOf(context).bottom;
  }

  /// Where the painting goes: it covers the screen, and its lowest hotspot
  /// line ([_sceneBottom] of its height) lands above the thumb zone.
  static const _sceneBottom = 0.8;

  Rect _sceneRect(Size size, double thumb) {
    const iw = 1080.0, ih = 1920.0;
    final room = size.height - thumb;
    final s = math.max(
      size.width / iw,
      math.max(size.height / ih, room / (ih * _sceneBottom)),
    );
    final w = iw * s, h = ih * s;
    // Put the scene's bottom line at the top of the thumb zone, but never
    // leave a gap above the sky.
    final top = math.min(0.0, room - h * _sceneBottom);
    return Rect.fromLTWH((size.width - w) / 2, top, w, h);
  }
}

enum _Side { left, right, above, below }

class _Spot extends StatefulWidget {
  const _Spot({
    required this.at,
    required this.label,
    required this.labelSide,
    required this.semantics,
    required this.onTap,
    required this.screen,
    this.radius = 30,
    this.quiet = false,
  });

  final Offset at;
  final String label;
  final _Side labelSide;
  final String semantics;
  final VoidCallback onTap;
  final Size screen;
  final double radius;
  final bool quiet;

  @override
  State<_Spot> createState() => _SpotState();
}

class _SpotState extends State<_Spot> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final r = math.max(widget.radius, 26.0);
    final labelStyle = CoveText.label().copyWith(
      color: _down
          ? CoveColors.beam
          : (widget.quiet ? CoveColors.textMuted : CoveColors.text),
      shadows: const [
        Shadow(color: Color(0xCC0B1626), blurRadius: 8, offset: Offset(0, 1)),
      ],
    );
    final tp = TextPainter(
      text: TextSpan(text: widget.label, style: labelStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    final lw = tp.width, lh = tp.height;
    final c = widget.at;
    var lx = switch (widget.labelSide) {
      _Side.left => c.dx - r - 6 - lw,
      _Side.right => c.dx + r + 6,
      _ => c.dx - lw / 2,
    };
    var ly = switch (widget.labelSide) {
      _Side.above => c.dy - r - lh - 2,
      _Side.below => c.dy + r + 2,
      _ => c.dy - lh / 2,
    };
    lx = lx.clamp(CoveSpacing.lg, widget.screen.width - CoveSpacing.lg - lw);
    ly = ly.clamp(
      MediaQuery.paddingOf(context).top + CoveSpacing.sm,
      widget.screen.height - lh,
    );

    void tap() {
      Fx.play(Sfx.tap);
      Fx.lightTap();
      widget.onTap();
    }

    return Positioned.fill(
      child: Stack(
        children: [
          Positioned(
            left: c.dx - r,
            top: c.dy - r,
            width: r * 2,
            height: r * 2,
            child: Semantics(
              button: true,
              label: widget.semantics,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (_) => setState(() => _down = true),
                onTapCancel: () => setState(() => _down = false),
                onTapUp: (_) {
                  setState(() => _down = false);
                  tap();
                },
                child: AnimatedOpacity(
                  duration: CoveMotion.quick,
                  opacity: _down ? 1 : 0,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          CoveColors.beam.withValues(alpha: 0.35),
                          CoveColors.beam.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (widget.label.isNotEmpty)
            Positioned(
              left: lx,
              top: ly,
              child: ExcludeSemantics(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: tap,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(widget.label, style: labelStyle),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _HubPainter extends CustomPainter {
  _HubPainter({
    required this.image,
    required this.clock,
    required this.reduceMotion,
    required this.seasonsKept,
    required this.nightsKept,
    required this.beam,
    required this.towerPaint,
    required this.keepsakes,
  }) : super(repaint: clock);

  final Rect image;
  final Animation<double> clock;
  final bool reduceMotion;
  final int seasonsKept;
  final int nightsKept;
  final Color beam;
  final String towerPaint;
  final Set<String> keepsakes;

  Offset _at(double fx, double fy) =>
      Offset(image.left + fx * image.width, image.top + fy * image.height);
  double get _u => image.width / 1080; // image pixels to screen

  @override
  void paint(Canvas canvas, Size size) {
    final t = clock.value * 24; // seconds
    // Deep water under everything, matching the painting's foreground, for
    // screens where the painting ends above the bottom edge.
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF08101C),
    );
    final hub = Art.img('hub');
    if (hub != null) {
      canvas.drawImageRect(
        hub,
        Rect.fromLTWH(0, 0, hub.width.toDouble(), hub.height.toDouble()),
        image,
        Paint()..filterQuality = FilterQuality.medium,
      );
    } else {
      canvas.drawRect(Offset.zero & size, Paint()..color = CoveColors.sea);
    }

    _turningBeam(canvas, size, t);
    _village(canvas, t);
    _moored(canvas, t);
    _tower(canvas);
    _chart(canvas);
    _plaque(canvas);
    _keepsakes(canvas, t);
    _thumbShade(canvas, size);
  }

  /// The lighthouse's own light turning slowly over the sky.
  void _turningBeam(Canvas canvas, Size size, double t) {
    final o = _at(HubSpots.window.dx, HubSpots.window.dy);
    final angle = reduceMotion ? math.pi * 1.15 : t / 24 * 2 * math.pi;
    final reach = size.longestSide * 1.3;
    for (final a in [angle, angle + math.pi]) {
      // Only draw while the beam sweeps the sky side (not into the sea).
      final up = -math.sin(a);
      if (up < -0.15) continue;
      final fade = ((up + 0.15) / 0.6).clamp(0.0, 1.0);
      const h = 0.07;
      final path = Path()
        ..moveTo(o.dx, o.dy)
        ..lineTo(o.dx + math.cos(a - h) * reach, o.dy - math.sin(a - h) * reach)
        ..lineTo(o.dx + math.cos(a + h) * reach, o.dy - math.sin(a + h) * reach)
        ..close();
      canvas.drawPath(
        path,
        Paint()
          ..shader = ui.Gradient.radial(o, reach * 0.8, [
            beam.withValues(alpha: 0.22 * fade),
            beam.withValues(alpha: 0),
          ]),
      );
    }
    canvas.drawCircle(
      o,
      46 * _u,
      Paint()
        ..color = beam.withValues(alpha: 0.35)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 24 * _u),
    );
  }

  /// Village windows across the cove: more are lit with every kept season.
  void _village(Canvas canvas, double t) {
    final lit = 3 + seasonsKept * 3;
    final r = math.Random(4);
    for (var k = 0; k < 14; k++) {
      final on = k < lit;
      final fx = 0.02 + k * 0.032 + 0.011 + r.nextDouble() * 0.005;
      final fy = (1123 - 40 + k * 2.2 - 6) / 1920;
      if (!on) continue;
      final flicker = reduceMotion
          ? 1.0
          : 0.85 + 0.15 * math.sin(t * (0.8 + k * 0.13) + k);
      final c = _at(fx, fy);
      canvas.drawRect(
        Rect.fromCenter(center: c, width: 5 * _u, height: 6 * _u),
        Paint()..color = CoveColors.harbor.withValues(alpha: flicker),
      );
      canvas.drawCircle(
        c,
        10 * _u,
        Paint()
          ..color = CoveColors.beam.withValues(alpha: 0.25 * flicker)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8 * _u),
      );
      // Its reflection, broken on the water.
      final rc = _at(fx, 0.6 + k * 0.0015);
      canvas.drawRect(
        Rect.fromCenter(center: rc, width: 7 * _u, height: 1.6 * _u),
        Paint()..color = CoveColors.harbor.withValues(alpha: 0.35 * flicker),
      );
    }
  }

  /// Boats you have brought home ride at anchor by the jetty.
  void _moored(Canvas canvas, double t) {
    final n = math.min(nightsKept, 8);
    for (var i = 0; i < n; i++) {
      final fx = 0.08 + (i % 4) * 0.075 + (i ~/ 4) * 0.035;
      final fy = 0.775 + (i ~/ 4) * 0.045 + (i % 2) * 0.008;
      final bob = reduceMotion
          ? 0.0
          : math.sin(t * 2 * math.pi / CoveMotion.swellSeconds + i) * 2 * _u;
      final c = _at(fx, fy) + Offset(0, bob);
      final w = 46 * _u;
      canvas.drawPath(
        Path()
          ..moveTo(c.dx - w / 2, c.dy)
          ..lineTo(c.dx + w / 2, c.dy)
          ..lineTo(c.dx + w * 0.38, c.dy + 8 * _u)
          ..lineTo(c.dx - w * 0.38, c.dy + 8 * _u)
          ..close(),
        Paint()..color = const Color(0xFF26313F),
      );
      canvas.drawLine(
        c,
        c - Offset(0, 34 * _u),
        Paint()
          ..color = const Color(0xFF4A5868)
          ..strokeWidth = 2 * _u,
      );
      canvas.drawCircle(
        c - Offset(0, 36 * _u),
        2.6 * _u,
        Paint()..color = CoveColors.harbor,
      );
      canvas.drawCircle(
        c - Offset(0, 36 * _u),
        8 * _u,
        Paint()
          ..color = CoveColors.beam.withValues(alpha: 0.3)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 6 * _u),
      );
    }
  }

  void _tower(Canvas canvas) {
    final img = Art.img('tower_$towerPaint') ?? Art.img('tower_rust');
    if (img == null) return;
    final w = HubSpots.towerWidth * image.width;
    final h = w * img.height / img.width;
    final dst = Rect.fromLTWH(
      image.left + HubSpots.towerX * image.width - w / 2,
      image.top + HubSpots.towerTop * image.height,
      w,
      h,
    );
    canvas.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
      dst,
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  /// A rolled sea chart hanging from the gallery rail.
  void _chart(Canvas canvas) {
    final c = _at(HubSpots.chart.dx, HubSpots.chart.dy);
    final w = 22 * _u, h = 58 * _u;
    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(center: c, width: w, height: h),
      Radius.circular(w / 2),
    );
    canvas.drawRRect(body, Paint()..color = const Color(0xFF9FB2C2));
    canvas.drawRRect(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5 * _u
        ..color = const Color(0xFF4A5E72),
    );
    canvas.drawLine(
      c - Offset(w / 2, h * 0.15),
      c + Offset(w / 2, -h * 0.15),
      Paint()
        ..color = const Color(0xFF4A5E72)
        ..strokeWidth = 2 * _u,
    );
    canvas.drawLine(
      c - Offset(0, h / 2),
      c - Offset(0, h / 2 + 12 * _u),
      Paint()
        ..color = const Color(0xFF4A5E72)
        ..strokeWidth = 2 * _u,
    );
  }

  void _plaque(Canvas canvas) {
    final c = _at(HubSpots.plaque.dx, HubSpots.plaque.dy);
    final r = RRect.fromRectAndRadius(
      Rect.fromCenter(center: c, width: 54 * _u, height: 30 * _u),
      Radius.circular(5 * _u),
    );
    canvas.drawRRect(r, Paint()..color = const Color(0xFFB08A52));
    canvas.drawRRect(
      r.deflate(4 * _u),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4 * _u
        ..color = const Color(0xFF6E5432),
    );
  }

  void _keepsakes(Canvas canvas, double t) {
    void put(String id, String asset, double fx, double fy, double width) {
      if (!keepsakes.contains(id)) return;
      final img = Art.img('keepsake_$asset');
      if (img == null) return;
      final w = width * image.width;
      final h = w * img.height / img.width;
      final c = _at(fx, fy);
      canvas.drawImageRect(
        img,
        Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
        Rect.fromCenter(center: c, width: w, height: h),
        Paint()..filterQuality = FilterQuality.medium,
      );
    }

    put('keep_vane', 'vane', 0.70, 0.168, 0.09);
    put('keep_telescope', 'telescope', 0.615, 0.272, 0.075);
    put('keep_bunting', 'bunting', 0.555, 0.672, 0.17);
    put('keep_garden', 'garden', 0.575, 0.752, 0.08);
    put('keep_cat', 'cat', 0.6, 0.758, 0.055);
  }

  /// A soft shade behind the bottom thumb zone so the primary action reads.
  void _thumbShade(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(
      0,
      size.height * 0.78,
      size.width,
      size.height * 0.22,
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            CoveColors.sea.withValues(alpha: 0),
            CoveColors.sea.withValues(alpha: 0.85),
          ],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_HubPainter old) =>
      old.image != image ||
      old.seasonsKept != seasonsKept ||
      old.nightsKept != nightsKept ||
      old.beam != beam ||
      old.towerPaint != towerPaint ||
      old.keepsakes.length != keepsakes.length ||
      old.reduceMotion != reduceMotion;
}
