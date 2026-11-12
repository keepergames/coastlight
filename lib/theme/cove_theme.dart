import 'package:flutter/material.dart';

/// Palette from docs/DESIGN_LANGUAGE.md: five roles plus two text tones.
class CoveColors {
  CoveColors._();

  /// Night sea: the ground of every screen.
  static const Color sea = Color(0xFF0B1626);

  /// Tide: water highlights, fog, dimmed scene, dividers.
  static const Color lift = Color(0xFF152A3F);

  /// Beam: the light and the one live control.
  static const Color beam = Color(0xFFF4B860);

  /// Harbor glow: safety and reward.
  static const Color harbor = Color(0xFFFFD9A0);

  /// Rust: rocks and a lost ember. Never bright red.
  static const Color danger = Color(0xFF7E4A3B);

  static const Color text = Color(0xFFEAF1F8);
  static const Color textMuted = Color(0xFF8AA0B4);

  /// Hairline dividers in lists.
  static const Color rule = Color(0xFF22384F);
}

/// 4-pt spacing scale.
class CoveSpacing {
  CoveSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;

  static const double screenMargin = 16;
  static const double hubMargin = 24;
  static const double focal = 24;
}

/// Spectral mapped to the type roles in DESIGN_LANGUAGE.md.
class CoveText {
  CoveText._();

  static const String fontFamily = 'Spectral';
  static const _tab = [FontFeature.tabularFigures()];

  static TextStyle display() => const TextStyle(
        fontFamily: fontFamily, fontSize: 40, height: 1.1, fontWeight: FontWeight.w600,
        letterSpacing: 1.5, color: CoveColors.text);

  static TextStyle headline() => const TextStyle(
        fontFamily: fontFamily, fontSize: 28, height: 1.15, fontWeight: FontWeight.w600,
        color: CoveColors.text);

  static TextStyle title() => const TextStyle(
        fontFamily: fontFamily, fontSize: 20, height: 1.25, fontWeight: FontWeight.w600,
        color: CoveColors.text);

  static TextStyle body() => const TextStyle(
        fontFamily: fontFamily, fontSize: 16, height: 1.45, fontWeight: FontWeight.w400,
        color: CoveColors.text);

  static TextStyle label() => const TextStyle(
        fontFamily: fontFamily, fontSize: 14, height: 1.2, fontWeight: FontWeight.w500,
        letterSpacing: 0.6, color: CoveColors.text);

  static TextStyle caption() => const TextStyle(
        fontFamily: fontFamily, fontSize: 12, height: 1.3, fontWeight: FontWeight.w500,
        letterSpacing: 0.4, color: CoveColors.textMuted);

  /// HUD numbers: tabular so counts never jitter.
  static TextStyle hud() => label().copyWith(fontFeatures: _tab);

  static TextStyle number(double size) => TextStyle(
        fontFamily: fontFamily, fontSize: size, height: 1, fontWeight: FontWeight.w600,
        color: CoveColors.text, fontFeatures: _tab);
}

/// Motion durations shared by every screen.
class CoveMotion {
  CoveMotion._();

  static const Duration page = Duration(milliseconds: 300);
  static const Duration quick = Duration(milliseconds: 180);
  static const Curve ease = Curves.easeOutCubic;

  /// The swell everything floating rocks on.
  static const double swellSeconds = 2.6;
}

/// Material fade-through: the old screen fades out, the new one fades and
/// scales in from 92 %.
class _FadeThrough extends PageTransitionsBuilder {
  const _FadeThrough();

  @override
  Widget buildTransitions<T>(PageRoute<T> route, BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation, Widget child) {
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final inCurve = CurvedAnimation(parent: animation, curve: const Interval(0.3, 1, curve: Curves.easeOutCubic));
    final outCurve = CurvedAnimation(parent: secondaryAnimation, curve: const Interval(0, 0.3));
    Widget page = FadeTransition(
      opacity: inCurve,
      child: reduce
          ? child
          : ScaleTransition(scale: Tween(begin: 0.96, end: 1.0).animate(inCurve), child: child),
    );
    return FadeTransition(opacity: Tween(begin: 1.0, end: 0.0).animate(outCurve), child: page);
  }
}

final ThemeData coveTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  fontFamily: CoveText.fontFamily,
  scaffoldBackgroundColor: CoveColors.sea,
  canvasColor: CoveColors.sea,
  colorScheme: const ColorScheme.dark(
    surface: CoveColors.sea,
    surfaceContainerHigh: CoveColors.lift,
    primary: CoveColors.beam,
    onPrimary: CoveColors.sea,
    secondary: CoveColors.harbor,
    onSecondary: CoveColors.sea,
    error: CoveColors.danger,
    onSurface: CoveColors.text,
    onSurfaceVariant: CoveColors.textMuted,
    outline: CoveColors.rule,
  ),
  textTheme: TextTheme(
    displayMedium: CoveText.display(),
    headlineMedium: CoveText.headline(),
    titleLarge: CoveText.title(),
    bodyLarge: CoveText.body(),
    bodyMedium: CoveText.body(),
    labelLarge: CoveText.label(),
    labelMedium: CoveText.hud(),
    bodySmall: CoveText.caption(),
  ),
  textSelectionTheme: const TextSelectionThemeData(
    cursorColor: CoveColors.beam,
    selectionColor: Color(0x55F4B860),
    selectionHandleColor: CoveColors.beam,
  ),
  switchTheme: SwitchThemeData(
    thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? CoveColors.sea : CoveColors.textMuted),
    trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? CoveColors.beam : CoveColors.lift),
    trackOutlineColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? CoveColors.beam : CoveColors.rule),
  ),
  dialogTheme: DialogThemeData(
    backgroundColor: CoveColors.lift,
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    titleTextStyle: CoveText.title(),
    contentTextStyle: CoveText.body().copyWith(color: CoveColors.textMuted),
  ),
  snackBarTheme: SnackBarThemeData(
    backgroundColor: CoveColors.lift,
    contentTextStyle: CoveText.label(),
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
  ),
  splashFactory: InkRipple.splashFactory,
  highlightColor: const Color(0x14F4B860),
  splashColor: const Color(0x22F4B860),
  focusColor: const Color(0x33F4B860),
  pageTransitionsTheme: const PageTransitionsTheme(builders: {
    TargetPlatform.android: _FadeThrough(),
    TargetPlatform.iOS: _FadeThrough(),
    TargetPlatform.windows: _FadeThrough(),
    TargetPlatform.linux: _FadeThrough(),
    TargetPlatform.macOS: _FadeThrough(),
    TargetPlatform.fuchsia: _FadeThrough(),
  }),
);
