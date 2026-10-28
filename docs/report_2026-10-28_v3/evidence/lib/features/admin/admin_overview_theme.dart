import 'package:flutter/material.dart';

class AdminOverviewTheme {
  static const blue = Color(0xFF345DFA);
  static const ink = Color(0xFF15213D);
  static const muted = Color(0xFF5E6C87);
  static const background = Color(0xFFF3F6FD);
  static const line = Color(0xFFE5EBF5);
  static const green = Color(0xFF087B57);
  static const red = Color(0xFFC5364C);
  static const amber = Color(0xFF946200);
  static const surface = Colors.white;

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme:
            ColorScheme.fromSeed(seedColor: blue, brightness: Brightness.light)
                .copyWith(
                    primary: blue,
                    onPrimary: Colors.white,
                    surface: Colors.white,
                    onSurface: ink,
                    onSurfaceVariant: muted,
                    error: red),
        scaffoldBackgroundColor: background,
        textTheme: const TextTheme(
          headlineMedium: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: ink,
              height: 1.2),
          headlineSmall: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: ink,
              height: 1.2),
          titleLarge:
              TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: ink),
          titleMedium:
              TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: ink),
          bodyLarge: TextStyle(fontSize: 16, color: ink, height: 1.45),
          bodyMedium: TextStyle(fontSize: 14, color: ink, height: 1.45),
          bodySmall: TextStyle(fontSize: 12, color: muted, height: 1.4),
          labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        appBarTheme: const AppBarTheme(
            backgroundColor: background,
            foregroundColor: ink,
            elevation: 0,
            scrolledUnderElevation: 0,
            centerTitle: false),
        dividerTheme: const DividerThemeData(color: line, thickness: 1),
        cardTheme: CardThemeData(
            color: surface,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: line))),
        iconButtonTheme: IconButtonThemeData(
            style: IconButton.styleFrom(
                foregroundColor: muted, minimumSize: const Size(44, 44))),
        filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
                minimumSize: const Size(44, 44),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)))),
        outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
                minimumSize: const Size(44, 44),
                side: const BorderSide(color: line),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)))),
        inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: surface,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: line)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: line)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: blue, width: 1.5)),
            errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: red)),
            focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: red, width: 1.5)),
            labelStyle: const TextStyle(color: muted),
            hintStyle: const TextStyle(color: muted)),
        dialogTheme: DialogThemeData(
            backgroundColor: surface,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: line)),
            titleTextStyle: const TextStyle(
                color: ink, fontSize: 18, fontWeight: FontWeight.w700),
            contentTextStyle: const TextStyle(color: muted, fontSize: 14)),
        navigationBarTheme: NavigationBarThemeData(
            backgroundColor: Colors.white,
            indicatorColor: const Color(0xFFEBF0FF),
            height: 70,
            iconTheme: WidgetStateProperty.resolveWith((states) =>
                IconThemeData(
                    color: states.contains(WidgetState.selected) ? blue : muted,
                    size: 22)),
            labelTextStyle: WidgetStateProperty.resolveWith((states) =>
                TextStyle(
                    fontSize: 11,
                    fontWeight: states.contains(WidgetState.selected)
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color:
                        states.contains(WidgetState.selected) ? blue : muted))),
      );
}
