import 'package:flutter/material.dart';

/// Centralized color palette for the entire app.
///
/// IMPORTANT: Do not hardcode colors in individual screens or widgets.
/// Always reference values from here (or from [AppTheme] extensions)
/// so the visual design can be restyled from a single source of truth.
///
/// v2 palette — a warm, modern "sunset sage" theme with vibrant accents.
class AppColors {
  AppColors._();

  // ---- Light theme palette (refined sunset-sage v3) ----
  static const Color lightBackground = Color(0xFFFBF8F3);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceMuted = Color(0xFFF2ECE3);
  static const Color lightPrimary = Color(0xFF7A6B5D);
  static const Color lightPrimaryVariant = Color(0xFF5C4F44);
  static const Color lightSecondary = Color(0xFF5F8A78);
  static const Color lightAccent = Color(0xFFE8946F);
  static const Color lightTextPrimary = Color(0xFF2B2723);
  static const Color lightTextSecondary = Color(0xFF837A70);
  static const Color lightDivider = Color(0xFFEBE3D7);
  static const Color lightError = Color(0xFFD4675A);
  static const Color lightSuccess = Color(0xFF5F8A78);
  static const Color lightNudge = Color(0xFFF4E9D4);
  // Warmer, more noticeable ambient gradient for depth.
  static const Color lightGradientTop = Color(0xFFF6EEE2);
  static const Color lightGradientBottom = Color(0xFFFBF8F3);
  static const Color lightShadow = Color(0xFF6B5A48);

  // ---- Dark theme palette ----
  static const Color darkBackground = Color(0xFF171513);
  static const Color darkSurface = Color(0xFF242119);
  static const Color darkSurfaceMuted = Color(0xFF322E26);
  static const Color darkPrimary = Color(0xFFCBAF9B);
  static const Color darkPrimaryVariant = Color(0xFFA88B77);
  static const Color darkSecondary = Color(0xFF93B8A4);
  static const Color darkAccent = Color(0xFFEC9C77);
  static const Color darkTextPrimary = Color(0xFFF6F1EB);
  static const Color darkTextSecondary = Color(0xFFB8AEA4);
  static const Color darkDivider = Color(0xFF3D3833);
  static const Color darkError = Color(0xFFE89B8E);
  static const Color darkSuccess = Color(0xFF93B8A4);
  static const Color darkNudge = Color(0xFF3A3328);
  static const Color darkGradientTop = Color(0xFF2A251D);
  static const Color darkGradientBottom = Color(0xFF171513);
  static const Color darkShadow = Color(0xFF000000);

  // ---- Habit category accent colors (semantic, vibrant) ----
  static const Color categoryWorkout = Color(0xFFE8946F);
  static const Color categoryLifestyle = Color(0xFF6B9080);
  static const Color categoryOther = Color(0xFF7B93B5);

  // ---- File-type accent colors (used by the file manager) ----
  static const Color fileFolder = Color(0xFFE8B66F);
  static const Color fileImage = Color(0xFF6B9080);
  static const Color fileVideo = Color(0xFFD67474);
  static const Color fileAudio = Color(0xFFB58BB5);
  static const Color fileDoc = Color(0xFF7B93B5);
  static const Color fileArchive = Color(0xFFE8946F);
  static const Color fileApk = Color(0xFF8FC0A0);
  static const Color fileCode = Color(0xFF6C8EBF);
  static const Color fileOther = Color(0xFF9A8E80);

  // ---- Mood colors ----
  static const Color moodGreat = Color(0xFF6B9080);
  static const Color moodGood = Color(0xFFA8C09A);
  static const Color moodOkay = Color(0xFFE8C56F);
  static const Color moodLow = Color(0xFFE8946F);
  static const Color moodRough = Color(0xFFD4675A);

  // ---- Available custom habit colors ----
  static const List<Color> habitColorPalette = [
    Color(0xFFE8946F), // terracotta
    Color(0xFF6B9080), // sage
    Color(0xFF7B93B5), // blue
    Color(0xFFC4A895), // tan
    Color(0xFFB58BB5), // mauve
    Color(0xFF8FC0A0), // mint
    Color(0xFFE8B66F), // amber
    Color(0xFFD67474), // coral
  ];
}
