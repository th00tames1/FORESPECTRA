import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const _paddletailBlack = Color(0xFF1A1A1A);
  static const _basalt = Color(0xFF2D2D2D);
  static const _osuOrange = Color(0xFFD73F09);
  static const _ink = Color(0xFFFFFFFF);
  static const _muted = Color(0xFF9E9E9E);
  static const _warning = Color(0xFFFFC107);
  static const _lightSurface = Color(0xFFF8F5F2);
  static const _lightCard = Color(0xFFFFFFFF);
  static const _lightInk = Color(0xFF1C1C1C);
  static const _lightMuted = Color(0xFF6E6E6E);
  static const _lightOutline = Color(0xFFE0D7D2);

  static ThemeData get lightTheme {
    final base = ThemeData.light();
    final bodyTheme = GoogleFonts.barlowTextTheme(base.textTheme);
    final titleTheme = GoogleFonts.bitterTextTheme(base.textTheme);
    final textTheme = bodyTheme.copyWith(
      displayLarge: titleTheme.displayLarge,
      displayMedium: titleTheme.displayMedium,
      displaySmall: titleTheme.displaySmall,
      headlineLarge: titleTheme.headlineLarge,
      headlineMedium: titleTheme.headlineMedium,
      headlineSmall: titleTheme.headlineSmall,
      titleLarge: titleTheme.titleLarge,
      titleMedium: titleTheme.titleMedium,
      titleSmall: titleTheme.titleSmall,
    );
    final colorScheme = ColorScheme.light(
      primary: _osuOrange,
      secondary: _osuOrange,
      surface: _lightSurface,
      surfaceTint: _lightSurface,
      error: _warning,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: _lightInk,
      onError: Colors.black,
      outline: _lightOutline,
    );

    return ThemeData.from(
      colorScheme: colorScheme,
      textTheme: textTheme.apply(bodyColor: _lightInk, displayColor: _lightInk),
      useMaterial3: true,
    ).copyWith(
      scaffoldBackgroundColor: _lightSurface,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: _lightInk,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: const IconThemeData(color: _lightInk),
      ),
      cardTheme: CardThemeData(
        color: _lightCard,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: _lightOutline),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _osuOrange,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          side: BorderSide(color: _osuOrange),
          foregroundColor: _osuOrange,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: _lightCard,
        selectedColor: _osuOrange.withValues(alpha: 0.15),
        labelStyle: textTheme.labelLarge?.copyWith(color: _lightInk),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
    );
  }

  static ThemeData get darkTheme {
    final base = ThemeData.dark();
    final bodyTheme = GoogleFonts.barlowTextTheme(base.textTheme);
    final titleTheme = GoogleFonts.bitterTextTheme(base.textTheme);
    final textTheme = bodyTheme.copyWith(
      displayLarge: titleTheme.displayLarge,
      displayMedium: titleTheme.displayMedium,
      displaySmall: titleTheme.displaySmall,
      headlineLarge: titleTheme.headlineLarge,
      headlineMedium: titleTheme.headlineMedium,
      headlineSmall: titleTheme.headlineSmall,
      titleLarge: titleTheme.titleLarge,
      titleMedium: titleTheme.titleMedium,
      titleSmall: titleTheme.titleSmall,
    );
    final colorScheme = ColorScheme.dark(
      primary: _osuOrange,
      secondary: _osuOrange,
      surface: _basalt,
      surfaceTint: _basalt,
      error: _warning,
      onPrimary: Colors.white,
      onSecondary: Colors.black,
      onSurface: _ink,
      onError: Colors.black,
      outline: const Color(0xFF3B3B3B),
    );

    return ThemeData.from(
      colorScheme: colorScheme,
      textTheme: textTheme.apply(bodyColor: _ink, displayColor: _ink),
      useMaterial3: true,
    ).copyWith(
      scaffoldBackgroundColor: _paddletailBlack,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: _ink,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: const IconThemeData(color: _ink),
      ),
      cardTheme: CardThemeData(
        color: _basalt,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1F1F1F),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Color(0xFF3B3B3B)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _osuOrange,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFF1F1F1F),
        selectedColor: _osuOrange.withValues(alpha: 0.2),
        labelStyle: textTheme.labelLarge?.copyWith(color: _ink),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
    );
  }

  static List<Color> backgroundGradient(Brightness brightness) {
    if (brightness == Brightness.dark) {
      return [
        _paddletailBlack,
        const Color(0xFF131313),
        const Color(0xFF1B1B1B),
      ];
    }
    return [
      const Color(0xFFF5F2EF),
      const Color(0xFFF7F2EE),
      const Color(0xFFFAF6F3),
    ];
  }

  static Color get accent => _osuOrange;
  static Color get success => _osuOrange;
  static Color get warning => _warning;
  static Color get ink => _ink;
  static Color get muted => _muted;
  static Color get lightMuted => _lightMuted;
}
