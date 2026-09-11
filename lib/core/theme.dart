import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  MediLoop Design Tokens — Elevated CDSCO Compliance Palette
// ─────────────────────────────────────────────────────────────────────────────

class MediLoopColors {
  // Primary Obsidian / Slate tones
  static const Color ink = Color(0xFF0F172A);
  static const Color inkLight = Color(0xFF1E293B);
  static const Color paper = Color(0xFFF8FAFC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceElevated = Color(0xFFFFFFFF);
  static const Color line = Color(0xFFE2E8F0);
  static const Color lineLight = Color(0xFFF1F5F9);

  // Semantic Compliance Colors (CDSCO standard)
  static const Color verified = Color(0xFF059669);
  static const Color verifiedLight = Color(0xFF10B981);
  static const Color attention = Color(0xFFD97706);
  static const Color attentionLight = Color(0xFFF59E0B);
  static const Color critical = Color(0xFFDC2626);
  static const Color criticalLight = Color(0xFFEF4444);
  static const Color accent = Color(0xFF2563EB);
  static const Color accentLight = Color(0xFF3B82F6);

  // Text
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textMuted = Color(0xFF64748B);
  static const Color textSubtle = Color(0xFF94A3B8);

  // Badge backgrounds & translucent surfaces
  static const Color verifiedBg = Color(0xFFECFDF5);
  static const Color attentionBg = Color(0xFFFFFBEB);
  static const Color criticalBg = Color(0xFFFEF2F2);
  static const Color accentBg = Color(0xFFEFF6FF);
  static const Color inactiveBg = Color(0xFFF1F5F9);
}

class MediLoopRadius {
  static const double card = 14.0;
  static const double badge = 8.0;
  static const double button = 12.0;
  static const double sheet = 20.0;
}

class MediLoopSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;
}

// ─────────────────────────────────────────────────────────────────────────────
//  Shadows & Gradients
// ─────────────────────────────────────────────────────────────────────────────

class MediLoopShadows {
  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color(0x080F172A),
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
    BoxShadow(
      color: Color(0x040F172A),
      blurRadius: 1,
      offset: Offset(0, 1),
    ),
  ];

  static const List<BoxShadow> elevated = [
    BoxShadow(
      color: Color(0x100F172A),
      blurRadius: 16,
      offset: Offset(0, 6),
    ),
    BoxShadow(
      color: Color(0x060F172A),
      blurRadius: 4,
      offset: Offset(0, 2),
    ),
  ];

  static List<BoxShadow> glow(Color color, {double opacity = 0.25, double blur = 12}) => [
        BoxShadow(
          color: color.withAlpha((255 * opacity).round()),
          blurRadius: blur,
          offset: const Offset(0, 4),
        ),
      ];
}

class MediLoopGradients {
  static const LinearGradient primary = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
  );

  static const LinearGradient hero = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0F172A), Color(0xFF1E3A5F), Color(0xFF0D2538)],
  );

  static const LinearGradient verified = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [MediLoopColors.verified, MediLoopColors.verifiedLight],
  );

  static const LinearGradient attention = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [MediLoopColors.attention, MediLoopColors.attentionLight],
  );

  static const LinearGradient critical = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [MediLoopColors.critical, MediLoopColors.criticalLight],
  );

  static const LinearGradient accent = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [MediLoopColors.accent, MediLoopColors.accentLight],
  );

  static const LinearGradient laser = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Colors.transparent,
      Color(0x8010B981),
      Color(0xFF10B981),
      Color(0x8010B981),
      Colors.transparent,
    ],
    stops: [0.0, 0.45, 0.5, 0.55, 1.0],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  Text Styles
// ─────────────────────────────────────────────────────────────────────────────

class MediLoopText {
  // IBM Plex Sans — headers, labels, batch codes
  static TextStyle plexSans({
    double size = 16,
    FontWeight weight = FontWeight.w400,
    Color color = MediLoopColors.textPrimary,
    double height = 1.35,
    double letterSpacing = -0.2,
  }) =>
      GoogleFonts.ibmPlexSans(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
      );

  // Inter — body text, forms
  static TextStyle inter({
    double size = 14,
    FontWeight weight = FontWeight.w400,
    Color color = MediLoopColors.textPrimary,
    double height = 1.45,
    double letterSpacing = -0.1,
  }) =>
      GoogleFonts.inter(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
      );

  // IBM Plex Mono — batch codes, cryptographic hashes
  static TextStyle plexMono({
    double size = 13,
    FontWeight weight = FontWeight.w400,
    Color color = MediLoopColors.textMuted,
    double height = 1.4,
    double letterSpacing = 0.2,
  }) =>
      GoogleFonts.ibmPlexMono(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
      );

  // Semantic shortcuts
  static TextStyle get h1 =>
      plexSans(size: 28, weight: FontWeight.w700, height: 1.2, letterSpacing: -0.6);
  static TextStyle get h2 =>
      plexSans(size: 22, weight: FontWeight.w700, height: 1.25, letterSpacing: -0.4);
  static TextStyle get h3 =>
      plexSans(size: 18, weight: FontWeight.w600, height: 1.3, letterSpacing: -0.3);
  static TextStyle get h4 =>
      plexSans(size: 16, weight: FontWeight.w600, height: 1.3, letterSpacing: -0.2);
  static TextStyle get label =>
      plexSans(size: 14, weight: FontWeight.w600, letterSpacing: -0.1);
  static TextStyle get labelMuted =>
      plexSans(size: 14, weight: FontWeight.w500, color: MediLoopColors.textMuted);
  static TextStyle get body =>
      inter(size: 14, weight: FontWeight.w400);
  static TextStyle get bodyMuted =>
      inter(size: 14, color: MediLoopColors.textMuted);
  static TextStyle get caption =>
      inter(size: 12, color: MediLoopColors.textMuted, weight: FontWeight.w400);
  static TextStyle get batchCode =>
      plexMono(size: 13, weight: FontWeight.w500, color: MediLoopColors.ink);
  static TextStyle get hashText =>
      plexMono(size: 11, weight: FontWeight.w400, color: MediLoopColors.textMuted);
  static TextStyle get kpiNumber =>
      plexSans(size: 30, weight: FontWeight.w700, letterSpacing: -0.8);
}

// ─────────────────────────────────────────────────────────────────────────────
//  Theme Configuration
// ─────────────────────────────────────────────────────────────────────────────

ThemeData buildMediLoopTheme() {
  final colorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: MediLoopColors.ink,
    onPrimary: Colors.white,
    primaryContainer: MediLoopColors.inkLight,
    onPrimaryContainer: Colors.white,
    secondary: MediLoopColors.accent,
    onSecondary: Colors.white,
    secondaryContainer: MediLoopColors.accentBg,
    onSecondaryContainer: MediLoopColors.accent,
    tertiary: MediLoopColors.verified,
    onTertiary: Colors.white,
    tertiaryContainer: MediLoopColors.verifiedBg,
    onTertiaryContainer: MediLoopColors.verified,
    error: MediLoopColors.critical,
    onError: Colors.white,
    errorContainer: MediLoopColors.criticalBg,
    onErrorContainer: MediLoopColors.critical,
    surface: MediLoopColors.surface,
    onSurface: MediLoopColors.textPrimary,
    surfaceContainerHighest: MediLoopColors.paper,
    onSurfaceVariant: MediLoopColors.textMuted,
    outline: MediLoopColors.line,
    outlineVariant: MediLoopColors.lineLight,
    shadow: const Color(0x100F172A),
    scrim: Colors.black54,
    inverseSurface: MediLoopColors.ink,
    onInverseSurface: Colors.white,
    inversePrimary: MediLoopColors.surface,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: MediLoopColors.paper,

    // Cards — soft shadow, 14px radius, crisp outline
    cardTheme: CardThemeData(
      color: MediLoopColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MediLoopRadius.card),
        side: const BorderSide(color: MediLoopColors.line, width: 1),
      ),
      shadowColor: const Color(0x0A0F172A),
      margin: EdgeInsets.zero,
    ),

    // App Bar
    appBarTheme: AppBarTheme(
      backgroundColor: MediLoopColors.surface,
      foregroundColor: MediLoopColors.ink,
      elevation: 0,
      scrolledUnderElevation: 1,
      centerTitle: false,
      titleTextStyle: MediLoopText.h4,
      surfaceTintColor: Colors.transparent,
      shadowColor: const Color(0x0A0F172A),
      shape: const Border(
        bottom: BorderSide(color: MediLoopColors.line, width: 1),
      ),
    ),

    // Navigation Bar
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: MediLoopColors.surface,
      indicatorColor: MediLoopColors.ink.withAlpha(16),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return MediLoopText.inter(
              size: 12, weight: FontWeight.w600, color: MediLoopColors.ink);
        }
        return MediLoopText.inter(
            size: 12, color: MediLoopColors.textMuted, weight: FontWeight.w500);
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: MediLoopColors.ink, size: 23);
        }
        return const IconThemeData(color: MediLoopColors.textMuted, size: 22);
      }),
      elevation: 2,
      surfaceTintColor: Colors.transparent,
      shadowColor: const Color(0x100F172A),
      height: 68,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
    ),

    // Input Decoration
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: MediLoopColors.surface,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(MediLoopRadius.card),
        borderSide: const BorderSide(color: MediLoopColors.line, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(MediLoopRadius.card),
        borderSide: const BorderSide(color: MediLoopColors.line, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(MediLoopRadius.card),
        borderSide: const BorderSide(color: MediLoopColors.accent, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(MediLoopRadius.card),
        borderSide: const BorderSide(color: MediLoopColors.critical, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(MediLoopRadius.card),
        borderSide: const BorderSide(color: MediLoopColors.critical, width: 2),
      ),
      labelStyle: MediLoopText.inter(size: 14, color: MediLoopColors.textMuted),
      hintStyle: MediLoopText.inter(size: 14, color: MediLoopColors.textSubtle),
      errorStyle: MediLoopText.inter(size: 12, color: MediLoopColors.critical),
    ),

    // Elevated button — Obsidian/Navy with soft glow shadow
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: MediLoopColors.ink,
        foregroundColor: Colors.white,
        elevation: 0,
        padding:
            const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MediLoopRadius.button),
        ),
        textStyle: MediLoopText.inter(
            size: 14, weight: FontWeight.w600, color: Colors.white),
      ),
    ),

    // Outlined button
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: MediLoopColors.ink,
        side: const BorderSide(color: MediLoopColors.line, width: 1.5),
        padding:
            const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MediLoopRadius.button),
        ),
        textStyle: MediLoopText.inter(size: 14, weight: FontWeight.w600),
      ),
    ),

    // Text button
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: MediLoopColors.accent,
        textStyle: MediLoopText.inter(size: 14, weight: FontWeight.w600),
      ),
    ),

    // Chip
    chipTheme: ChipThemeData(
      backgroundColor: MediLoopColors.inactiveBg,
      selectedColor: MediLoopColors.ink,
      labelStyle: MediLoopText.inter(size: 13, weight: FontWeight.w500),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MediLoopRadius.badge),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    ),

    // Divider
    dividerTheme: const DividerThemeData(
      color: MediLoopColors.line,
      thickness: 1,
      space: 1,
    ),

    // Text theme
    textTheme: GoogleFonts.interTextTheme().copyWith(
      displayLarge: MediLoopText.h1,
      displayMedium: MediLoopText.h2,
      displaySmall: MediLoopText.h3,
      headlineMedium: MediLoopText.h4,
      bodyLarge: MediLoopText.body,
      bodyMedium: MediLoopText.body,
      bodySmall: MediLoopText.caption,
      labelLarge: MediLoopText.label,
      labelMedium: MediLoopText.labelMuted,
    ),
  );
}
