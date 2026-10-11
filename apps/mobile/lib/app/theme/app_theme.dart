import 'package:flutter/material.dart';

import 'app_spacing.dart';

/// Material 3 light and dark themes built from a single brand seed colour.
abstract final class AppTheme {
  static const Color seed = Color(0xFF1E6B8F);

  static ThemeData light() => _build(ColorScheme.fromSeed(seedColor: seed));

  static ThemeData dark() =>
      _build(ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark));

  static ThemeData _build(ColorScheme colors) {
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(16));
    return ThemeData(
      colorScheme: colors,
      visualDensity: VisualDensity.standard,
      scaffoldBackgroundColor: colors.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: colors.surface,
        foregroundColor: colors.onSurface,
        centerTitle: false,
        scrolledUnderElevation: 1,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: colors.surfaceContainerLow,
        shape: shape,
        margin: EdgeInsets.zero,
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
      ),
      navigationBarTheme: NavigationBarThemeData(indicatorColor: colors.secondaryContainer),
    );
  }
}
