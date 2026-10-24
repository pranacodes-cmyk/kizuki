import 'package:flutter/material.dart';

/// Design tokens — mirrored 1:1 from src/styles.css (:root). Components use these only.
class T {
  static const background = Color(0xFF000000);
  static const surface = Color(0xFF0D0D0D);
  static const surface2 = Color(0xFF141414);
  static const surface3 = Color(0xFF1F1F1F);
  static const border = Color(0xFF303030);
  static const foreground = Color(0xFFEDEDED);
  static const muted = Color(0xFFA3A3A3);
  static const faint = Color(0xFF737373);
  static const primary = Color(0xFFFF8A3D);
  static const primaryGlow = Color(0xFFFFB27A); // light orange: splash ripples, ring head
  static const primaryDeep = Color(0xFFC8601C);
  static const primaryDim = Color(0xFF4A3122);
  static const primaryDimFg = Color(0xFFA57A5C);
  static const primaryFg = Color(0xFF1E130B);
  static const success = Color(0xFF4CD07D);
  static const successDeep = Color(0xFF2B9A57);
  static const successSoft = Color(0xFF1C3326);
  static const danger = Color(0xFFFF6767);
  static const dangerSoft = Color(0xFF3A2124);
  static const info = Color(0xFF5DA9FF);
  static const gold = Color(0xFFFFC53D);
  static const learning = Color(0xFFFF9F5A); // word level 1
  static const level2 = Color(0xFFE58A4E);
  static const level3 = Color(0xFFBE7648);
  static const level4 = Color(0xFF93623F);
  static const known = Color(0xFF4CD07D);
  static const stage = Color(0xFF000000);
  static const googleBlue = Color(0xFF4285F4);
  static const googleGreen = Color(0xFF34A853);
  static const googleYellow = Color(0xFFFBBC05);
  static const googleRed = Color(0xFFEA4335);

  static const rSm = 8.0;
  static const rMd = 12.0;
  static const rLg = 16.0;
  static const rXl = 20.0;
  static const r2xl = 24.0;
  static const r3xl = 28.0;

  static const sans = 'Nunito';
  static const jp = 'MPLUSRounded1c';
  static const fallback = ['MPLUSRounded1c'];
}

ThemeData buildTheme() {
  const scheme = ColorScheme.dark(
    surface: T.background,
    onSurface: T.foreground,
    primary: T.primary,
    onPrimary: T.primaryFg,
    secondary: T.surface2,
    onSecondary: T.foreground,
    error: T.danger,
    onError: T.foreground,
    outline: T.border,
  );
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: T.background,
    fontFamily: T.sans,
    fontFamilyFallback: T.fallback,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: T.foreground, displayColor: T.foreground, fontFamily: T.sans, fontFamilyFallback: T.fallback),
    sliderTheme: const SliderThemeData(trackHeight: 8),
    dividerColor: T.border,
  );
}
