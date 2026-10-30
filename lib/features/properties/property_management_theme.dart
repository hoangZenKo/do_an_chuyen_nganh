import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class PropertyManagementTheme {
  const PropertyManagementTheme._();

  static const background = Color(0xFFF8FAFC);
  static const surface = Colors.white;
  static const surfaceAlt = Color(0xFFF1F5F9);
  static const ink = Color(0xFF0F172A);
  static const muted = Color(0xFF475569);
  static const border = Color(0xFFE2E8F0);
  static const error = Color(0xFFB91C1C);

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        fontFamily: AppTheme.fontFamily,
        fontFamilyFallback: AppTheme.fontFamilyFallback,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppTheme.primary,
          brightness: Brightness.light,
        ).copyWith(
          primary: AppTheme.primary,
          onPrimary: Colors.white,
          surface: surface,
          onSurface: ink,
          onSurfaceVariant: muted,
          outline: muted,
          outlineVariant: border,
          error: error,
        ),
        scaffoldBackgroundColor: background,
        appBarTheme: const AppBarTheme(
          backgroundColor: surface,
          foregroundColor: ink,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: surface,
          hintStyle: const TextStyle(color: muted),
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
            borderSide: const BorderSide(color: AppTheme.primary, width: 1.8),
          ),
        ),
        dialogTheme: const DialogThemeData(
          backgroundColor: surface,
          surfaceTintColor: Colors.transparent,
        ),
        popupMenuTheme: const PopupMenuThemeData(
          color: surface,
          surfaceTintColor: Colors.transparent,
        ),
      );
}
