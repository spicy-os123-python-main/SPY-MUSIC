import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/theme_controller.dart';

class SpyThemeConfig {
  final ThemeType type;
  final String id;
  final String name;
  final Color bg;
  final Color fg;
  final Color muted;
  final Color accent;
  final Color onAccent;
  final Color c1;
  final Color c2;
  final Color c3;
  final double radius;
  final bool isFlame;
  final bool isGlass;
  final bool isWarp;
  final bool isSignal;
  final bool isLight;
  final Color? bgGlow;
  final Color? flameOuter;
  final Color? flameMid;
  final Color? flameCore;
  final Color? flameHot;
  final Color? glassFill;
  final Color? glassBorder;
  final Color? glassHighlight;
  final Color? glassInnerShade;
  final Color? glassDropShadow;
  final Color? glassActiveTab;
  final List<Color>? glassBlobs;
  final Color? cardColor;
  final Color? lineColor;
  final String enterAnimation;

  const SpyThemeConfig({
    required this.type,
    required this.id,
    required this.name,
    required this.bg,
    required this.fg,
    required this.muted,
    required this.accent,
    required this.onAccent,
    required this.c1,
    required this.c2,
    required this.c3,
    required this.radius,
    this.isFlame = false,
    this.isGlass = false,
    this.isWarp = false,
    this.isSignal = false,
    this.isLight = false,
    this.bgGlow,
    this.flameOuter,
    this.flameMid,
    this.flameCore,
    this.flameHot,
    this.glassFill,
    this.glassBorder,
    this.glassHighlight,
    this.glassInnerShade,
    this.glassDropShadow,
    this.glassActiveTab,
    this.glassBlobs,
    this.cardColor,
    this.lineColor,
    required this.enterAnimation,
  });

  TextTheme createTextTheme(BuildContext? context) {
    TextTheme base = TextTheme(
      displayLarge:
          TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: fg),
      displayMedium:
          TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: fg),
      displaySmall:
          TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: fg),
      headlineLarge:
          TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: fg),
      headlineMedium:
          TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: fg),
      headlineSmall:
          TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: fg),
      titleLarge:
          TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: fg),
      titleMedium:
          TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: fg),
      titleSmall:
          TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: muted),
      bodyLarge: TextStyle(fontSize: 16, color: fg),
      bodyMedium: TextStyle(fontSize: 14, color: muted),
      bodySmall: TextStyle(fontSize: 12, color: muted),
      labelLarge:
          TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: fg),
      labelMedium:
          TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: fg),
      labelSmall:
          TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: muted),
    );

    TextTheme result;
    if (isSignal) {
      result = GoogleFonts.spaceMonoTextTheme(base);
    } else if (isWarp) {
      final bodyTheme = GoogleFonts.spaceGroteskTextTheme(base);
      result = bodyTheme.copyWith(
        titleLarge: GoogleFonts.unbounded(
          textStyle: bodyTheme.titleLarge?.copyWith(letterSpacing: 0.8),
        ),
        titleMedium: GoogleFonts.unbounded(
          textStyle: bodyTheme.titleMedium?.copyWith(letterSpacing: 0.5),
        ),
        labelMedium: GoogleFonts.unbounded(
          textStyle: bodyTheme.labelMedium?.copyWith(letterSpacing: 0.5),
        ),
      );
    } else {
      result = GoogleFonts.bricolageGrotesqueTextTheme(base);
    }

    return result.apply(
      bodyColor: fg,
      displayColor: fg,
      decorationColor: fg,
    );
  }

  ThemeData createThemeData() {
    final textTheme = createTextTheme(null);
    final brightness = isLight ? Brightness.light : Brightness.dark;

    return ThemeData(
      useMaterial3: false,
      brightness: brightness,
      primaryColor: accent,
      scaffoldBackgroundColor: bg,
      canvasColor: bg,
      cardColor: cardColor ?? bg,
      dialogBackgroundColor: cardColor ?? bg,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: accent,
        onPrimary: onAccent,
        secondary: accent,
        onSecondary: onAccent,
        error: Colors.redAccent,
        onError: Colors.white,
        surface: cardColor ?? bg,
        onSurface: fg,
      ),
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      cardTheme: CardTheme(
        color: cardColor ?? bg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: BorderSide(
              color: lineColor ?? muted.withOpacity(0.2), width: 1.0),
        ),
      ),
      dialogTheme: DialogTheme(
        backgroundColor: cardColor ?? bg,
        titleTextStyle:
            TextStyle(color: fg, fontSize: 18, fontWeight: FontWeight.bold),
        contentTextStyle: TextStyle(color: fg, fontSize: 14),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: cardColor ?? bg,
        modalBarrierColor: Colors.black.withOpacity(0.6),
      ),
      listTileTheme: ListTileThemeData(
        textColor: fg,
        iconColor: accent,
      ),
      iconTheme: IconThemeData(
        color: fg,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        foregroundColor: fg,
        elevation: 0,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: accent,
        linearTrackColor: lineColor ?? muted.withOpacity(0.3),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: accent,
        inactiveTrackColor: lineColor ?? muted.withOpacity(0.3),
        thumbColor: accent,
        valueIndicatorColor: cardColor ?? bg,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: bg,
        selectedIconTheme: IconThemeData(color: accent),
        unselectedIconTheme: IconThemeData(color: muted),
        selectedLabelTextStyle:
            TextStyle(color: fg, fontWeight: FontWeight.bold),
        unselectedLabelTextStyle: TextStyle(color: muted),
      ),
      dividerColor: lineColor ?? muted.withOpacity(0.2),
    );
  }
}

class AppThemes {
  static const emberGlass = SpyThemeConfig(
    type: ThemeType.emberGlass,
    id: 'ember',
    name: 'Ember Glass',
    bg: Color(0xFF0B0302),
    fg: Color(0xFFFFF4EA),
    muted: Color(0xFFE0AD92),
    accent: Color(0xFFFF8A1F),
    onAccent: Color(0xFF2A0A00),
    c1: Color(0xFFFF8A1F),
    c2: Color(0xFFFFD000),
    c3: Color(0xFFFF3D00),
    radius: 30.0,
    isFlame: true,
    isGlass: true,
    flameOuter: Color(0xFFFF3D00),
    flameMid: Color(0xFFFF8A00),
    flameCore: Color(0xFFFFD000),
    flameHot: Color(0xFFFFFBD0),
    bgGlow: Color(0xFF5A0F00),
    glassFill: Color(0x1AFFFFFF),
    glassBorder: Color(0x61FFCDA0),
    glassHighlight: Color(0x80FFFFFF),
    glassInnerShade: Color(0x24FF7828),
    glassDropShadow: Color(0x73000000),
    glassActiveTab: Color(0x3DFFFFFF),
    lineColor: Color(0x29FFFFFF),
    cardColor: Color(0xF2160704),
    enterAnimation: 'ignite',
  );

  static const inferno = SpyThemeConfig(
    type: ThemeType.inferno,
    id: 'inferno',
    name: 'Inferno',
    bg: Color(0xFF0B0302),
    fg: Color(0xFFFFF1E6),
    muted: Color(0xFFB88F7C),
    accent: Color(0xFFFF6A00),
    onAccent: Color(0xFF1A0500),
    c1: Color(0xFFFF6A00),
    c2: Color(0xFFFFD000),
    c3: Color(0xFFB01E00),
    radius: 16.0,
    isFlame: true,
    flameOuter: Color(0xFFFF3D00),
    flameMid: Color(0xFFFF8A00),
    flameCore: Color(0xFFFFD000),
    flameHot: Color(0xFFFFFBD0),
    bgGlow: Color(0xFF5A0F00),
    cardColor: Color(0xF51A0702),
    lineColor: Color(0x4DFF6A00),
    enterAnimation: 'ignite',
  );

  static const blueFlame = SpyThemeConfig(
    type: ThemeType.blueFlame,
    id: 'blue',
    name: 'Blue Flame',
    bg: Color(0xFF02060F),
    fg: Color(0xFFEAF4FF),
    muted: Color(0xFF7FA0C8),
    accent: Color(0xFF2B8CFF),
    onAccent: Color(0xFF02101F),
    c1: Color(0xFF2B8CFF),
    c2: Color(0xFF7FE3FF),
    c3: Color(0xFF0A3CFF),
    radius: 16.0,
    isFlame: true,
    flameOuter: Color(0xFF0A3CFF),
    flameMid: Color(0xFF2B8CFF),
    flameCore: Color(0xFF7FE3FF),
    flameHot: Color(0xFFFFFFFF),
    bgGlow: Color(0xFF00225E),
    cardColor: Color(0xF5061226),
    lineColor: Color(0x573C8CFF),
    enterAnimation: 'ignite',
  );

  static const liquidGlass = SpyThemeConfig(
    type: ThemeType.liquidGlass,
    id: 'glass',
    name: 'Liquid Glass',
    bg: Color(0xFFDFE9FF),
    fg: Color(0xFF0F1F3D),
    muted: Color(0xFF5A6F94),
    accent: Color(0xFF2F7BFF),
    onAccent: Color(0xFFFFFFFF),
    c1: Color(0xFF2F7BFF),
    c2: Color(0xFFFF7AB6),
    c3: Color(0xFFFFB36B),
    radius: 30.0,
    isGlass: true,
    isLight: true,
    glassFill: Color(0x80FFFFFF),
    glassBorder: Color(0xE6FFFFFF),
    glassHighlight: Color(0xFFFFFFFF),
    glassInnerShade: Color(0x2978A0FF),
    glassDropShadow: Color(0x331E3C8C),
    glassActiveTab: Color(0xE6FFFFFF),
    glassBlobs: [Color(0xFFFF7AB6), Color(0xFF5AB0FF), Color(0xFFFFB36B)],
    lineColor: Color(0x1F0F1F3D),
    cardColor: Color(0xF5F0F5FF),
    enterAnimation: 'surf',
  );

  static const glassNight = SpyThemeConfig(
    type: ThemeType.glassNight,
    id: 'glassd',
    name: 'Glass Night',
    bg: Color(0xFF05060D),
    fg: Color(0xFFF2F5FF),
    muted: Color(0xFF8F9AC0),
    accent: Color(0xFF6EA8FF),
    onAccent: Color(0xFF05060D),
    c1: Color(0xFF4F8BFF),
    c2: Color(0xFF00D4D0),
    c3: Color(0xFFC13CFF),
    radius: 30.0,
    isGlass: true,
    glassFill: Color(0x33FFFFFF),
    glassBorder: Color(0x4DFFFFFF),
    glassHighlight: Color(0x73FFFFFF),
    glassInnerShade: Color(0x1A788CFF),
    glassDropShadow: Color(0x8C000000),
    glassActiveTab: Color(0x38FFFFFF),
    glassBlobs: [Color(0xFF2A5BFF), Color(0xFF00C2C7), Color(0xFFC13CFF)],
    lineColor: Color(0x1FFFFFFF),
    cardColor: Color(0xF50A0E1C),
    enterAnimation: 'surf',
  );

  static const warp = SpyThemeConfig(
    type: ThemeType.warp,
    id: 'warp',
    name: 'Warp',
    bg: Color(0xFF02030A),
    fg: Color(0xFFEAF6FF),
    muted: Color(0xFF6F86A6),
    accent: Color(0xFF00F0FF),
    onAccent: Color(0xFF02030A),
    c1: Color(0xFF00F0FF),
    c2: Color(0xFFFF2E93),
    c3: Color(0xFFFFFFFF),
    radius: 14.0,
    isWarp: true,
    cardColor: Color(0xF5081026),
    lineColor: Color(0x3800F0FF),
    enterAnimation: 'warpin',
  );

  static const signal = SpyThemeConfig(
    type: ThemeType.signal,
    id: 'signal',
    name: 'Signal',
    bg: Color(0xFF050607),
    fg: Color(0xFFD6F5E4),
    muted: Color(0xFF5D7068),
    accent: Color(0xFFB8FF3C),
    onAccent: Color(0xFF050607),
    c1: Color(0xFFB8FF3C),
    c2: Color(0xFF0F1A14),
    c3: Color(0xFF2FD6A0),
    radius: 0.0,
    isSignal: true,
    cardColor: Color(0xFF0A0D0C),
    lineColor: Color(0x29B8FF3C),
    enterAnimation: 'scan',
  );

  static const List<SpyThemeConfig> allCustomThemes = [
    emberGlass,
    inferno,
    blueFlame,
    liquidGlass,
    glassNight,
    warp,
    signal,
  ];

  static SpyThemeConfig? fromType(ThemeType type) {
    switch (type) {
      case ThemeType.emberGlass:
        return emberGlass;
      case ThemeType.inferno:
        return inferno;
      case ThemeType.blueFlame:
        return blueFlame;
      case ThemeType.liquidGlass:
        return liquidGlass;
      case ThemeType.glassNight:
        return glassNight;
      case ThemeType.warp:
        return warp;
      case ThemeType.signal:
        return signal;
      default:
        return null;
    }
  }

  static bool isCustomTheme(ThemeType type) {
    return fromType(type) != null;
  }
}

