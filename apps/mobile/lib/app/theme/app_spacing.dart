/// Spacing scale (logical pixels). Use these instead of ad-hoc numbers.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;

  /// Maximum readable content width on tablets and desktop web.
  static const double maxContentWidth = 760;

  /// Width at which the bottom navigation bar becomes a labelled navigation rail (tablets).
  static const double railBreakpoint = 840;

  /// Width at which the rail becomes a full sidebar listing every feature (desktop web).
  static const double sidebarBreakpoint = 1100;
  static const double sidebarWidth = 256;

  /// Corner radii shared by cards, fields and buttons.
  static const double radiusSm = 10;
  static const double radiusMd = 14;
  static const double radiusLg = 20;
}

/// Size class of the window. Phones, tablets and desktop web get different navigation and
/// icon sizes, so features stay easy to find on a large screen.
enum FormFactor {
  phone,
  tablet,
  desktop;

  static FormFactor ofWidth(double width) => width >= AppSpacing.sidebarBreakpoint
      ? desktop
      : width >= AppSpacing.railBreakpoint
      ? tablet
      : phone;

  /// Navigation icon size: phones keep Material's 24, a tablet rail is larger, and the desktop
  /// sidebar pairs a slightly smaller icon with a full label.
  double get navIconSize => switch (this) {
    phone => 24,
    tablet => 28,
    desktop => 22,
  };
}
