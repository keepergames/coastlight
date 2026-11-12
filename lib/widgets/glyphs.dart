import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/cove_theme.dart';

/// Icons drawn in the world's own grammar: one 1.6 px stroke weight, filled
/// light where something glows. No emoji, no stock icon set.
enum GlyphKind { ember, emberOut, lantern, lanternEmpty, oil, hull, back, pause, bell, moon, check, lock }

class Glyph extends StatelessWidget {
  const Glyph(this.kind, {super.key, this.size = 20, this.color, this.semanticLabel});

  final GlyphKind kind;
  final double size;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final g = SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _GlyphPainter(kind, color)),
    );
    if (semanticLabel == null) return ExcludeSemantics(child: g);
    return Semantics(label: semanticLabel, image: true, child: g);
  }
}

class _GlyphPainter extends CustomPainter {
  _GlyphPainter(this.kind, this.color);
  final GlyphKind kind;
  final Color? color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    canvas.save();
    canvas.scale(s / 24);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color ?? CoveColors.text;
    final fill = Paint()..color = color ?? CoveColors.text;

    switch (kind) {
      case GlyphKind.ember:
        final glow = Paint()
          ..color = CoveColors.beam.withValues(alpha: 0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
        canvas.drawCircle(const Offset(12, 14), 7, glow);
        canvas.drawPath(_flame(), Paint()..color = color ?? CoveColors.beam);
        canvas.drawPath(_flame(inner: true), Paint()..color = CoveColors.harbor);
      case GlyphKind.emberOut:
        // A spent wick: an outline flame and a thread of smoke.
        canvas.drawPath(_flame(), stroke..color = color ?? CoveColors.danger);
        canvas.drawPath(
            Path()
              ..moveTo(12, 5)
              ..cubicTo(10, 3, 14, 2, 12, 0),
            stroke..color = (color ?? CoveColors.textMuted).withValues(alpha: 0.7));
      case GlyphKind.lantern:
      case GlyphKind.lanternEmpty:
        final lit = kind == GlyphKind.lantern;
        if (lit) {
          canvas.drawCircle(const Offset(12, 13.5), 7,
              Paint()
                ..color = CoveColors.beam.withValues(alpha: 0.35)
                ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
        }
        final frame = stroke..color = color ?? (lit ? CoveColors.harbor : CoveColors.textMuted);
        canvas.drawLine(const Offset(9, 4), const Offset(15, 4), frame);
        canvas.drawArc(const Rect.fromLTWH(9.5, 1.5, 5, 4), math.pi, math.pi, false, frame);
        final body = RRect.fromLTRBR(7, 6, 17, 20, const Radius.circular(2.5));
        if (lit) canvas.drawRRect(body.deflate(1.2), Paint()..color = CoveColors.harbor);
        canvas.drawRRect(body, frame);
        canvas.drawLine(const Offset(6, 21.5), const Offset(18, 21.5), frame);
      case GlyphKind.oil:
        final drop = Path()
          ..moveTo(12, 3)
          ..cubicTo(15, 8, 18.5, 11, 18.5, 14.5)
          ..arcToPoint(const Offset(5.5, 14.5), radius: const Radius.circular(6.5))
          ..cubicTo(5.5, 11, 9, 8, 12, 3)
          ..close();
        canvas.drawPath(drop, fill..color = color ?? CoveColors.harbor);
        canvas.drawPath(
            Path()
              ..moveTo(9, 14)
              ..quadraticBezierTo(9, 17, 11.5, 17.5),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.4
              ..strokeCap = StrokeCap.round
              ..color = CoveColors.sea.withValues(alpha: 0.5));
      case GlyphKind.hull:
        canvas.drawPath(
            Path()
              ..moveTo(3, 15)
              ..lineTo(21, 15)
              ..lineTo(18, 19)
              ..lineTo(6, 19)
              ..close(),
            fill);
        canvas.drawLine(const Offset(12, 15), const Offset(12, 4), stroke);
        canvas.drawPath(
            Path()
              ..moveTo(13, 5)
              ..lineTo(13, 13.5)
              ..lineTo(19, 13.5)
              ..close(),
            fill);
      case GlyphKind.back:
        canvas.drawPath(
            Path()
              ..moveTo(15, 5)
              ..lineTo(8, 12)
              ..lineTo(15, 19),
            stroke..strokeWidth = 2);
      case GlyphKind.pause:
        // A hanging storm lantern with its flame turned down.
        canvas.drawLine(const Offset(12, 1.5), const Offset(12, 4), stroke);
        canvas.drawRRect(RRect.fromLTRBR(6.5, 4, 17.5, 20, const Radius.circular(3)), stroke);
        canvas.drawLine(const Offset(10, 9), const Offset(10, 15), stroke);
        canvas.drawLine(const Offset(14, 9), const Offset(14, 15), stroke);
        canvas.drawLine(const Offset(5, 22), const Offset(19, 22), stroke);
      case GlyphKind.bell:
        final b = Path()
          ..moveTo(5, 17)
          ..lineTo(19, 17)
          ..cubicTo(17, 15, 17.5, 12, 17, 9)
          ..cubicTo(16.5, 5, 7.5, 5, 7, 9)
          ..cubicTo(6.5, 12, 7, 15, 5, 17)
          ..close();
        canvas.drawPath(b, stroke);
        canvas.drawCircle(const Offset(12, 19.5), 1.6, fill);
        canvas.drawLine(const Offset(12, 3), const Offset(12, 5.5), stroke);
      case GlyphKind.moon:
        final moon = Path()
          ..addOval(const Rect.fromLTWH(4, 4, 16, 16));
        final bite = Path()..addOval(const Rect.fromLTWH(9, 2, 15, 15));
        canvas.drawPath(Path.combine(PathOperation.difference, moon, bite), fill);
      case GlyphKind.check:
        canvas.drawPath(
            Path()
              ..moveTo(5, 12.5)
              ..lineTo(10, 17)
              ..lineTo(19, 7),
            stroke..strokeWidth = 2);
      case GlyphKind.lock:
        canvas.drawRRect(RRect.fromLTRBR(6, 11, 18, 20, const Radius.circular(2)), stroke);
        canvas.drawArc(const Rect.fromLTWH(8.5, 5, 7, 10), math.pi, math.pi, false, stroke);
    }
    canvas.restore();
  }

  Path _flame({bool inner = false}) {
    if (inner) {
      return Path()
        ..moveTo(12, 11)
        ..cubicTo(14, 13.5, 14.5, 15, 14.5, 16.5)
        ..arcToPoint(const Offset(9.5, 16.5), radius: const Radius.circular(2.5))
        ..cubicTo(9.5, 15, 10, 13.5, 12, 11)
        ..close();
    }
    return Path()
      ..moveTo(12, 3)
      ..cubicTo(16, 8, 18, 11, 18, 15)
      ..arcToPoint(const Offset(6, 15), radius: const Radius.circular(6))
      ..cubicTo(6, 11.5, 8.5, 9.5, 10, 7)
      ..cubicTo(10.5, 9, 11.5, 10, 12, 10)
      ..cubicTo(12, 8, 11.5, 5.5, 12, 3)
      ..close();
  }

  @override
  bool shouldRepaint(_GlyphPainter old) => old.kind != kind || old.color != color;
}

/// A row of 1-3 lanterns (earned are lit; never colour alone: lit ones are
/// filled, unearned are outlines).
class LanternRow extends StatelessWidget {
  const LanternRow(this.count, {super.key, this.size = 16, this.of = 3});
  final int count;
  final int of;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$count of $of lanterns',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < of; i++)
              Glyph(i < count ? GlyphKind.lantern : GlyphKind.lanternEmpty, size: size),
          ],
        ),
      ),
    );
  }
}

/// Lamp oil amount with its drop.
class OilAmount extends StatelessWidget {
  const OilAmount(this.amount, {super.key, this.size = 16, this.style});
  final int amount;
  final double size;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$amount lamp oil',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Glyph(GlyphKind.oil, size: size),
            const SizedBox(width: 4),
            Text('$amount', style: style ?? CoveText.hud().copyWith(color: CoveColors.harbor)),
          ],
        ),
      ),
    );
  }
}
