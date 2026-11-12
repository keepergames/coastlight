import 'package:flutter/material.dart';

import '../app.dart';
import '../audio/fx.dart';
import '../theme/cove_theme.dart';
import '../widgets/controls.dart';
import '../widgets/glyphs.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _confirmReset(BuildContext context) async {
    final p = context.progress;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear the logbook?'),
        content: const Text(
          'Every kept night, lantern, mark, lamp oil and purchase will be erased from this device. '
          'This cannot be undone. Your sound and motion settings stay as they are.',
        ),
        actions: [
          QuietAction(
            label: 'Keep my progress',
            onTap: () => Navigator.of(context).pop(false),
          ),
          QuietAction(
            label: 'Clear everything',
            danger: true,
            onTap: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await p.reset();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('The logbook is clear. A new year begins.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.progress;

    Widget toggle(
      String label,
      String detail,
      bool value,
      void Function(bool) set,
    ) => MergeSemantics(
      child: InkWell(
        onTap: () {
          Fx.lightTap();
          set(!value);
        },
        child: LogRow(
          label: label,
          detail: detail,
          value: Switch(
            value: value,
            onChanged: (v) {
              Fx.lightTap();
              set(v);
            },
          ),
        ),
      ),
    );

    Widget link(String label, VoidCallback open) => Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: () {
          Fx.play(Sfx.page, volume: 0.6);
          open();
        },
        child: ExcludeSemantics(
          child: LogRow(
            label: label,
            value: const RotatedBox(
              quarterTurns: 2,
              child: Glyph(
                GlyphKind.back,
                size: 20,
                color: CoveColors.textMuted,
              ),
            ),
          ),
        ),
      ),
    );

    return CovePage(
      title: 'Settings',
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          CoveSpacing.xl,
          0,
          CoveSpacing.xl,
          MediaQuery.paddingOf(context).bottom + CoveSpacing.xl,
        ),
        children: [
          const SectionHead('Sound and touch'),
          toggle(
            'Sound',
            'Bells, the beam and the harbour',
            p.sound,
            (v) => p.setSettings(sound: v),
          ),
          toggle(
            'Music',
            'The sea and the keeper\'s tune',
            p.music,
            (v) => p.setSettings(music: v),
          ),
          toggle(
            'Vibration',
            'A light touch when boats come home',
            p.vibration,
            (v) => p.setSettings(vibration: v),
          ),
          toggle(
            'Reduce motion',
            'Calms the swell, shakes and moving light',
            p.reduceMotion,
            (v) => p.setSettings(reduceMotion: v),
          ),
          const SectionHead('The lighthouse'),
          link('How to play', () => Navigator.of(context).pushNamed(Routes.duty)),
          link(
            'A quiet promise (privacy)',
            () => Navigator.of(context).pushNamed(Routes.promise),
          ),
          // Bundled licences (Spectral's OFL is registered in main.dart).
          link(
            'Open-source licences',
            () => showLicensePage(
              context: context,
              applicationName: 'Keeper of the Cove',
              applicationVersion: '1.0.0',
            ),
          ),
          const SectionHead('Logbook'),
          Align(
            alignment: Alignment.centerLeft,
            child: QuietAction(
              label: 'Clear all progress',
              danger: true,
              onTap: () => _confirmReset(context),
            ),
          ),
          const SizedBox(height: CoveSpacing.xl),
          Text('Keeper of the Cove · version 1.0.0', style: CoveText.caption()),
        ],
      ),
    );
  }
}
