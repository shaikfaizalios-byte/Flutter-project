/// Spacing scale (logical pixels). Use these instead of ad-hoc numbers.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;

  /// Maximum readable content width on tablets and desktop web.
  static const double maxContentWidth = 720;

  /// Width at which the bottom navigation bar becomes a navigation rail.
  static const double railBreakpoint = 840;
}
