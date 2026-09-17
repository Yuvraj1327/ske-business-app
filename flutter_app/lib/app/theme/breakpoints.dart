/// Centralized responsive width thresholds — previously independent magic
/// numbers duplicated across the shell (sidebar vs. drawer) and the
/// dashboard (KPI grid column count). Keeping them here means every screen
/// agrees on where "mobile"/"tablet"/"desktop" starts.
class AppBreakpoints {
  AppBreakpoints._();

  /// Below this, layouts collapse to a single column.
  static const double compact = 640;

  /// Below this (and >= [compact]), layouts use a 2-column grid.
  static const double medium = 1000;

  /// At or above this, the app shell shows a persistent nav rail instead of
  /// a drawer + bottom nav.
  static const double sidebarWide = 900;
}
