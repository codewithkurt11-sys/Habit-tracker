import 'package:flutter/material.dart';

/// Centralized typography scale.
///
/// Screens should reference `Theme.of(context).textTheme` (populated
/// from this class in [AppTheme]) rather than defining TextStyle
/// instances inline.
class AppTypography {
  AppTypography._();

  static const String fontFamily = 'Georgia'; // Falls back to system serif.

  static TextTheme textTheme(Color primaryText, Color secondaryText) {
    return TextTheme(
      displayLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w600,
        color: primaryText,
        height: 1.2,
        letterSpacing: -0.5,
      ),
      displayMedium: TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w600,
        color: primaryText,
        height: 1.25,
      ),
      displaySmall: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: primaryText,
        height: 1.25,
      ),
      headlineMedium: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: primaryText,
        height: 1.3,
      ),
      headlineSmall: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: primaryText,
        height: 1.3,
      ),
      titleLarge: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: primaryText,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: primaryText,
      ),
      titleSmall: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: primaryText,
        height: 1.3,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: primaryText,
        height: 1.5,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: secondaryText,
        height: 1.45,
      ),
      bodySmall: TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w400,
        color: secondaryText,
        height: 1.4,
      ),
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: primaryText,
      ),
      labelSmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: secondaryText,
        letterSpacing: 0.4,
      ),
    );
  }
}
