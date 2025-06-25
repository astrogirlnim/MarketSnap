import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';
import 'app_typography.dart';
import 'app_spacing.dart';

/// MarketSnap App Theme
/// Implements the design system defined in snap_design.md
/// Inspiration: Snapchat's playful minimalism + farmers-market warmth
class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: AppColors.lightColorScheme,
      textTheme: AppTypography.textTheme,
      appBarTheme: _appBarTheme,
      elevatedButtonTheme: _elevatedButtonTheme,
      outlinedButtonTheme: _outlinedButtonTheme,
      textButtonTheme: _textButtonTheme,
      inputDecorationTheme: _inputDecorationTheme,
      cardTheme: _cardTheme,
      dividerTheme: _dividerTheme,
      scaffoldBackgroundColor: AppColors.cornsilk,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      splashColor: AppColors.marketBlue.withValues(alpha: 0.1),
      highlightColor: AppColors.marketBlue.withValues(alpha: 0.05),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: AppColors.darkColorScheme,
      textTheme: AppTypography.textTheme.apply(
        bodyColor: AppColors.textPrimaryDark,
        displayColor: AppColors.textPrimaryDark,
      ),
      appBarTheme: _appBarThemeDark,
      elevatedButtonTheme: _elevatedButtonThemeDark,
      outlinedButtonTheme: _outlinedButtonThemeDark,
      textButtonTheme: _textButtonThemeDark,
      inputDecorationTheme: _inputDecorationThemeDark,
      cardTheme: _cardThemeDark,
      dividerTheme: _dividerThemeDark,
      scaffoldBackgroundColor: AppColors.backgroundDark,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      splashColor: AppColors.marketBlueDark.withValues(alpha: 0.1),
      highlightColor: AppColors.marketBlueDark.withValues(alpha: 0.05),
    );
  }

  // App Bar Themes
  static AppBarTheme get _appBarTheme {
    return AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      iconTheme: const IconThemeData(
        color: AppColors.soilCharcoal,
        size: 24,
      ),
      titleTextStyle: AppTypography.h2.copyWith(
        color: AppColors.soilCharcoal,
      ),
    );
  }

  static AppBarTheme get _appBarThemeDark {
    return AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      iconTheme: const IconThemeData(
        color: AppColors.textPrimaryDark,
        size: 24,
      ),
      titleTextStyle: AppTypography.h2.apply(
        color: AppColors.textPrimaryDark,
      ),
    );
  }

  // Button Themes
  static ElevatedButtonThemeData get _elevatedButtonTheme {
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.marketBlue,
        foregroundColor: Colors.white,
        elevation: 2,
        shadowColor: AppColors.marketBlue.withValues(alpha: 0.3),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        minimumSize: const Size(double.infinity, 56), // 48px + padding
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: AppTypography.bodyLG.copyWith(
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }

  static ElevatedButtonThemeData get _elevatedButtonThemeDark {
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.marketBlueDark,
        foregroundColor: Colors.white,
        elevation: 2,
        shadowColor: AppColors.marketBlueDark.withValues(alpha: 0.3),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        minimumSize: const Size(double.infinity, 56),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: AppTypography.bodyLG.copyWith(
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }

  static OutlinedButtonThemeData get _outlinedButtonTheme {
    return OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.soilCharcoal,
        side: const BorderSide(
          color: AppColors.seedBrown,
          width: 2,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        minimumSize: const Size(double.infinity, 56),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: AppTypography.bodyLG.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  static OutlinedButtonThemeData get _outlinedButtonThemeDark {
    return OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textPrimaryDark,
        side: const BorderSide(
          color: AppColors.outlineDark,
          width: 2,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        minimumSize: const Size(double.infinity, 56),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: AppTypography.bodyLG.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  static TextButtonThemeData get _textButtonTheme {
    return TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.marketBlue,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        minimumSize: const Size(48, 48), // Minimum touch target
        textStyle: AppTypography.body.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  static TextButtonThemeData get _textButtonThemeDark {
    return TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.marketBlueDark,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        minimumSize: const Size(48, 48),
        textStyle: AppTypography.body.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // Input Decoration Theme
  static InputDecorationTheme get _inputDecorationTheme {
    return InputDecorationTheme(
      filled: true,
      fillColor: AppColors.eggshell,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: AppColors.seedBrown,
          width: 1,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: AppColors.seedBrown,
          width: 1,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: AppColors.marketBlue,
          width: 2,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: AppColors.appleRed,
          width: 2,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: AppColors.appleRed,
          width: 2,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      hintStyle: AppTypography.body.copyWith(
        color: AppColors.soilTaupe,
      ),
      labelStyle: AppTypography.label.copyWith(
        color: AppColors.soilTaupe,
      ),
    );
  }

  static InputDecorationTheme get _inputDecorationThemeDark {
    return InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceDark,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: AppColors.outlineDark,
          width: 1,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: AppColors.outlineDark,
          width: 1,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: AppColors.marketBlueDark,
          width: 2,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: AppColors.appleRedDark,
          width: 2,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: AppColors.appleRedDark,
          width: 2,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      hintStyle: AppTypography.body.copyWith(
        color: AppColors.textSecondaryDark,
      ),
      labelStyle: AppTypography.label.copyWith(
        color: AppColors.textSecondaryDark,
      ),
    );
  }

  // Card Theme
  static CardThemeData get _cardTheme {
    return CardThemeData(
      color: AppColors.eggshell,
      elevation: 2,
      shadowColor: AppColors.soilCharcoal.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(
          color: AppColors.seedBrown,
          width: 0.5,
        ),
      ),
      margin: const EdgeInsets.all(AppSpacing.sm),
    );
  }

  static CardThemeData get _cardThemeDark {
    return CardThemeData(
      color: AppColors.surfaceDark,
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(
          color: AppColors.outlineDark,
          width: 0.5,
        ),
      ),
      margin: const EdgeInsets.all(AppSpacing.sm),
    );
  }

  // Divider Theme
  static DividerThemeData get _dividerTheme {
    return const DividerThemeData(
      color: AppColors.seedBrown,
      thickness: 1,
      space: AppSpacing.md,
    );
  }

  static DividerThemeData get _dividerThemeDark {
    return const DividerThemeData(
      color: AppColors.outlineDark,
      thickness: 1,
      space: AppSpacing.md,
    );
  }
}