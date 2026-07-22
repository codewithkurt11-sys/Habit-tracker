/// Centralized spacing, radius, and elevation tokens.
///
/// Use these constants instead of magic numbers in screen/widget code
/// so density and rounding can be tuned globally.
class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  static const double radiusSmall = 10;
  static const double radiusMedium = 16;
  static const double radiusLarge = 24;
  static const double radiusPill = 999;

  static const double elevationCard = 0; // Flat, soft-shadow style preferred.
}

/// Centralized animation durations/curves so transitions feel consistent
/// across the app.
class AppMotion {
  AppMotion._();

  static const Duration fast = Duration(milliseconds: 150);
  static const Duration medium = Duration(milliseconds: 280);
  static const Duration slow = Duration(milliseconds: 420);
}
