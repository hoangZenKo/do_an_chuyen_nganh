import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class TenantManagementTheme {
  const TenantManagementTheme._();

  static const background = Color(0xFFF8FAFC);
  static const surface = Colors.white;
  static const surfaceAlt = Color(0xFFF1F5F9);
  static const ink = Color(0xFF0F172A);
  static const muted = Color(0xFF64748B);
  static const border = Color(0xFFE2E8F0);

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
          fillColor: surfaceAlt,
          hintStyle: const TextStyle(color: muted),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
          ),
        ),
        dialogTheme: const DialogThemeData(
          backgroundColor: surface,
          surfaceTintColor: Colors.transparent,
        ),
      );
}
