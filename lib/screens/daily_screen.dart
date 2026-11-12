import 'package:flutter/material.dart';

import '../app.dart';
import '../data/progress.dart';
import '../engine/modes.dart';
import '../engine/night_spec.dart';
import '../engine/seasons.dart';
import '../theme/cove_theme.dart';
import '../widgets/controls.dart';
import '../widgets/glyphs.dart';
import 'night_screen.dart';

/// The Daily Tide: one night a day, the same for everyone, and a streak.
class DailyScreen extends StatelessWidget {
  const DailyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.progress;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final spec = dailySpec(today, furthestSeason: p.furthestSeason);
    final done = p.dailyDone(today);
    final streak = p.dailyStreak(today);

    return CovePage(
      title: 'Daily Tide',
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          CoveSpacing.xl,
          CoveSpacing.xl,
          CoveSpacing.xl,
          MediaQuery.paddingOf(context).bottom + CoveSpacing.xl,
        ),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Semantics(
                label: '$streak day streak',
                child: ExcludeSemantics(
                  child: Text(
                    '$streak',
                    style: CoveText.number(
                      72,
                    ).copyWith(color: CoveColors.harbor),
                  ),
                ),
              ),
              const SizedBox(width: CoveSpacing.md),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ExcludeSemantics(
                    child: Text(
                      streak == 1 ? 'day in a row' : 'days in a row',
                      style: CoveText.title(),
                    ),
                  ),
                ),
              ),
              Glyph(
                GlyphKind.bell,
                size: 56,
                color: done ? CoveColors.harbor : CoveColors.textMuted,
              ),
            ],
          ),
          const SizedBox(height: CoveSpacing.xs),
          Text('Best streak: ${p.bestDailyStreak}', style: CoveText.caption()),
          const SizedBox(height: CoveSpacing.xxl),
          _TideCalendar(today: today, kept: p.dailyKept),
          const SizedBox(height: CoveSpacing.sm),
          Wrap(
            spacing: CoveSpacing.lg,
            runSpacing: 4,
            children: const [
              _Legend(kind: _Mark.kept, text: 'Kept'),
              _Legend(kind: _Mark.missed, text: 'Missed'),
              _Legend(kind: _Mark.today, text: 'Today'),
            ],
          ),
          const SizedBox(height: CoveSpacing.xxl),
          Text(_describe(spec), style: CoveText.body()),
          const SizedBox(height: CoveSpacing.xs),
          Text(
            'Every keeper meets the same sea today. Keeping it earns 20 extra lamp oil.',
            style: CoveText.body().copyWith(color: CoveColors.textMuted),
          ),
          const SizedBox(height: CoveSpacing.xl),
          BeamAction(
            label: done ? 'Ring it again' : 'Ring the tide bell',
            large: true,
            detail: done
                ? "Today's tide is kept. A new one comes at midnight."
                : null,
            onTap: () => startNight(
              context,
              NightArgs(mode: PlayMode.daily, spec: spec, day: dayKey(today)),
            ),
          ),
        ],
      ),
    );
  }

  String _describe(NightSpec s) {
    final parts = <String>['Bring ${s.quota} home before dawn'];
    if (s.fogBanks > 0) parts.add('fog on the water');
    if (s.convoyChance > 0) parts.add('convoys');
    if (s.buoys.isNotEmpty) parts.add('bell buoys');
    return '${parts.join(', ')}. ${seasons[s.season].name} weather.';
  }
}

enum _Mark { kept, missed, today, future }

class _TideCalendar extends StatelessWidget {
  const _TideCalendar({required this.today, required this.kept});
  final DateTime today;
  final Set<String> kept;

  @override
  Widget build(BuildContext context) {
    // Four weeks ending on the week that holds today (Monday-first).
    final end = today.add(Duration(days: 7 - today.weekday));
    final start = end.subtract(const Duration(days: 27));
    const names = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return Column(
      children: [
        Row(
          children: [
            for (final n in names)
              Expanded(
                child: Center(child: Text(n, style: CoveText.caption())),
              ),
          ],
        ),
        const SizedBox(height: CoveSpacing.sm),
        for (var w = 0; w < 4; w++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                for (var d = 0; d < 7; d++)
                  Expanded(
                    child: Center(
                      child: _dayMark(start.add(Duration(days: w * 7 + d))),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _dayMark(DateTime day) {
    final key = dayKey(day);
    final first = kept.isEmpty
        ? null
        : kept.reduce((a, b) => a.compareTo(b) < 0 ? a : b);
    final beforeFirst = first == null || key.compareTo(first) < 0;
    final mark = day.isAfter(today) || (beforeFirst && day != today)
        ? _Mark.future
        : kept.contains(key)
        ? _Mark.kept
        : (day == today ? _Mark.today : _Mark.missed);
    final label = switch (mark) {
      _Mark.kept => 'kept',
      _Mark.missed => 'missed',
      _Mark.today => 'today, not yet kept',
      _Mark.future => day.isAfter(today) ? 'to come' : 'before your first tide',
    };
    return Semantics(
      label: '${day.day} ${_month(day.month)}, $label',
      child: ExcludeSemantics(
        child: SizedBox.square(
          dimension: 30,
          child: CustomPaint(painter: _MarkPainter(mark)),
        ),
      ),
    );
  }

  static String _month(int m) => const [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ][m - 1];
}

class _Legend extends StatelessWidget {
  const _Legend({required this.kind, required this.text});
  final _Mark kind;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      SizedBox.square(
        dimension: 16,
        child: CustomPaint(painter: _MarkPainter(kind)),
      ),
      const SizedBox(width: 6),
      Text(text, style: CoveText.caption()),
    ],
  );
}

class _MarkPainter extends CustomPainter {
  _MarkPainter(this.mark);
  final _Mark mark;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width * 0.4;
    switch (mark) {
      case _Mark.kept:
        canvas.drawCircle(
          c,
          r * 1.3,
          Paint()
            ..color = CoveColors.beam.withValues(alpha: 0.3)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
        );
        canvas.drawCircle(c, r, Paint()..color = CoveColors.harbor);
      case _Mark.missed:
        canvas.drawCircle(
          c,
          r * 0.85,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4
            ..color = CoveColors.textMuted.withValues(alpha: 0.7),
        );
      case _Mark.today:
        canvas.drawCircle(
          c,
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = CoveColors.beam,
        );
        canvas.drawCircle(c, r * 0.3, Paint()..color = CoveColors.beam);
      case _Mark.future:
        canvas.drawCircle(c, 1.6, Paint()..color = CoveColors.rule);
    }
  }

  @override
  bool shouldRepaint(_MarkPainter old) => old.mark != mark;
}
