import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../engine/night_spec.dart';
import '../engine/sim.dart';
import '../engine/vec.dart';
import '../theme/cove_theme.dart';
import 'art.dart';

/// Maps the engine's 1000 x 1600 world onto the screen. The world fills the
/// width and sits on the bottom edge (the lamp is always under the thumb);
/// extra height on tall phones is open sea above.
class SeaView {
  SeaView(Size size)
      : scale = math.min(size.width / World.width, size.height / (World.height * 0.86)),
        screen = size {
    origin = Offset((size.width - World.width * scale) / 2, size.height - World.height * scale);
  }

  final double scale;
  final Size screen;
  late final Offset origin;

  Offset toScreen(Vec v) => Offset(origin.dx + v.x * scale, origin.dy + v.y * scale);
  Vec toWorld(Offset o) => Vec((o.dx - origin.dx) / scale, (o.dy - origin.dy) / scale);
  Rect worldRect(double x, double y, double w, double h) =>
      Rect.fromLTWH(origin.dx + x * scale, origin.dy + y * scale, w * scale, h * scale);
}

/// A spark of light (soul home, buoy kindled) or a puff of dark (lost).
class Particle {
  Particle(this.pos, this.vel, this.life, this.color, this.size);
  Vec pos;
  Vec vel;
  double life;
  final double maxLife = 1;
  final Color color;
  final double size;
}

/// Visual state the screen keeps alongside the simulation.
class NightVisuals {
  final List<Particle> particles = [];
  double shake = 0;
  double homeBloom = 0;
  double time = 0;

  void burst(Vec at, Color c, {int count = 18, double speed = 120, double size = 5}) {
    final r = math.Random(at.x.toInt() * 31 + at.y.toInt());
    for (var i = 0; i < count; i++) {
      final a = r.nextDouble() * math.pi * 2;
      final s = speed * (0.35 + r.nextDouble() * 0.65);
      particles.add(Particle(at, Vec.fromAngle(a, s) - const Vec(0, 30), 0.7 + r.nextDouble() * 0.6, c,
          size * (0.5 + r.nextDouble())));
    }
  }

  void update(double dt) {
    time += dt;
    for (final p in particles) {
      p.pos = p.pos + p.vel * dt;
      p.vel = p.vel * (1 - dt * 1.8);
      p.life -= dt;
    }
    particles.removeWhere((p) => p.life <= 0);
    shake = math.max(0, shake - dt * 3.2);
    homeBloom = math.max(0, homeBloom - dt * 1.4);
  }
}

class NightPainter extends CustomPainter {
  NightPainter({
    required this.sim,
    required this.fx,
    required this.beamColor,
    required this.livery,
    required this.reduceMotion,
    required Listenable repaint,
  }) : super(repaint: repaint);

  final CoveSim sim;
  final NightVisuals fx;
  final Color beamColor;
  final String livery;
  final bool reduceMotion;

  @override
  void paint(Canvas canvas, Size size) {
    final vp = SeaView(size);
    final t = fx.time;

    if (fx.shake > 0 && !reduceMotion) {
      final s = fx.shake * 8 * math.sin(t * 60);
      canvas.translate(s, 0);
    }

    _sea(canvas, size);
    _harbor(canvas, vp);
    _rocks(canvas, vp);
    for (final b in sim.buoys) {
      _buoy(canvas, vp, b, t);
    }
    // Homeward boats first so drifting boats (the ones that need you) sit on top.
    for (final v in sim.vessels.where((v) => v.state != VesselState.drifting)) {
      _vessel(canvas, vp, v, t);
    }
    for (final v in sim.vessels.where((v) => v.state == VesselState.drifting)) {
      _vessel(canvas, vp, v, t);
    }
    _fog(canvas, vp, t);
    // Rings stay readable above the fog, faint inside it.
    for (final v in sim.vessels) {
      _ring(canvas, vp, v);
    }
    _beam(canvas, vp, t);
    _lamp(canvas, vp, t);
    _particles(canvas, vp);
    _topShade(canvas, size);
  }

  // ------------------------------------------------------------------ sea ---
  void _sea(Canvas canvas, Size size) {
    final img = Art.sea(sim.spec.season);
    final rect = Offset.zero & size;
    if (img != null) {
      paintCover(canvas, img, rect, alignY: 1);
    } else {
      canvas.drawRect(
          rect,
          Paint()
            ..shader = const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF1C3350), CoveColors.sea],
            ).createShader(rect));
    }
    // Gentle moving glints so the water breathes even when nothing happens.
    if (!reduceMotion) {
      final glint = Paint()..color = const Color(0x18EAF1F8);
      final r = math.Random(7);
      for (var i = 0; i < 26; i++) {
        final x = r.nextDouble() * size.width;
        final y = size.height * (0.15 + r.nextDouble() * 0.7);
        final phase = math.sin(fx.time * (0.6 + r.nextDouble()) + i);
        if (phase < 0.6) continue;
        final w = 10 + 18 * (phase - 0.6);
        canvas.drawRRect(
            RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(x, y), width: w, height: 1.6),
                const Radius.circular(1)),
            glint);
      }
    }
  }

  void _topShade(Canvas canvas, Size size) {
    // Boats come out of the dark: a soft shade along the top edge.
    final rect = Rect.fromLTWH(0, 0, size.width, size.height * 0.16);
    canvas.drawRect(
        rect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [CoveColors.sea.withValues(alpha: 0.85), CoveColors.sea.withValues(alpha: 0)],
          ).createShader(rect));
  }

  // ------------------------------------------------------- shore & rocks ---
  void _harbor(Canvas canvas, SeaView vp) {
    final img = Art.img('harbor');
    final dst = vp.worldRect(-60, 1141, 300, 420);
    if (img != null) {
      canvas.drawImageRect(img, Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()), dst,
          Paint()..filterQuality = FilterQuality.medium);
    }
    if (fx.homeBloom > 0) {
      final c = vp.toScreen(const Vec(World.harborX, World.harborY));
      canvas.drawCircle(
          c,
          70 * vp.scale * (1.4 - fx.homeBloom * 0.4),
          Paint()
            ..color = CoveColors.harbor.withValues(alpha: 0.4 * fx.homeBloom)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, 30 * vp.scale + 4));
    }
  }

  void _rocks(Canvas canvas, SeaView vp) {
    final img = Art.img('rocks');
    final dst = vp.worldRect(CoveSim.rocksStartX - 30, World.hazardY - 110, 760, 170);
    if (img != null) {
      canvas.drawImageRect(img, Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()), dst,
          Paint()..filterQuality = FilterQuality.medium);
    } else {
      canvas.drawRect(dst, Paint()..color = const Color(0xFF1A222C));
    }
  }

  // ----------------------------------------------------------------- fog ---
  void _fog(Canvas canvas, SeaView vp, double t) {
    for (final f in sim.fog) {
      final c = vp.toScreen(f.pos);
      final r = f.radius * vp.scale;
      // Fog lies flat on the water: several wide, soft lobes that drift and
      // breathe, so a bank never reads as a disc or a spotlight.
      for (var k = 0; k < 5; k++) {
        final a = k * 1.3 + f.radius + (reduceMotion ? 0 : t * 0.12);
        final o = Offset(math.cos(a) * r * 0.5, math.sin(a * 1.7) * r * 0.22);
        final lobe = Rect.fromCenter(center: c + o, width: r * (1.9 - k * 0.12), height: r * (0.95 - k * 0.06));
        canvas.drawOval(
            lobe,
            Paint()
              ..shader = RadialGradient(colors: [
                const Color(0xFFA9B8C7).withValues(alpha: 0.2),
                const Color(0xFF8DA0B3).withValues(alpha: 0.1),
                const Color(0x008DA0B3),
              ], stops: const [0, 0.6, 1]).createShader(lobe));
      }
    }
  }

  // ---------------------------------------------------------------- buoys ---
  void _buoy(Canvas canvas, SeaView vp, Buoy b, double t) {
    final c = vp.toScreen(b.pos);
    if (b.lit) {
      final r = CoveSim.buoyRadius * vp.scale;
      final fade = math.min(1.0, b.active / 2);
      final pulse = reduceMotion ? 1.0 : 0.92 + 0.08 * math.sin(t * 2.4);
      final halo = Rect.fromCircle(center: c, radius: r * pulse);
      canvas.drawCircle(
          c,
          r * pulse,
          Paint()
            ..shader = RadialGradient(colors: [
              beamColor.withValues(alpha: 0.26 * fade),
              beamColor.withValues(alpha: 0.1 * fade),
              beamColor.withValues(alpha: 0),
            ], stops: const [0, 0.7, 1]).createShader(halo));
      // The halo's edge, so its reach is readable without colour.
      canvas.drawCircle(
          c,
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2
            ..color = beamColor.withValues(alpha: 0.35 * fade));
      // Time left: an arc around the buoy.
      final arc = Rect.fromCircle(center: c, radius: 26 * vp.scale + 6);
      canvas.drawArc(
          arc,
          -math.pi / 2,
          2 * math.pi * (b.active / CoveSim.buoyDuration),
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5
            ..strokeCap = StrokeCap.round
            ..color = CoveColors.harbor.withValues(alpha: 0.8));
    } else if (b.kindle > 0) {
      final arc = Rect.fromCircle(center: c, radius: 26 * vp.scale + 6);
      canvas.drawArc(
          arc,
          -math.pi / 2,
          2 * math.pi * b.kindle,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..strokeCap = StrokeCap.round
            ..color = beamColor);
    }
    final img = Art.img(b.lit ? 'buoy_lit' : 'buoy_dark');
    final size = 92 * vp.scale;
    final bob = reduceMotion ? 0.0 : math.sin(t * 2 + b.pos.x) * 2;
    if (img != null) {
      final dst = Rect.fromCenter(center: c + Offset(0, -size * 0.18 + bob), width: size, height: size);
      canvas.drawImageRect(img, Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()), dst,
          Paint()..filterQuality = FilterQuality.medium);
    } else {
      canvas.drawCircle(c, 10 * vp.scale + 3, Paint()..color = b.lit ? beamColor : CoveColors.danger);
    }
  }

  // -------------------------------------------------------------- vessels ---
  void _vessel(Canvas canvas, SeaView vp, Vessel v, double t) {
    final c = vp.toScreen(v.pos);
    double alpha = 1;
    double sink = 0;
    if (v.state == VesselState.lost) {
      alpha = (1 - v.resolvedFor / 1.2).clamp(0.0, 1.0);
      sink = v.resolvedFor * 12;
    } else if (v.state == VesselState.home) {
      alpha = (1 - v.resolvedFor / 0.8).clamp(0.0, 1.0);
    }
    if (alpha <= 0) return;
    if (v.inFog && v.state == VesselState.drifting) alpha *= 0.4;

    final size = (v.isLead ? 176.0 : (v.isFollower ? 134.0 : 154.0)) * vp.scale;
    final sway = reduceMotion ? 0.0 : math.sin(t * 2 * math.pi / CoveMotion.swellSeconds + v.phase) * 0.08;

    // Wake: a short fading line behind the boat.
    if (v.active && v.vel.length2 > 1) {
      final back = v.vel.normalized() * -38;
      final p2 = vp.toScreen(v.pos + back);
      canvas.drawLine(
          c,
          p2,
          Paint()
            ..strokeWidth = 3 * vp.scale + 1
            ..strokeCap = StrokeCap.round
            ..shader = ui.Gradient.linear(c, p2, [
              const Color(0xFFDCE6F0).withValues(alpha: 0.35 * alpha),
              const Color(0x00DCE6F0),
            ]));
    }

    final warm = v.lit || v.state == VesselState.homeward || v.state == VesselState.home;
    if (warm) {
      canvas.drawCircle(
          c,
          size * 0.62,
          Paint()
            ..color = beamColor.withValues(alpha: 0.32 * alpha)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, size * 0.3));
    }

    canvas.save();
    canvas.translate(c.dx, c.dy + sink);
    canvas.rotate(sway);
    if (v.vel.x < -4) canvas.scale(-1, 1);
    final img = Art.boat(livery, v.isLead ? 3 : v.style);
    final paint = Paint()
      ..filterQuality = FilterQuality.medium
      ..color = Color.fromRGBO(255, 255, 255, alpha);
    if (warm) {
      paint.colorFilter = ColorFilter.mode(beamColor.withValues(alpha: 0.28), BlendMode.srcATop);
    } else if (v.state == VesselState.lost) {
      paint.colorFilter = ColorFilter.mode(CoveColors.sea.withValues(alpha: 0.5), BlendMode.srcATop);
    }
    if (img != null) {
      final dst = Rect.fromCenter(center: Offset(0, -size * 0.18), width: size, height: size);
      canvas.drawImageRect(img, Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()), dst, paint);
    } else {
      canvas.drawPath(
          Path()
            ..moveTo(0, -size * 0.3)
            ..lineTo(size * 0.3, size * 0.15)
            ..lineTo(-size * 0.3, size * 0.15)
            ..close(),
          Paint()..color = (warm ? CoveColors.harbor : CoveColors.textMuted).withValues(alpha: alpha));
    }
    canvas.restore();

    // Inside fog the boat's own lantern still glimmers, so it can be found.
    if (v.inFog && v.state == VesselState.drifting) {
      final g = reduceMotion ? 0.7 : 0.5 + 0.5 * math.sin(t * 3 + v.phase);
      canvas.drawCircle(
          c + Offset(0, -size * 0.25),
          3.5 + 2 * g,
          Paint()
            ..color = CoveColors.harbor.withValues(alpha: 0.5 + 0.4 * g)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
    }
  }

  void _ring(Canvas canvas, SeaView vp, Vessel v) {
    if (v.state != VesselState.drifting || v.isFollower) return;
    final c = vp.toScreen(v.pos) - Offset(0, 26 * vp.scale);
    final r = (v.isLead ? 64.0 : 56.0) * vp.scale + 4;
    final dim = v.inFog ? 0.55 : 1.0;
    // The track: a dotted circle so an empty ring still reads as "to fill".
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = CoveColors.text.withValues(alpha: 0.28 * dim);
    const dots = 24;
    for (var i = 0; i < dots; i += 2) {
      canvas.drawArc(Rect.fromCircle(center: c, radius: r), i / dots * 2 * math.pi, math.pi / dots, false, track);
    }
    if (v.chart > 0) {
      canvas.drawArc(
          Rect.fromCircle(center: c, radius: r),
          -math.pi / 2,
          2 * math.pi * v.chart,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3.4
            ..strokeCap = StrokeCap.round
            ..color = (v.lit ? beamColor : beamColor.withValues(alpha: 0.6)).withValues(alpha: dim));
      if (v.lit && !reduceMotion) {
        // A bright bead running at the head of the ring.
        final a = -math.pi / 2 + 2 * math.pi * v.chart;
        canvas.drawCircle(
            c + Offset(math.cos(a) * r, math.sin(a) * r),
            3.2,
            Paint()
              ..color = CoveColors.harbor
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
      }
    }
    // Convoy leads show how many boats follow them.
    if (v.isLead) {
      final tp = TextPainter(
        text: TextSpan(
            text: '+${v.followers}',
            style: CoveText.caption().copyWith(color: CoveColors.harbor, fontWeight: FontWeight.w600)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, c + Offset(r * 0.72, -r * 0.95));
    }
  }

  // ----------------------------------------------------------------- beam ---
  void _beam(Canvas canvas, SeaView vp, double t) {
    final o = vp.toScreen(sim.lamp);
    final reach = sim.reach * vp.scale;
    final a = sim.beamAngle;
    const h = CoveSim.halfAngle;
    final cone = Path()
      ..moveTo(o.dx, o.dy)
      ..lineTo(o.dx + math.cos(a - h) * reach, o.dy + math.sin(a - h) * reach)
      ..arcTo(Rect.fromCircle(center: o, radius: reach), a - h, 2 * h, false)
      ..close();

    canvas.drawPath(
        cone,
        Paint()
          ..color = beamColor.withValues(alpha: 0.12)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18));
    final flicker = reduceMotion ? 1.0 : 0.96 + 0.04 * math.sin(t * 9.3) * math.sin(t * 3.1);
    canvas.drawPath(
        cone,
        Paint()
          ..shader = ui.Gradient.radial(o, reach, [
            beamColor.withValues(alpha: 0.42 * flicker),
            beamColor.withValues(alpha: 0.16),
            beamColor.withValues(alpha: 0),
          ], [0, 0.6, 1]));
    // A bright core line down the middle of the beam.
    final tip = o + Offset(math.cos(a), math.sin(a)) * reach * 0.9;
    canvas.drawLine(
        o,
        tip,
        Paint()
          ..strokeWidth = 2
          ..shader = ui.Gradient.linear(o, tip, [
            CoveColors.harbor.withValues(alpha: 0.5),
            CoveColors.harbor.withValues(alpha: 0),
          ]));
  }

  void _lamp(Canvas canvas, SeaView vp, double t) {
    final img = Art.img('lamp_gallery');
    final dst = vp.worldRect(World.lampX - 150, World.lampY - 105, 300, 220);
    if (img != null) {
      canvas.drawImageRect(img, Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()), dst,
          Paint()..filterQuality = FilterQuality.medium);
    }
    final o = vp.toScreen(sim.lamp);
    final pulse = reduceMotion ? 1.0 : 0.9 + 0.1 * math.sin(t * 1.7);
    canvas.drawCircle(
        o,
        34 * vp.scale + 8,
        Paint()
          ..color = beamColor.withValues(alpha: 0.55 * pulse)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 16 * vp.scale + 6));
    canvas.drawCircle(o, 12 * vp.scale + 3, Paint()..color = CoveColors.harbor);
  }

  void _particles(Canvas canvas, SeaView vp) {
    for (final p in fx.particles) {
      final a = (p.life / p.maxLife).clamp(0.0, 1.0);
      canvas.drawCircle(
          vp.toScreen(p.pos),
          p.size * vp.scale + 1,
          Paint()
            ..color = p.color.withValues(alpha: a)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5));
    }
  }

  @override
  bool shouldRepaint(NightPainter old) => true;
}
