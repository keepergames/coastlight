import 'package:flutter/material.dart';

import '../audio/fx.dart';
import '../theme/cove_theme.dart';
import 'glyphs.dart';

/// The primary action: beam-coloured words on the night sea with a short
/// beam of light under them that brightens on press. Never a filled pill.
class BeamAction extends StatefulWidget {
  const BeamAction({
    super.key,
    required this.label,
    required this.onTap,
    this.detail,
    this.large = false,
    this.align = CrossAxisAlignment.start,
  });

  final String label;
  final String? detail;
  final VoidCallback? onTap;
  final bool large;
  final CrossAxisAlignment align;

  @override
  State<BeamAction> createState() => _BeamActionState();
}

class _BeamActionState extends State<BeamAction> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final colour = enabled ? CoveColors.beam : CoveColors.textMuted;
    final style = (widget.large ? CoveText.headline() : CoveText.title()).copyWith(color: colour);
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.detail == null ? widget.label : '${widget.label}, ${widget.detail}',
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: enabled ? (_) => setState(() => _down = true) : null,
          onTapCancel: () => setState(() => _down = false),
          onTapUp: enabled
              ? (_) {
                  setState(() => _down = false);
                  Fx.play(Sfx.tap);
                  Fx.lightTap();
                  widget.onTap!();
                }
              : null,
          child: AnimatedScale(
            scale: _down ? 0.97 : 1,
            duration: CoveMotion.quick,
            curve: CoveMotion.ease,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: CoveSpacing.sm),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: widget.align,
                  children: [
                    Text(widget.label, style: style),
                    const SizedBox(height: 6),
                    AnimatedContainer(
                      duration: CoveMotion.quick,
                      curve: CoveMotion.ease,
                      height: 2,
                      width: _down ? 88 : 56,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        gradient: LinearGradient(colors: [
                          colour.withValues(alpha: _down ? 1 : 0.85),
                          colour.withValues(alpha: 0),
                        ]),
                      ),
                    ),
                    if (widget.detail != null) ...[
                      const SizedBox(height: CoveSpacing.sm),
                      Text(widget.detail!, style: CoveText.label().copyWith(color: CoveColors.textMuted)),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A secondary action: plain words, no fill, no border.
class QuietAction extends StatelessWidget {
  const QuietAction({super.key, required this.label, required this.onTap, this.danger = false, this.flush = false});

  final String label;
  final VoidCallback? onTap;
  final bool danger;

  /// Text starts at the left edge (for actions stacked under a BeamAction).
  final bool flush;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap == null
          ? null
          : () {
              Fx.play(Sfx.tap);
              Fx.lightTap();
              onTap!();
            },
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
        padding: EdgeInsets.symmetric(horizontal: flush ? 0 : CoveSpacing.md, vertical: CoveSpacing.md),
        alignment: flush ? Alignment.centerLeft : null,
        foregroundColor: danger ? const Color(0xFFD9A08E) : CoveColors.text,
        textStyle: CoveText.label(),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Text(label),
    );
  }
}

/// A screen with a back control and a title, laid on the night sea.
class CovePage extends StatelessWidget {
  const CovePage({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
    this.background,
    this.onBack,
  });

  final String title;
  final Widget child;
  final Widget? trailing;
  final Widget? background;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          if (background != null) Positioned.fill(child: background!),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(CoveSpacing.xs, CoveSpacing.sm, CoveSpacing.lg, 0),
                  child: Row(
                    children: [
                      BackGlyph(onTap: onBack ?? () => Navigator.of(context).maybePop()),
                      const SizedBox(width: CoveSpacing.xs),
                      Expanded(
                        child: Semantics(
                          header: true,
                          child: Text(title, style: CoveText.headline(), maxLines: 2, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                      ?trailing,
                    ],
                  ),
                ),
                Expanded(child: child),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class BackGlyph extends StatelessWidget {
  const BackGlyph({super.key, required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () {
        Fx.play(Sfx.page, volume: 0.6);
        Fx.lightTap();
        onTap();
      },
      tooltip: 'Back',
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      icon: const Glyph(GlyphKind.back, size: 24),
    );
  }
}

/// A list row divided from its neighbours by a tide line and space.
class LogRow extends StatelessWidget {
  const LogRow({super.key, required this.label, this.value, this.detail, this.leading, this.dim = false});

  final String label;
  final Widget? value;
  final String? detail;
  final Widget? leading;
  final bool dim;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.symmetric(vertical: CoveSpacing.md),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: CoveColors.rule))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: CoveSpacing.md)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label,
                    style: CoveText.body().copyWith(color: dim ? CoveColors.textMuted : CoveColors.text)),
                if (detail != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(detail!, style: CoveText.caption()),
                  ),
              ],
            ),
          ),
          if (value != null) ...[const SizedBox(width: CoveSpacing.md), value!],
        ],
      ),
    );
  }
}

/// Section heading inside a long screen: more space above than below.
class SectionHead extends StatelessWidget {
  const SectionHead(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: CoveSpacing.xxl, bottom: CoveSpacing.sm),
      child: Row(
        children: [
          Expanded(child: Semantics(header: true, child: Text(text, style: CoveText.title()))),
          ?trailing,
        ],
      ),
    );
  }
}
