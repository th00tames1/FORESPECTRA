import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Brand
  static const _osuOrange = Color(0xFFD73F09);
  static const _osuOrangePressed = Color(0xFFB13407);

  // Light (Notion-inspired)
  static const _canvasLight = Color(0xFFFFFFFF);
  static const _surfaceLight = Color(0xFFF7F7F5);
  static const _surfaceSoftLight = Color(0xFFFBFBFA);
  static const _navSurfaceLight = Color(0xFFFFFFFF);
  static const _hairlineLight = Color(0xFFEBEBEA);
  static const _hairlineStrongLight = Color(0xFFE0E0DE);
  static const _inkLight = Color(0xFF37352F);
  static const _slateLight = Color(0xFF6F6E69);
  static const _stoneLight = Color(0xFF9B9A97);

  // Dark (softer than before)
  static const _canvasDark = Color(0xFF1F1E1C);
  static const _surfaceDark = Color(0xFF2A2926);
  static const _scaffoldDark = Color(0xFF191816);
  static const _hairlineDark = Color(0xFF3A3936);
  static const _inkDark = Color(0xFFEDEBE6);
  static const _slateDark = Color(0xFFB0AFAB);

  // Pastel tints (Notion feature card palette)
  static const tintPeach = Color(0xFFFDEBDD);
  static const tintRose = Color(0xFFFBE4E4);
  static const tintMint = Color(0xFFDCEFDC);
  static const tintLavender = Color(0xFFE8E0F2);
  static const tintSky = Color(0xFFDDEBF7);
  static const tintYellow = Color(0xFFFAF3D9);

  // Semantic
  static const _warning = Color(0xFFC97A0F);
  static const _success = Color(0xFF16A34A);

  static ThemeData get lightTheme {
    final base = ThemeData.light();
    final bodyTheme = GoogleFonts.interTextTheme(base.textTheme);
    final titleTheme = GoogleFonts.interTextTheme(base.textTheme);
    final textTheme = bodyTheme.copyWith(
      displayLarge: titleTheme.displayLarge?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -1.2),
      displayMedium: titleTheme.displayMedium?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -0.8),
      displaySmall: titleTheme.displaySmall?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -0.5),
      headlineLarge: titleTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -0.5),
      headlineMedium: titleTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -0.3),
      headlineSmall: titleTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
      titleLarge: titleTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
      titleMedium: titleTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      titleSmall: titleTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
    );
    final colorScheme = ColorScheme.light(
      primary: _osuOrange,
      secondary: _osuOrange,
      surface: _canvasLight,
      surfaceTint: _canvasLight,
      surfaceContainerHighest: _surfaceLight,
      surfaceContainer: _surfaceSoftLight,
      error: _warning,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: _inkLight,
      onSurfaceVariant: _slateLight,
      onError: Colors.white,
      outline: _hairlineLight,
      outlineVariant: _hairlineLight,
    );

    return ThemeData.from(
      colorScheme: colorScheme,
      textTheme: textTheme.apply(bodyColor: _inkLight, displayColor: _inkLight),
      useMaterial3: true,
    ).copyWith(
      scaffoldBackgroundColor: _canvasLight,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: _inkLight,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: const IconThemeData(color: _inkLight),
      ),
      cardTheme: CardThemeData(
        color: _canvasLight,
        surfaceTintColor: Colors.transparent,
        shadowColor: const Color(0x140F0F0F),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: _hairlineLight),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: const DividerThemeData(
        color: _hairlineLight,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _canvasLight,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _hairlineStrongLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _hairlineStrongLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _osuOrange, width: 1.5),
        ),
        labelStyle: textTheme.bodySmall?.copyWith(color: _slateLight),
        hintStyle: textTheme.bodyMedium?.copyWith(color: _stoneLight),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _osuOrange,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          side: const BorderSide(color: _hairlineStrongLight),
          foregroundColor: _inkLight,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w500),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _osuOrange,
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w500),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: _surfaceLight,
        selectedColor: _osuOrange.withValues(alpha: 0.12),
        labelStyle: textTheme.labelLarge?.copyWith(color: _inkLight),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        side: const BorderSide(color: _hairlineLight),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: _osuOrange,
        inactiveTrackColor: _hairlineLight,
        thumbColor: _osuOrange,
        overlayColor: _osuOrange.withValues(alpha: 0.12),
        valueIndicatorColor: _inkLight,
        valueIndicatorTextStyle: textTheme.labelSmall?.copyWith(color: Colors.white),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: _navSurfaceLight,
        surfaceTintColor: Colors.transparent,
        indicatorColor: _osuOrange.withValues(alpha: 0.12),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final base = textTheme.labelSmall;
          if (states.contains(WidgetState.disabled)) {
            return base?.copyWith(color: _stoneLight);
          }
          if (states.contains(WidgetState.selected)) {
            return base?.copyWith(color: _osuOrange, fontWeight: FontWeight.w600);
          }
          return base?.copyWith(color: _slateLight);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return const IconThemeData(color: _stoneLight);
          }
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: _osuOrange);
          }
          return const IconThemeData(color: _slateLight);
        }),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: _inkLight,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: _canvasLight,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: _canvasLight,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  static ThemeData get darkTheme {
    final base = ThemeData.dark();
    final bodyTheme = GoogleFonts.interTextTheme(base.textTheme);
    final titleTheme = GoogleFonts.interTextTheme(base.textTheme);
    final textTheme = bodyTheme.copyWith(
      displayLarge: titleTheme.displayLarge?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -1.2),
      displayMedium: titleTheme.displayMedium?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -0.8),
      displaySmall: titleTheme.displaySmall?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -0.5),
      headlineLarge: titleTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -0.5),
      headlineMedium: titleTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -0.3),
      headlineSmall: titleTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
      titleLarge: titleTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
      titleMedium: titleTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      titleSmall: titleTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
    );
    final colorScheme = ColorScheme.dark(
      primary: _osuOrange,
      secondary: _osuOrange,
      surface: _canvasDark,
      surfaceTint: _canvasDark,
      surfaceContainerHighest: _surfaceDark,
      error: _warning,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: _inkDark,
      onSurfaceVariant: _slateDark,
      onError: Colors.black,
      outline: _hairlineDark,
      outlineVariant: _hairlineDark,
    );

    return ThemeData.from(
      colorScheme: colorScheme,
      textTheme: textTheme.apply(bodyColor: _inkDark, displayColor: _inkDark),
      useMaterial3: true,
    ).copyWith(
      scaffoldBackgroundColor: _scaffoldDark,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: _inkDark,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: const IconThemeData(color: _inkDark),
      ),
      cardTheme: CardThemeData(
        color: _canvasDark,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: _hairlineDark),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: const DividerThemeData(
        color: _hairlineDark,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _surfaceDark,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _hairlineDark),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _hairlineDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _osuOrange, width: 1.5),
        ),
        labelStyle: textTheme.bodySmall?.copyWith(color: _slateDark),
        hintStyle: textTheme.bodyMedium?.copyWith(color: _slateDark),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _osuOrange,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          side: const BorderSide(color: _hairlineDark),
          foregroundColor: _inkDark,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w500),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _osuOrange,
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w500),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: _surfaceDark,
        selectedColor: _osuOrange.withValues(alpha: 0.18),
        labelStyle: textTheme.labelLarge?.copyWith(color: _inkDark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        side: const BorderSide(color: _hairlineDark),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: _osuOrange,
        inactiveTrackColor: _hairlineDark,
        thumbColor: _osuOrange,
        overlayColor: _osuOrange.withValues(alpha: 0.18),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: _canvasDark,
        surfaceTintColor: Colors.transparent,
        indicatorColor: _osuOrange.withValues(alpha: 0.16),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final base = textTheme.labelSmall;
          if (states.contains(WidgetState.disabled)) {
            return base?.copyWith(color: _slateDark);
          }
          if (states.contains(WidgetState.selected)) {
            return base?.copyWith(color: _osuOrange, fontWeight: FontWeight.w600);
          }
          return base?.copyWith(color: _slateDark);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return IconThemeData(color: _slateDark);
          }
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: _osuOrange);
          }
          return IconThemeData(color: _slateDark);
        }),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: _inkDark,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: _scaffoldDark),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: _canvasDark,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: _canvasDark,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  static List<Color> backgroundGradient(Brightness brightness) {
    if (brightness == Brightness.dark) {
      return const [
        _scaffoldDark,
        Color(0xFF1B1A18),
        Color(0xFF1F1E1C),
      ];
    }
    return const [
      _canvasLight,
      Color(0xFFFAFAF8),
      _surfaceLight,
    ];
  }

  // Static accessors used by screens. Values chosen to read well on both themes.
  static Color get accent => _osuOrange;
  static Color get accentPressed => _osuOrangePressed;
  static Color get success => _success;
  static Color get warning => _warning;
  static Color get muted => _slateLight;
  static Color get ink => _inkLight;
  static Color get lightMuted => _stoneLight;
}
