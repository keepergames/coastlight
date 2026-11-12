import 'package:flutter/material.dart';

import '../app.dart';
import '../data/progress.dart';
import '../engine/seasons.dart';
import '../theme/cove_theme.dart';
import '../widgets/controls.dart';
import '../widgets/glyphs.dart';

/// The Keeper's Log: what the keeper has done, and the marks earned.
class LogScreen extends StatelessWidget {
  const LogScreen({super.key});

  String _time(double seconds) {
    final m = (seconds / 60).floor();
    if (m < 60) return '$m min';
    return '${m ~/ 60} h ${m % 60} min';
  }

  @override
  Widget build(BuildContext context) {
    final p = context.progress;
    final earned = achievements.where((a) => p.unlocked.contains(a.id)).length;
    Widget stat(String label, String value) => LogRow(
      label: label,
      value: Text(value, style: CoveText.hud().copyWith(fontSize: 16)),
    );

    return CovePage(
      title: "Keeper's Log",
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          CoveSpacing.xl,
          0,
          CoveSpacing.xl,
          MediaQuery.paddingOf(context).bottom + CoveSpacing.xl,
        ),
        children: [
          const SectionHead('The watch so far'),
          stat('Souls brought home', '${p.soulsHome}'),
          stat('Nights kept', '${p.nightsKept}'),
          stat('Lanterns earned', '${p.totalLanterns} of ${nightCount * 3}'),
          stat('Longest run without a loss', '${p.bestStreak}'),
          stat('Whole convoys home', '${p.convoysHome}'),
          stat('Boats charted in fog', '${p.chartedInFog}'),
          stat('Bell buoys kindled', '${p.buoysKindled}'),
          stat('Embers lost to the dark', '${p.embersLost}'),
          stat('Daily Tides kept', '${p.dailyKept.length}'),
          stat('Best Longest Night', '${p.longestBest}'),
          stat('Time at the lamp', _time(p.secondsAtLamp)),
          const SectionHead('The year'),
          for (final s in seasons)
            LogRow(
              label: s.name,
              dim: !p.seasonOpen(s.index),
              detail: p.seasonOpen(s.index)
                  ? '${p.seasonKept(s.index)} of ${s.length} nights kept'
                  : 'Not reached yet',
              value: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Glyph(GlyphKind.lantern, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    '${p.seasonLanterns(s.index)} / ${s.length * 3}',
                    style: CoveText.hud(),
                  ),
                ],
              ),
            ),
          SectionHead(
            'Marks',
            trailing: Text(
              '$earned of ${achievements.length}',
              style: CoveText.hud(),
            ),
          ),
          for (final a in achievements)
            Builder(
              builder: (context) {
                final has = p.unlocked.contains(a.id);
                return Semantics(
                  label:
                      '${a.name}. ${a.line} ${has ? 'Earned' : 'Not yet earned'}',
                  child: ExcludeSemantics(
                    child: LogRow(
                      label: a.name,
                      detail: a.line,
                      dim: !has,
                      leading: Glyph(
                        has ? GlyphKind.check : GlyphKind.lock,
                        size: 22,
                        color: has ? CoveColors.harbor : CoveColors.textMuted,
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
