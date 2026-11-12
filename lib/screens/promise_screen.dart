import 'package:flutter/material.dart';

import '../theme/cove_theme.dart';
import '../widgets/controls.dart';

/// A Quiet Promise: the privacy summary, in the keeper's words.
class PromiseScreen extends StatelessWidget {
  const PromiseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Widget para(String text) => Padding(
      padding: const EdgeInsets.only(bottom: CoveSpacing.lg),
      child: Text(text, style: CoveText.body()),
    );

    return CovePage(
      title: 'A Quiet Promise',
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          CoveSpacing.xl,
          CoveSpacing.xl,
          CoveSpacing.xl,
          MediaQuery.paddingOf(context).bottom + CoveSpacing.xl,
        ),
        children: [
          Text(
            'This lighthouse keeps no records of you.',
            style: CoveText.title().copyWith(color: CoveColors.harbor),
          ),
          const SizedBox(height: CoveSpacing.lg),
          para(
            'Keeper of the Cove collects no data at all. There is no account and no sign-in: '
            'you open the game and keep the light.',
          ),
          para(
            'The game works fully offline, sends nothing anywhere and asks for no permissions.',
          ),
          const SectionHead('Your progress'),
          para(
            'Your kept nights, lanterns, lamp oil, marks and settings are saved only on this device.',
          ),
          para(
            'To delete them, choose Clear all progress in Settings, clear this game\'s app data '
            'in your phone\'s settings, or uninstall the game.',
          ),
          const SectionHead('Questions'),
          para(
            'For questions or support, please use the developer contact details shown on this '
            'game\'s Google Play store listing.',
          ),
          Text('Updated 12 November 2026', style: CoveText.caption()),
        ],
      ),
    );
  }
}
