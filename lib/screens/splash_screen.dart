import 'dart:async';

import 'package:flutter/material.dart';

import '../app.dart';
import '../theme/cove_theme.dart';

/// First Light: black, then the beam sweeps once across the title and lights
/// the letters as it passes. Tap to skip.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );
  Timer? _leave;
  bool _gone = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final reduce =
          context.progress.reduceMotion ||
          (MediaQuery.maybeDisableAnimationsOf(context) ?? false);
      if (reduce) _c.duration = const Duration(milliseconds: 700);
      _c.forward();
      _leave = Timer(_c.duration! + const Duration(milliseconds: 500), _go);
    });
  }

  void _go() {
    if (_gone || !mounted) return;
    _gone = true;
    final p = context.progress;
    Navigator.of(context).pushReplacementNamed(Routes.hub);
    if (!p.seenDuty) Navigator.of(context).pushNamed(Routes.duty);
  }

  @override
  void dispose() {
    _leave?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _go,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final t = Curves.easeInOutSine.transform(_c.value);
            // The beam's position across the title, from off-left to off-right.
            final x = -0.4 + t * 1.8;
            return Stack(
              fit: StackFit.expand,
              children: [
                // The beam itself, a soft diagonal shaft sweeping across.
                Opacity(
                  opacity: (1 - (t - 0.5).abs() * 2).clamp(0.0, 1.0) * 0.5,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment(-1 + x * 2 - 0.5, -1),
                        end: Alignment(-1 + x * 2 + 0.5, 1),
                        colors: [
                          CoveColors.beam.withValues(alpha: 0),
                          CoveColors.beam.withValues(alpha: 0.35),
                          CoveColors.beam.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
                Center(
                  child: ShaderMask(
                    blendMode: BlendMode.srcIn,
                    shaderCallback: (rect) => LinearGradient(
                      colors: [
                        CoveColors.harbor.withValues(alpha: 0.85),
                        CoveColors.harbor,
                        CoveColors.beam,
                        const Color(0xFF2A3A4E),
                      ],
                      stops: [
                        0,
                        (x - 0.15).clamp(0.0, 1.0),
                        x.clamp(0.0, 1.0),
                        (x + 0.12).clamp(0.0, 1.0),
                      ],
                    ).createShader(rect),
                    child: Semantics(
                      header: true,
                      child: Text(
                        'Keeper\nof the Cove',
                        textAlign: TextAlign.center,
                        style: CoveText.display().copyWith(
                          fontSize: 46,
                          letterSpacing: 3,
                          height: 1.15,
                        ),
                      ),
                    ),
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
