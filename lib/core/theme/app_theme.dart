import 'package:flutter/material.dart';

class AppTheme {
  const AppTheme._();

  // ── Core dark palette ─────────────────────────────────────────────────────
  static const Color background  = Color(0xFF0F1117); // scaffold bg
  static const Color surface     = Color(0xFF1A1D27); // cards, panels
  static const Color surfaceAlt  = Color(0xFF22263A); // inputs, chips
  static const Color border      = Color(0xFF2E3348); // dividers, borders
  static const Color ink         = Color(0xFFF0F2FF); // primary text
  static const Color muted       = Color(0xFF8891A8); // secondary text
  static const Color primary     = Color(0xFF2A3A6E); // navy primary
  static const Color primaryDark = Color(0xFF1E2B54);
  static const Color accent      = Color(0xFFFF6B1A); // orange CTA
  static const Color teal        = Color(0xFF0D9488); // teal action
  static const Color green       = Color(0xFF22C55E); // success
  static const Color amber       = Color(0xFFF59E0B); // warning
  static const Color red         = Color(0xFFEF4444); // error/danger
  static const String? fontFamily = null;
  static const List<String> fontFamilyFallback = <String>[
    '.AppleSystemUIFont',
    'SF Pro Display',
    'SF Pro Text',
    'Inter',
    'Segoe UI',
    'Roboto',
    'sans-serif',
  ];

  static ThemeData get dark {
    const colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: teal,
      onPrimary: Colors.white,
      primaryContainer: Color(0xFF0F3D39),
      onPrimaryContainer: Color(0xFF99F6E4),
      secondary: accent,
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFF5A2500),
      onSecondaryContainer: Color(0xFFFFDBCC),
      tertiary: Color(0xFF6B7FD4),
      onTertiary: Colors.white,
      error: red,
      onError: Colors.white,
      errorContainer: Color(0xFF5C1A1A),
      onErrorContainer: Color(0xFFFFCDD2),
      surface: surface,
      onSurface: ink,
      onSurfaceVariant: muted,
      outline: border,
      outlineVariant: Color(0xFF1E2235),
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: Color(0xFFE8EAED),
      onInverseSurface: Color(0xFF1A1D27),
      inversePrimary: teal,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      fontFamily: fontFamily,
      fontFamilyFallback: fontFamilyFallback,
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: background,
        foregroundColor: ink,
        iconTheme: IconThemeData(color: ink),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          color: ink,
          fontSize: 34,
          fontWeight: FontWeight.w800,
          height: 1.1,
        ),
        headlineSmall: TextStyle(
          color: ink,
          fontSize: 22,
          fontWeight: FontWeight.w800,
          height: 1.2,
        ),
        titleMedium: TextStyle(
          color: ink,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
        bodyMedium: TextStyle(
          color: muted,
          fontSize: 14,
          height: 1.5,
        ),
        bodySmall: TextStyle(
          color: muted,
          fontSize: 12,
          height: 1.4,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: surface,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: border, width: 1),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: border,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceAlt,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: teal, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: red),
        ),
        hintStyle: const TextStyle(color: muted),
        labelStyle: const TextStyle(color: muted),
        prefixIconColor: muted,
        suffixIconColor: muted,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: teal,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: teal,
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceAlt,
        selectedColor: teal.withValues(alpha: 0.22),
        labelStyle: const TextStyle(color: ink, fontSize: 13),
        side: const BorderSide(color: border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: teal,
        unselectedItemColor: muted,
        elevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: teal.withValues(alpha: 0.18),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: teal);
          }
          return const IconThemeData(color: muted);
        }),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? teal : muted),
        trackColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected)
                ? teal.withValues(alpha: 0.35)
                : surfaceAlt),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? teal : Colors.transparent),
        side: const BorderSide(color: border, width: 1.5),
      ),
      listTileTheme: const ListTileThemeData(
        tileColor: Colors.transparent,
        iconColor: muted,
        textColor: ink,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: border),
        ),
        textStyle: const TextStyle(color: ink, fontFamily: fontFamily),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceAlt,
        contentTextStyle: const TextStyle(color: ink),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: border),
        ),
        titleTextStyle: const TextStyle(
          color: ink,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          fontFamily: fontFamily,
        ),
        contentTextStyle: const TextStyle(
          color: muted,
          fontSize: 14,
          fontFamily: fontFamily,
        ),
      ),
    );
  }
}
