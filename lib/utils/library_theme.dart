import 'package:flutter/material.dart';

import 'constants.dart';

ThemeData libraryTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final paper = dark ? AppColors.backgroundDark : AppColors.backgroundLight;
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    brightness: brightness,
    primary: dark ? const Color(0xFFC5CBFF) : AppColors.primary,
    surface: dark ? AppColors.surfaceDark : AppColors.surfaceLight,
    tertiaryContainer: dark ? const Color(0xFF21493D) : const Color(0xFFDAECE2),
    onTertiaryContainer: dark
        ? const Color(0xFFB6E8D1)
        : const Color(0xFF234A39),
    outlineVariant: dark ? AppColors.borderDark : AppColors.borderLight,
  );
  final base = ThemeData(colorScheme: scheme, scaffoldBackgroundColor: paper);
  final rounded = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(16),
  );
  final field = OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: BorderSide(color: scheme.outlineVariant),
  );
  return base.copyWith(
    textTheme: base.textTheme.copyWith(
      displaySmall: base.textTheme.displaySmall?.copyWith(
        fontFamily: 'Georgia',
        fontFamilyFallback: const ['serif', 'Roboto', 'Segoe UI'],
        height: 1.12,
      ),
      headlineSmall: base.textTheme.headlineSmall?.copyWith(
        fontFamily: 'Georgia',
        fontFamilyFallback: const ['serif', 'Roboto', 'Segoe UI'],
        fontWeight: FontWeight.w600,
      ),
      titleLarge: base.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
      ),
      titleMedium: base.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: paper,
      foregroundColor: scheme.onSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: scheme.surface,
      shape: rounded.copyWith(side: BorderSide(color: scheme.outlineVariant)),
      clipBehavior: Clip.antiAlias,
    ),
    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      fillColor: scheme.surface,
      border: field,
      enabledBorder: field,
      focusedBorder: field.copyWith(
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: rounded,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: rounded,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surface,
      indicatorColor: scheme.primaryContainer,
      elevation: 0,
      height: 72,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surface,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}
