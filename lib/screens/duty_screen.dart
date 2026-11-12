import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../app.dart';
import '../audio/fx.dart';
import '../engine/night_spec.dart';
import '../engine/sim.dart';
import '../game/night_painter.dart';
import '../theme/cove_theme.dart';
import '../widgets/controls.dart';
import '../widgets/glyphs.dart';

/// The Keeper's Duty: how to play, with a small sea you can try it on.
class DutyScreen extends StatefulWidget {
  const DutyScreen({super.key});

  @override
  State<DutyScreen> createState() => _DutyScreenState();
}

class _DutyScreenState extends State<DutyScreen> {
  final _pages = PageController();
  int _page = 0;

  static const _count = 3;

  void _done() {
    context.progress.markDutySeen();
    Navigator.of(context).maybePop();
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final last = _page == _count - 1;
    return CovePage(
      title: "The Keeper's Duty",
      onBack: _done,
      child: Column(
        children: [
          Expanded(
            child: PageView(
              controller: _pages,
              onPageChanged: (i) {
                Fx.play(Sfx.page, volume: 0.5);
                setState(() => _page = i);
              },
              children: const [_TryIt(), _Embers(), _Seasons()],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              CoveSpacing.xl,
              CoveSpacing.sm,
              CoveSpacing.xl,
              MediaQuery.paddingOf(context).bottom + CoveSpacing.lg,
            ),
            child: Row(
              children: [
                Semantics(
                  label: 'Page ${_page + 1} of $_count',
                  child: ExcludeSemantics(
                    child: Row(
                      children: [
                        for (var i = 0; i < _count; i++)
                          AnimatedContainer(
                            duration: CoveMotion.quick,
                            margin: const EdgeInsets.only(right: 6),
                            width: i == _page ? 18 : 6,
                            height: 6,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(3),
                              color: i == _page
                                  ? CoveColors.beam
                                  : CoveColors.rule,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                BeamAction(
                  label: last ? 'Begin the watch' : 'Next',
                  align: CrossAxisAlignment.end,
                  onTap: last
                      ? _done
                      : () => _pages.nextPage(
                          duration: CoveMotion.page,
                          curve: CoveMotion.ease,
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Page extends StatelessWidget {
  const _Page({required this.title, required this.body, required this.art});
  final String title;
  final String body;
  final Widget art;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            CoveSpacing.xl,
            CoveSpacing.lg,
            CoveSpacing.xl,
            CoveSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: (box.maxHeight * 0.55).clamp(220.0, 420.0),
                child: art,
              ),
              const SizedBox(height: CoveSpacing.xl),
              Semantics(
                header: true,
                child: Text(title, style: CoveText.title()),
              ),
              const SizedBox(height: CoveSpacing.sm),
              Text(
                body,
                style: CoveText.body().copyWith(color: CoveColors.textMuted),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// A small, endless, forgiving sea to practise on.
class _TryIt extends StatefulWidget {
  const _TryIt();

  @override
  State<_TryIt> createState() => _TryItState();
}

class _TryItState extends State<_TryIt> with SingleTickerProviderStateMixin {
  static const _spec = NightSpec(
    id: 0,
    season: 0,
    name: 'Practice',
    quota: 1 << 20,
    dawnSeconds: double.infinity,
    maxAtOnce: 1,
    spawnPeriod: 2.5,
    speed: 42,
    beamReach: 1.05,
    rockTeeth: 12,
    seed: 9,
  );

  final CoveSim _sim = CoveSim(_spec);
  final NightVisuals _fx = NightVisuals();
  final ValueNotifier<int> _frame = ValueNotifier(0);
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  int _home = 0;
  bool _touched = false;

  @override
  void initState() {
    super.initState();
    _sim.aim(-1.2);
    _sim.step(7); // start with a boat already in sight
    _sim.drainEvents();
    _ticker = createTicker((elapsed) {
      final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.05);
      _last = elapsed;
      _sim.step(dt);
      _sim.embers = CoveSim.maxEmbers; // practice never runs out of light
      _fx.update(dt);
      for (final e in _sim.drainEvents()) {
        if (e.type == SimEventType.home) {
          Fx.play(Sfx.home, volume: 0.5);
          _fx.burst(e.pos, CoveColors.harbor);
          _fx.homeBloom = 1;
          setState(() => _home++);
        } else if (e.type == SimEventType.charted) {
          Fx.play(Sfx.charted, volume: 0.6);
        }
      }
      _frame.value++;
    })..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _frame.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = context.progress.reduceMotion;
    return _Page(
      title: 'Sweep the beam. Hold it on a boat.',
      body:
          'Drag anywhere on the sea to turn the light. Keep it on a boat until the ring around it '
          'fills; then it turns for the harbour on its own. Try it here.',
      art: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: LayoutBuilder(
          builder: (context, box) {
            final size = box.biggest;
            return Stack(
              children: [
                Positioned.fill(
                  child: Semantics(
                    label:
                        'Practice sea. Drag to sweep the beam. $_home boats home.',
                    child: Listener(
                      behavior: HitTestBehavior.opaque,
                      onPointerDown: (e) {
                        _sim.aimAt(SeaView(size).toWorld(e.localPosition));
                        if (!_touched) setState(() => _touched = true);
                      },
                      onPointerMove: (e) =>
                          _sim.aimAt(SeaView(size).toWorld(e.localPosition)),
                      child: CustomPaint(
                        painter: NightPainter(
                          sim: _sim,
                          fx: _fx,
                          beamColor: CoveColors.beam,
                          livery: 'skiff',
                          reduceMotion: reduce,
                          repaint: _frame,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: CoveSpacing.md,
                  top: CoveSpacing.md,
                  child: Text(
                    _home == 0
                        ? (_touched ? 'Hold it steady…' : 'Drag here')
                        : '$_home home',
                    style: CoveText.label().copyWith(color: CoveColors.harbor),
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

class _Embers extends StatelessWidget {
  const _Embers();

  @override
  Widget build(BuildContext context) {
    return _Page(
      title: 'Three embers keep the light',
      body:
          'A boat that reaches the rocks before it is charted puts out an ember. Lose all three and '
          'the light goes out. Bring the night\'s boats home before dawn and you keep a lantern for '
          'every ember still burning.',
      art: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Glyph(GlyphKind.ember, size: 56),
                Glyph(GlyphKind.ember, size: 56),
                Glyph(GlyphKind.emberOut, size: 56),
              ],
            ),
            const SizedBox(height: CoveSpacing.xl),
            const RotatedBox(
              quarterTurns: 3,
              child: Glyph(
                GlyphKind.back,
                size: 24,
                color: CoveColors.textMuted,
              ),
            ),
            const SizedBox(height: CoveSpacing.xl),
            const LanternRow(2, size: 56),
            const SizedBox(height: CoveSpacing.sm),
            Text(
              'Two embers left at dawn: two lanterns',
              style: CoveText.caption(),
            ),
          ],
        ),
      ),
    );
  }
}

class _Seasons extends StatelessWidget {
  const _Seasons();

  @override
  Widget build(BuildContext context) {
    Widget row(String name, String text) => LogRow(label: name, detail: text);
    return _Page(
      title: 'Each season brings something new',
      body:
          'You will learn each one on its first nights. Lamp oil from every night buys paint, glass '
          'and keepsakes at the Chandlery. Nothing in the game costs money.',
      art: ListView(
        physics: const NeverScrollableScrollPhysics(),
        children: [
          row('Still Water', 'Calm nights to learn the beam.'),
          row('Fog Season', 'Boats inside fog are hidden and chart slowly.'),
          row(
            'Squall Coast',
            'Light a convoy\'s lead and its line follows home.',
          ),
          row(
            'The Long Winter',
            'Kindle bell buoys; their halos guide boats for you.',
          ),
        ],
      ),
    );
  }
}
