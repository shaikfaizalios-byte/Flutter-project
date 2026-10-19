import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

import 'app_spacing.dart';

/// Material 3 light and dark themes: a deep ink-indigo brand on a warm paper ground, white
/// cards edged by a hairline instead of shadows, and one shared set of radii and control sizes.
abstract final class AppTheme {
  static const Color seed = Color(0xFF283C8C);

  /// Bundled font used for characters the primary font lacks (Devanagari),
  /// so Hindi renders without network access (see pubspec.yaml).
  static const fontFallback = ['NotoSansDevanagari'];

  /// Bundled (see pubspec.yaml): the web app loads no fonts from Google's servers.
  static const fontFamily = 'Roboto';

  static ThemeData light() => _build(
    ColorScheme.fromSeed(
      seedColor: seed,
      dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
    ).copyWith(
      primary: seed,
      surface: const Color(0xFFF7F5F0),
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: Colors.white,
      surfaceContainer: const Color(0xFFF1EEE7),
      surfaceContainerHigh: const Color(0xFFEBE7DF),
      surfaceContainerHighest: const Color(0xFFE4E0D7),
      outlineVariant: const Color(0xFFE2DED4),
    ),
  );

  static ThemeData dark() => _build(
    ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.dark,
      dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
    ).copyWith(
      surface: const Color(0xFF111319),
      surfaceContainerLowest: const Color(0xFF0C0E13),
      surfaceContainerLow: const Color(0xFF181B22),
      surfaceContainer: const Color(0xFF1D2028),
      surfaceContainerHigh: const Color(0xFF232731),
      surfaceContainerHighest: const Color(0xFF2B2F3A),
      outlineVariant: const Color(0xFF2E3240),
    ),
  );

  static TextTheme _text(TextTheme base) => base.copyWith(
    displaySmall: base.displaySmall?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -1),
    headlineMedium: base.headlineMedium?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.6),
    headlineSmall: base.headlineSmall?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.4),
    titleLarge: base.titleLarge?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -0.2),
    titleMedium: base.titleMedium?.copyWith(fontWeight: FontWeight.w600),
    titleSmall: base.titleSmall?.copyWith(fontWeight: FontWeight.w600),
    bodyLarge: base.bodyLarge?.copyWith(height: 1.45),
    bodyMedium: base.bodyMedium?.copyWith(height: 1.45),
    labelLarge: base.labelLarge?.copyWith(fontWeight: FontWeight.w600, letterSpacing: 0.1),
  );

  static ThemeData _build(ColorScheme colors) {
    final base = ThemeData(
      colorScheme: colors,
      fontFamily: fontFamily,
      fontFamilyFallback: fontFallback,
    );
    // Font sizes normally join the text theme only when the theme is localised; merge them in now
    // so component styles below (app bar, navigation labels) get real sizes.
    final text = _text(ThemeData.localize(base, base.typography.englishLike).textTheme);
    RoundedRectangleBorder rounded(double r) =>
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(r));
    const controlSize = Size(64, 48);
    final hairline = BorderSide(color: colors.outlineVariant);

    return base.copyWith(
      textTheme: text,
      visualDensity: VisualDensity.standard,
      scaffoldBackgroundColor: colors.surface,
      splashFactory: InkSparkle.splashFactory,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        foregroundColor: colors.onSurface,
        centerTitle: false,
        scrolledUnderElevation: 0,
        titleTextStyle: text.titleLarge?.copyWith(color: colors.onSurface),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: colors.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          side: hairline,
        ),
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
      ),
      dividerTheme: DividerThemeData(color: colors.outlineVariant, space: 1, thickness: 1),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        shape: rounded(AppSpacing.radiusMd),
        iconColor: colors.onSurfaceVariant,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: controlSize,
          shape: rounded(AppSpacing.radiusMd),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          textStyle: text.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: controlSize,
          shape: rounded(AppSpacing.radiusMd),
          side: BorderSide(color: colors.outline),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          textStyle: text.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: rounded(AppSpacing.radiusSm),
          textStyle: text.labelLarge,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 1,
        highlightElevation: 2,
        backgroundColor: colors.primary,
        foregroundColor: colors.onPrimary,
        shape: rounded(AppSpacing.radiusLg),
        extendedTextStyle: text.labelLarge,
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: colors.surfaceContainerLowest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: hairline,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: BorderSide(color: colors.outline.withValues(alpha: 0.6)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: BorderSide(color: colors.primary, width: 2),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: rounded(AppSpacing.radiusSm),
        side: hairline,
        labelStyle: text.labelLarge?.copyWith(color: colors.onSurface),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(minimumSize: const Size(48, 44)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shape: rounded(AppSpacing.radiusLg + 4),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusLg + 4)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: rounded(AppSpacing.radiusMd),
      ),
      tooltipTheme: TooltipThemeData(
        waitDuration: const Duration(milliseconds: 400),
        decoration: BoxDecoration(
          color: colors.inverseSurface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        ),
        textStyle: text.bodySmall?.copyWith(color: colors.onInverseSurface),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        linearTrackColor: colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(4),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        elevation: 0,
        backgroundColor: colors.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        indicatorColor: colors.secondaryContainer,
        indicatorShape: rounded(AppSpacing.radiusMd),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => text.labelMedium?.copyWith(
            fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? colors.onSurface
                : colors.onSurfaceVariant,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: colors.surface,
        indicatorColor: colors.secondaryContainer,
        indicatorShape: rounded(AppSpacing.radiusMd),
        minWidth: 88,
        selectedLabelTextStyle: text.labelLarge?.copyWith(color: colors.onSurface),
        unselectedLabelTextStyle: text.labelLarge?.copyWith(
          fontWeight: FontWeight.w500,
          color: colors.onSurfaceVariant,
        ),
      ),
    );
  }
}
