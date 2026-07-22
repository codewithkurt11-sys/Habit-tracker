import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// Assembles [ThemeData] from the design tokens in [AppColors],
/// [AppTypography], and [AppSpacing].
///
/// Screens must not construct their own [ThemeData] or hardcode
/// colors/text styles — always pull from `Theme.of(context)` or from
/// [AppThemeExtension] below.
class AppTheme {
  AppTheme._();

  static ThemeData light() {
    const scheme = ColorScheme.light(
      primary: AppColors.lightPrimary,
      onPrimary: Colors.white,
      secondary: AppColors.lightSecondary,
      onSecondary: Colors.white,
      surface: AppColors.lightSurface,
      onSurface: AppColors.lightTextPrimary,
      error: AppColors.lightError,
      onError: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.lightBackground,
      textTheme: AppTypography.textTheme(
        AppColors.lightTextPrimary,
        AppColors.lightTextSecondary,
      ),
      dividerColor: AppColors.lightDivider,
      cardTheme: CardThemeData(
        color: AppColors.lightSurface,
        elevation: 0,
        shadowColor: AppColors.lightShadow.withValues(alpha: 0.10),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
        ),
        margin: EdgeInsets.zero,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        foregroundColor: AppColors.lightTextPrimary,
        titleTextStyle: TextStyle(
          fontFamily: AppTypography.fontFamily,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.lightTextPrimary,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.lightSurfaceMuted,
        labelStyle: const TextStyle(
          color: AppColors.lightTextPrimary,
          fontSize: 12,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
        ),
        side: BorderSide.none,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.lightPrimary,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.lightPrimary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.lightSurfaceMuted,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.all(AppSpacing.md),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.xs),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.lightSurface,
        elevation: 0,
        height: 68,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.lightPrimary.withValues(alpha: 0.14),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
        ),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.lightPrimary, size: 24);
          }
          return const IconThemeData(
            color: AppColors.lightTextSecondary,
            size: 24,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.lightPrimary,
            );
          }
          return const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: AppColors.lightTextSecondary,
          );
        }),
      ),
      extensions: const [
        AppThemeExtension(
          nudge: AppColors.lightNudge,
          success: AppColors.lightSuccess,
          surfaceMuted: AppColors.lightSurfaceMuted,
          categoryWorkout: AppColors.categoryWorkout,
          categoryLifestyle: AppColors.categoryLifestyle,
          categoryOther: AppColors.categoryOther,
          gradientTop: AppColors.lightGradientTop,
          gradientBottom: AppColors.lightGradientBottom,
          shadow: AppColors.lightShadow,
        ),
      ],
    );
  }

  static ThemeData dark() {
    const scheme = ColorScheme.dark(
      primary: AppColors.darkPrimary,
      onPrimary: Color(0xFF2C2420),
      secondary: AppColors.darkSecondary,
      onSecondary: Color(0xFF20261C),
      surface: AppColors.darkSurface,
      onSurface: AppColors.darkTextPrimary,
      error: AppColors.darkError,
      onError: Colors.black,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.darkBackground,
      textTheme: AppTypography.textTheme(
        AppColors.darkTextPrimary,
        AppColors.darkTextSecondary,
      ),
      dividerColor: AppColors.darkDivider,
      cardTheme: CardThemeData(
        color: AppColors.darkSurface,
        elevation: 0,
        shadowColor: Colors.black.withValues(alpha: 0.35),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
        ),
        margin: EdgeInsets.zero,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        foregroundColor: AppColors.darkTextPrimary,
        titleTextStyle: TextStyle(
          fontFamily: AppTypography.fontFamily,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.darkTextPrimary,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.darkSurfaceMuted,
        labelStyle: const TextStyle(
          color: AppColors.darkTextPrimary,
          fontSize: 12,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
        ),
        side: BorderSide.none,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.darkPrimary,
        foregroundColor: Color(0xFF2C2420),
        elevation: 2,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.darkPrimary,
          foregroundColor: const Color(0xFF2C2420),
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkSurfaceMuted,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.all(AppSpacing.md),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.xs),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.darkSurface,
        elevation: 0,
        height: 68,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.darkPrimary.withValues(alpha: 0.18),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
        ),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.darkPrimary, size: 24);
          }
          return const IconThemeData(
            color: AppColors.darkTextSecondary,
            size: 24,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.darkPrimary,
            );
          }
          return const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: AppColors.darkTextSecondary,
          );
        }),
      ),
      extensions: const [
        AppThemeExtension(
          nudge: AppColors.darkNudge,
          success: AppColors.darkSuccess,
          surfaceMuted: AppColors.darkSurfaceMuted,
          categoryWorkout: AppColors.categoryWorkout,
          categoryLifestyle: AppColors.categoryLifestyle,
          categoryOther: AppColors.categoryOther,
          gradientTop: AppColors.darkGradientTop,
          gradientBottom: AppColors.darkGradientBottom,
          shadow: AppColors.darkShadow,
        ),
      ],
    );
  }
}

/// Additional theme tokens not covered by Flutter's built-in [ColorScheme].
/// Access via `Theme.of(context).extension<AppThemeExtension>()!`.
class AppThemeExtension extends ThemeExtension<AppThemeExtension> {
  final Color nudge;
  final Color success;
  final Color surfaceMuted;
  final Color categoryWorkout;
  final Color categoryLifestyle;
  final Color categoryOther;
  final Color gradientTop;
  final Color gradientBottom;
  final Color shadow;

  const AppThemeExtension({
    required this.nudge,
    required this.success,
    required this.surfaceMuted,
    required this.categoryWorkout,
    required this.categoryLifestyle,
    required this.categoryOther,
    required this.gradientTop,
    required this.gradientBottom,
    required this.shadow,
  });

  @override
  AppThemeExtension copyWith({
    Color? nudge,
    Color? success,
    Color? surfaceMuted,
    Color? categoryWorkout,
    Color? categoryLifestyle,
    Color? categoryOther,
    Color? gradientTop,
    Color? gradientBottom,
    Color? shadow,
  }) {
    return AppThemeExtension(
      nudge: nudge ?? this.nudge,
      success: success ?? this.success,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      categoryWorkout: categoryWorkout ?? this.categoryWorkout,
      categoryLifestyle: categoryLifestyle ?? this.categoryLifestyle,
      categoryOther: categoryOther ?? this.categoryOther,
      gradientTop: gradientTop ?? this.gradientTop,
      gradientBottom: gradientBottom ?? this.gradientBottom,
      shadow: shadow ?? this.shadow,
    );
  }

  @override
  ThemeExtension<AppThemeExtension> lerp(
    covariant ThemeExtension<AppThemeExtension>? other,
    double t,
  ) {
    if (other is! AppThemeExtension) return this;
    return AppThemeExtension(
      nudge: Color.lerp(nudge, other.nudge, t)!,
      success: Color.lerp(success, other.success, t)!,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
      categoryWorkout: Color.lerp(categoryWorkout, other.categoryWorkout, t)!,
      categoryLifestyle: Color.lerp(
        categoryLifestyle,
        other.categoryLifestyle,
        t,
      )!,
      categoryOther: Color.lerp(categoryOther, other.categoryOther, t)!,
      gradientTop: Color.lerp(gradientTop, other.gradientTop, t)!,
      gradientBottom: Color.lerp(gradientBottom, other.gradientBottom, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
    );
  }
}
