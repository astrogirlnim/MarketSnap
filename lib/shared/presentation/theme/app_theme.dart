import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';
import 'app_typography.dart';
import 'app_spacing.dart';

/// MarketSnap app theme following design system guidelines
class AppTheme {
  // Prevent instantiation
  AppTheme._();

  // ======================================
  // LIGHT THEME
  // ======================================

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: AppColors.lightScheme,
      textTheme: AppTypography.textTheme,
      
      // App Bar Theme
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.eggshell,
        foregroundColor: AppColors.soilCharcoal,
        elevation: 0,
        titleTextStyle: AppTypography.h2,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        iconTheme: IconThemeData(color: AppColors.soilCharcoal),
      ),

      // Card Theme
      cardTheme: CardTheme(
        color: AppColors.eggshell,
        shadowColor: AppColors.soilTaupe.withValues(alpha: 0.2),
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.snapCardBorderRadius),
        ),
        margin: AppSpacing.cardContent,
      ),

      // Button Themes
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.marketBlue,
          foregroundColor: AppColors.white,
          textStyle: AppTypography.button,
          padding: AppSpacing.buttonContent,
          minimumSize: const Size(0, AppSpacing.touchTarget),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.snapCardBorderRadius),
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.marketBlue,
          textStyle: AppTypography.button,
          padding: AppSpacing.buttonContent,
          minimumSize: const Size(0, AppSpacing.touchTarget),
          side: const BorderSide(color: AppColors.marketBlue, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.snapCardBorderRadius),
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.marketBlue,
          textStyle: AppTypography.button,
          padding: AppSpacing.buttonContent,
          minimumSize: const Size(0, AppSpacing.touchTarget),
        ),
      ),

      // Icon Theme
      iconTheme: const IconThemeData(
        color: AppColors.soilCharcoal,
        size: 24.0,
      ),

      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.eggshell,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.snapCardBorderRadius),
          borderSide: const BorderSide(color: AppColors.seedBrown),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.snapCardBorderRadius),
          borderSide: const BorderSide(color: AppColors.seedBrown),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.snapCardBorderRadius),
          borderSide: const BorderSide(color: AppColors.marketBlue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.snapCardBorderRadius),
          borderSide: const BorderSide(color: AppColors.appleRed),
        ),
        labelStyle: AppTypography.label,
        hintStyle: AppTypography.bodyWithColor(AppColors.soilTaupe),
        contentPadding: AppSpacing.cardContent,
      ),

      // Bottom Navigation Bar Theme
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.eggshell,
        selectedItemColor: AppColors.marketBlue,
        unselectedItemColor: AppColors.soilTaupe,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedLabelStyle: AppTypography.caption,
        unselectedLabelStyle: AppTypography.caption,
      ),

      // Floating Action Button Theme
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.harvestOrange,
        foregroundColor: AppColors.white,
        elevation: 6,
        focusElevation: 8,
        hoverElevation: 8,
        disabledElevation: 0,
      ),

      // Divider Theme
      dividerTheme: const DividerThemeData(
        color: AppColors.seedBrown,
        thickness: 1,
        space: AppSpacing.md,
      ),

      // Chip Theme
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.eggshell,
        selectedColor: AppColors.marketBlue,
        disabledColor: AppColors.soilTaupe.withValues(alpha: 0.3),
        labelStyle: AppTypography.caption,
        secondaryLabelStyle: AppTypography.captionWithColor(AppColors.white),
        padding: AppSpacing.paddingSM,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),

      // Dialog Theme
      dialogTheme: DialogTheme(
        backgroundColor: AppColors.eggshell,
        titleTextStyle: AppTypography.h2WithColor(AppColors.soilCharcoal),
        contentTextStyle: AppTypography.bodyWithColor(AppColors.soilCharcoal),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.snapCardBorderRadius),
        ),
      ),

      // Snackbar Theme
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.soilCharcoal,
        contentTextStyle: AppTypography.bodyWithColor(AppColors.white),
        actionTextColor: AppColors.marketBlue,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.snapCardBorderRadius),
        ),
      ),
    );
  }

  // ======================================
  // DARK THEME
  // ======================================

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: AppColors.darkScheme,
      textTheme: AppTypography.textTheme.apply(
        bodyColor: AppColors.soilCharcoalDark,
        displayColor: AppColors.soilCharcoalDark,
      ),
      
      // App Bar Theme
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.eggshellDark,
        foregroundColor: AppColors.soilCharcoalDark,
        elevation: 0,
        titleTextStyle: AppTypography.h2,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        iconTheme: IconThemeData(color: AppColors.soilCharcoalDark),
      ),

      // Card Theme
      cardTheme: CardTheme(
        color: AppColors.eggshellDark,
        shadowColor: AppColors.black.withValues(alpha: 0.3),
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.snapCardBorderRadius),
        ),
        margin: AppSpacing.cardContent,
      ),

      // Button Themes
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.marketBlueDark,
          foregroundColor: AppColors.black,
          textStyle: AppTypography.button,
          padding: AppSpacing.buttonContent,
          minimumSize: const Size(0, AppSpacing.touchTarget),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.snapCardBorderRadius),
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.marketBlueDark,
          textStyle: AppTypography.button,
          padding: AppSpacing.buttonContent,
          minimumSize: const Size(0, AppSpacing.touchTarget),
          side: const BorderSide(color: AppColors.marketBlueDark, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.snapCardBorderRadius),
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.marketBlueDark,
          textStyle: AppTypography.button,
          padding: AppSpacing.buttonContent,
          minimumSize: const Size(0, AppSpacing.touchTarget),
        ),
      ),

      // Icon Theme
      iconTheme: const IconThemeData(
        color: AppColors.soilCharcoalDark,
        size: 24.0,
      ),

      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.eggshellDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.snapCardBorderRadius),
          borderSide: const BorderSide(color: AppColors.seedBrownDark),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.snapCardBorderRadius),
          borderSide: const BorderSide(color: AppColors.seedBrownDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.snapCardBorderRadius),
          borderSide: const BorderSide(color: AppColors.marketBlueDark, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.snapCardBorderRadius),
          borderSide: const BorderSide(color: AppColors.appleRedDark),
        ),
        labelStyle: AppTypography.labelWithColor(AppColors.soilCharcoalDark),
        hintStyle: AppTypography.bodyWithColor(AppColors.soilTaupeDark),
        contentPadding: AppSpacing.cardContent,
      ),

      // Bottom Navigation Bar Theme
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.eggshellDark,
        selectedItemColor: AppColors.marketBlueDark,
        unselectedItemColor: AppColors.soilTaupeDark,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedLabelStyle: AppTypography.caption,
        unselectedLabelStyle: AppTypography.caption,
      ),

      // Floating Action Button Theme
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.harvestOrangeDark,
        foregroundColor: AppColors.black,
        elevation: 6,
        focusElevation: 8,
        hoverElevation: 8,
        disabledElevation: 0,
      ),

      // Divider Theme
      dividerTheme: const DividerThemeData(
        color: AppColors.seedBrownDark,
        thickness: 1,
        space: AppSpacing.md,
      ),

      // Chip Theme
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.eggshellDark,
        selectedColor: AppColors.marketBlueDark,
        disabledColor: AppColors.soilTaupeDark.withValues(alpha: 0.3),
        labelStyle: AppTypography.captionWithColor(AppColors.soilCharcoalDark),
        secondaryLabelStyle: AppTypography.captionWithColor(AppColors.black),
        padding: AppSpacing.paddingSM,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),

      // Dialog Theme
      dialogTheme: DialogTheme(
        backgroundColor: AppColors.eggshellDark,
        titleTextStyle: AppTypography.h2WithColor(AppColors.soilCharcoalDark),
        contentTextStyle: AppTypography.bodyWithColor(AppColors.soilCharcoalDark),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.snapCardBorderRadius),
        ),
      ),

      // Snackbar Theme
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.soilCharcoalDark,
        contentTextStyle: AppTypography.bodyWithColor(AppColors.black),
        actionTextColor: AppColors.marketBlueDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.snapCardBorderRadius),
        ),
      ),
    );
  }

  // ======================================
  // UTILITY METHODS
  // ======================================

  /// Get theme based on brightness
  static ThemeData getTheme(Brightness brightness) {
    return brightness == Brightness.light ? lightTheme : darkTheme;
  }

  /// Check if current theme is dark
  static bool isDark(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }

  /// Get appropriate color based on current theme
  static Color getColor(BuildContext context, Color lightColor, Color darkColor) {
    return isDark(context) ? darkColor : lightColor;
  }
}