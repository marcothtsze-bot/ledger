import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design tokens transcribed from the Ledger handoff. One source of truth for
/// colour, type, radii, shadow and motion so nothing is hardcoded ad hoc.

class AppColors {
  AppColors._();

  // Surfaces
  static const screen = Color(0xFF0D1814); // device screen / app bg
  static const sheet = Color(0xFF101D18); // sheets & overlays
  static const card = Color(0xFF15211C); // cards / rows
  static const keypad = Color(0xFF1A2823); // deep input / keys
  static const deep = Color(0xFF0A1511); // deepest input surface

  // Text
  static const text = Color(0xFFEEF3F0);
  static const muted = Color(0xFF8A958F);
  static const mutedLight = Color(0xFFC4CCC7);
  static const mutedNet = Color(0xFF9AA6A1);
  static const idleTab = Color(0xFF5C6863);

  // Brand / semantic
  static const brand = Color(0xFF3AD29F);
  static const onBrand = Color(0xFF06160F);
  static const onBrandDeep = Color(0xFF04130D);
  static const softGreen = Color(0xFF9AF0D2);
  static const softGreen2 = Color(0xFF8AEFC6);
  static const expense = Color(0xFFFF7A6B);
  static const expenseMuted = Color(0xFFF0998C);
  static const amber = Color(0xFFF0A23A); // utilisation bars

  // Hairlines
  static Color get hairline => Colors.white.withValues(alpha: 0.07);
  static Color get hairlineSoft => Colors.white.withValues(alpha: 0.06);
  static Color get hairlineStrong => Colors.white.withValues(alpha: 0.10);

  /// Home header backdrop — radial green wash fading to the screen colour.
  static const homeHeaderGradient = RadialGradient(
    center: Alignment(-0.7, -1.0),
    radius: 1.25,
    colors: [Color(0xFF2A8466), Color(0x80185644), screen],
    stops: [0.0, 0.44, 0.80],
  );
}

class AppRadii {
  AppRadii._();
  static const card = 16.0;
  static const statCard = 22.0;
  static const sheet = 30.0;
  static const device = 47.0;
  static const bezel = 58.0;
  static const key = 14.0;
  static const field = 13.0;
  static const tileSmall = 9.0;
  static const tileMed = 13.0;
  static const pill = 999.0;
}

class AppShadows {
  AppShadows._();
  static const primaryButton = [
    BoxShadow(
      color: Color(0x803AD29F),
      blurRadius: 20,
      offset: Offset(0, 8),
      spreadRadius: -6,
    ),
  ];
  static const fab = [
    BoxShadow(
      color: Color(0x8C3AD29F),
      blurRadius: 22,
      offset: Offset(0, 8),
      spreadRadius: -4,
    ),
  ];
  static const toast = [
    BoxShadow(
      color: Color(0x993AD29F),
      blurRadius: 26,
      offset: Offset(0, 10),
      spreadRadius: -8,
    ),
  ];
  static const device = [
    BoxShadow(
      color: Color(0x8C000000),
      blurRadius: 90,
      offset: Offset(0, 40),
      spreadRadius: -25,
    ),
  ];
}

class AppDurations {
  AppDurations._();
  static const sheet = Duration(milliseconds: 260);
  static const picker = Duration(milliseconds: 220);
  static const fade = Duration(milliseconds: 190);
  static const toast = Duration(milliseconds: 1900);
  static const countUp = Duration(milliseconds: 950);
  static const easeOutExpo = Cubic(0.22, 1, 0.36, 1);
}

/// Typography helpers. Hanken Grotesk for UI, IBM Plex Mono for every money
/// figure. (For production these should be bundled as assets; google_fonts
/// fetches them at runtime here.)
class AppText {
  AppText._();

  static TextStyle ui(
    double size,
    FontWeight weight, {
    Color color = AppColors.text,
    double? spacing,
    double? height,
  }) => GoogleFonts.hankenGrotesk(
    fontSize: size,
    fontWeight: weight,
    color: color,
    letterSpacing: spacing,
    height: height,
  );

  static TextStyle mono(
    double size,
    FontWeight weight, {
    Color color = AppColors.text,
    double? spacing,
  }) => GoogleFonts.ibmPlexMono(
    fontSize: size,
    fontWeight: weight,
    color: color,
    letterSpacing: spacing,
  );

  // Common named styles
  static TextStyle get screenTitle => ui(28, FontWeight.w800, spacing: -0.5);
  static TextStyle get sectionHeader => ui(16, FontWeight.w700);
  static TextStyle get cardTitle => ui(14, FontWeight.w600);
  static TextStyle get muted12 =>
      ui(12, FontWeight.w400, color: AppColors.muted);
  static TextStyle eyebrow({Color color = AppColors.muted}) =>
      ui(11, FontWeight.w700, color: color, spacing: 1.4);
  static TextStyle get heroNetWorth => mono(45, FontWeight.w600, spacing: -1.1);
  static TextStyle get keypadAmount => mono(42, FontWeight.w600, spacing: -0.9);
  static TextStyle get money => mono(15, FontWeight.w600);
}

/// Builds the app-wide dark theme.
ThemeData buildLedgerTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.screen,
    colorScheme: base.colorScheme.copyWith(
      primary: AppColors.brand,
      surface: AppColors.card,
      onPrimary: AppColors.onBrand,
    ),
    textTheme: GoogleFonts.hankenGroteskTextTheme(
      base.textTheme,
    ).apply(bodyColor: AppColors.text, displayColor: AppColors.text),
    splashFactory: InkRipple.splashFactory,
  );
}
