import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../app.dart';
import '../audio/fx.dart';
import '../data/catalog.dart';
import '../data/progress.dart';
import '../game/art.dart';
import '../theme/cove_theme.dart';
import '../widgets/controls.dart';
import '../widgets/glyphs.dart';

/// The Chandlery: cosmetics bought with lamp oil earned by playing.
class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  Shelf _shelf = Shelf.beam;
  String? _selected;

  Good _previewGood(Progress p) => _selected != null
      ? goodById(_selected!)
      : (isExclusive(_shelf)
            ? p.equippedGood(_shelf)
            : shelfGoods(_shelf).first);

  void _buy(Progress p, Good g) {
    final fresh = p.buy(g);
    if (fresh == null) return;
    Fx.play(Sfx.purchase);
    Fx.soft();
    final msg = fresh.isEmpty
        ? '${g.name} is yours.'
        : '${g.name} is yours. ${fresh.map((a) => a.name).join(', ')} earned.';
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final p = context.progress;
    final preview = _previewGood(p);
    return CovePage(
      title: 'Chandlery',
      trailing: Padding(
        padding: const EdgeInsets.only(right: CoveSpacing.xs),
        child: OilAmount(p.oil, size: 18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: CoveSpacing.md),
          SizedBox(
            height: 180,
            child: Semantics(
              label: 'Preview of ${preview.name}',
              child: ClipRect(
                child: CustomPaint(painter: _Preview(p, preview)),
              ),
            ),
          ),
          const SizedBox(height: CoveSpacing.md),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: CoveSpacing.lg),
            child: Row(
              children: [
                for (final s in Shelf.values)
                  _ShelfTab(
                    label: shelfTitle(s),
                    selected: s == _shelf,
                    onTap: () => setState(() {
                      _shelf = s;
                      _selected = null;
                    }),
                  ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                CoveSpacing.xl,
                CoveSpacing.sm,
                CoveSpacing.xl,
                MediaQuery.paddingOf(context).bottom + CoveSpacing.xl,
              ),
              children: [
                for (final g in shelfGoods(_shelf)) _goodRow(p, g),
                const SizedBox(height: CoveSpacing.lg),
                Text(
                  'Lamp oil comes from keeping the light: one for each soul home, more for lanterns '
                  'and for the Daily Tide. Nothing here costs money.',
                  style: CoveText.caption(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _goodRow(Progress p, Good g) {
    final owned = p.owned.contains(g.id);
    final inUse = isExclusive(g.shelf)
        ? p.equipped[g.shelf] == g.id
        : p.shownKeepsakes.contains(g.id);
    final selected = _selected == g.id;
    final state = inUse
        ? (isExclusive(g.shelf) ? 'In use' : 'On show')
        : owned
        ? 'Owned'
        : null;

    Widget? action;
    if (selected) {
      if (!owned) {
        action = BeamAction(
          label: p.canAfford(g)
              ? 'Buy for ${g.price} oil'
              : 'Needs ${g.price - p.oil} more oil',
          onTap: p.canAfford(g) ? () => _buy(p, g) : null,
        );
      } else if (!inUse || !isExclusive(g.shelf)) {
        action = BeamAction(
          label: isExclusive(g.shelf)
              ? 'Put in use'
              : (inUse ? 'Put away' : 'Put on show'),
          onTap: () {
            Fx.play(Sfx.tap);
            p.use(g);
          },
        );
      }
    }

    // The row (select to preview) and its action are separate semantic
    // nodes, so a screen reader can reach the Buy / Put in use button.
    return Container(
      padding: const EdgeInsets.symmetric(vertical: CoveSpacing.md),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: CoveColors.rule)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            selected: selected,
            label: '${g.name}. ${g.line} ${state ?? '${g.price} lamp oil'}',
            child: InkWell(
              onTap: () {
                Fx.play(Sfx.tap, volume: 0.6);
                setState(() => _selected = g.id);
              },
              child: ExcludeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (g.beamColor != null) ...[
                          Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: g.beamColor,
                            ),
                          ),
                          const SizedBox(width: CoveSpacing.sm),
                        ],
                        Expanded(
                          child: Text(
                            g.name,
                            style: CoveText.title().copyWith(
                              color: selected
                                  ? CoveColors.beam
                                  : CoveColors.text,
                            ),
                          ),
                        ),
                        if (state != null)
                          Text(
                            state,
                            style: CoveText.label().copyWith(
                              color: CoveColors.harbor,
                            ),
                          )
                        else
                          OilAmount(
                            g.price,
                            size: 16,
                            style: CoveText.hud().copyWith(
                              color: p.canAfford(g)
                                  ? CoveColors.harbor
                                  : CoveColors.textMuted,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      g.line,
                      style: CoveText.body().copyWith(
                        color: CoveColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (action != null)
            Padding(
              padding: const EdgeInsets.only(top: CoveSpacing.xs),
              child: Align(alignment: Alignment.centerLeft, child: action),
            ),
        ],
      ),
    );
  }
}

class _ShelfTab extends StatelessWidget {
  const _ShelfTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          Fx.play(Sfx.tap, volume: 0.6);
          onTap();
        },
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: CoveSpacing.md,
              vertical: CoveSpacing.sm,
            ),
            child: ExcludeSemantics(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: CoveText.label().copyWith(
                      color: selected ? CoveColors.beam : CoveColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  AnimatedContainer(
                    duration: CoveMotion.quick,
                    height: 2,
                    width: selected ? 32 : 0,
                    color: CoveColors.beam,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A small night scene that wears whatever is being looked at.
class _Preview extends CustomPainter {
  _Preview(this.p, this.good);
  final Progress p;
  final Good good;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final sea = Art.sea(0);
    if (sea != null) paintCover(canvas, sea, rect, alignY: -0.2);
    canvas.drawRect(
      rect,
      Paint()..color = CoveColors.sea.withValues(alpha: 0.25),
    );

    final beam = good.shelf == Shelf.beam
        ? good.beamColor!
        : (p.equippedGood(Shelf.beam).beamColor ?? CoveColors.beam);
    final paint = good.shelf == Shelf.paint
        ? good.asset!
        : (p.equippedGood(Shelf.paint).asset ?? 'rust');
    final livery = good.shelf == Shelf.boats
        ? good.asset!
        : (p.equippedGood(Shelf.boats).asset ?? 'skiff');

    // Tower on the right, its beam reaching left over the water.
    final tower = Art.img('tower_$paint');
    final th = size.height * 1.25;
    final tw = tower == null ? 0.0 : th * tower.width / tower.height;
    final tx = size.width * 0.74;
    final lamp = Offset(tx, size.height * 0.08 + th * 0.13);
    final cone = Path()
      ..moveTo(lamp.dx, lamp.dy)
      ..lineTo(0, lamp.dy - size.height * 0.05)
      ..lineTo(0, lamp.dy + size.height * 0.42)
      ..close();
    canvas.drawPath(
      cone,
      Paint()
        ..shader = ui.Gradient.linear(lamp, Offset(0, lamp.dy), [
          beam.withValues(alpha: 0.55),
          beam.withValues(alpha: 0.04),
        ]),
    );
    if (tower != null) {
      canvas.drawImageRect(
        tower,
        Rect.fromLTWH(0, 0, tower.width.toDouble(), tower.height.toDouble()),
        Rect.fromLTWH(tx - tw / 2, size.height * 0.08, tw, th),
        Paint()..filterQuality = FilterQuality.medium,
      );
    }

    // A boat in the chosen livery, caught in the beam.
    final boat = Art.boat(livery, good.shelf == Shelf.boats ? 3 : 1);
    if (boat != null) {
      final bs = size.height * 0.55;
      final c = Offset(size.width * 0.3, size.height * 0.62);
      canvas.drawCircle(
        c,
        bs * 0.4,
        Paint()
          ..color = beam.withValues(alpha: 0.25)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
      );
      canvas.drawImageRect(
        boat,
        Rect.fromLTWH(0, 0, boat.width.toDouble(), boat.height.toDouble()),
        Rect.fromCenter(
          center: c - Offset(0, bs * 0.18),
          width: bs,
          height: bs,
        ),
        Paint()..filterQuality = FilterQuality.medium,
      );
    }

    // A keepsake being looked at sits large in the foreground.
    if (good.shelf == Shelf.keepsakes) {
      final k = Art.img('keepsake_${good.asset}');
      if (k != null) {
        final kw = math.min(
          size.width * 0.32,
          size.height * (k.width / k.height) * 0.7,
        );
        final kh = kw * k.height / k.width;
        canvas.drawImageRect(
          k,
          Rect.fromLTWH(0, 0, k.width.toDouble(), k.height.toDouble()),
          Rect.fromLTWH(size.width * 0.06, size.height - kh - 8, kw, kh),
          Paint()..filterQuality = FilterQuality.medium,
        );
      }
    }
    // Fade the edges into the page.
    for (final (begin, end) in [
      (Alignment.topCenter, Alignment.bottomCenter),
      (Alignment.bottomCenter, Alignment.topCenter),
    ]) {
      canvas.drawRect(
        rect,
        Paint()
          ..shader = LinearGradient(
            begin: begin,
            end: end,
            colors: [CoveColors.sea, CoveColors.sea.withValues(alpha: 0)],
            stops: const [0, 0.18],
          ).createShader(rect),
      );
    }
  }

  @override
  bool shouldRepaint(_Preview old) => true;
}
