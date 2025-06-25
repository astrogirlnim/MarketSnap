import 'package:flutter/material.dart';

/// MarketSnap Color Palette
/// Based on the design system defined in snap_design.md
/// Inspiration: Snapchat's playful minimalism + farmers-market warmth
class AppColors {
  // Primary CTA Colors
  static const Color marketBlue = Color(0xFF007AFF); // Market Blue
  static const Color marketBlueDark = Color(0xFF4D9DFF);

  // Secondary CTA Colors
  static const Color harvestOrange = Color(0xFFFF9500); // Harvest Orange
  static const Color harvestOrangeDark = Color(0xFFFFAD33);

  // Accent / Success Colors
  static const Color leafGreen = Color(0xFF34C759); // Leaf Green
  static const Color leafGreenDark = Color(0xFF66D98A);

  // Warning Colors
  static const Color sunsetAmber = Color(0xFFFFCC00); // Sunset Amber
  static const Color sunsetAmberDark = Color(0xFFFFD633);

  // Error Colors
  static const Color appleRed = Color(0xFFFF3B30); // Apple Red
  static const Color appleRedDark = Color(0xFFFF665C);

  // Background Colors
  static const Color cornsilk = Color(0xFFFFF6D9); // Cornsilk
  static const Color backgroundDark = Color(0xFF1E1E1E);

  // Surface Colors
  static const Color eggshell = Color(0xFFFFFFEA); // Eggshell
  static const Color surfaceDark = Color(0xFF2A2A2A);

  // Outline Colors
  static const Color seedBrown = Color(0xFFC8B185); // Seed Brown
  static const Color outlineDark = Color(0xFF3F3F3F);

  // Text Colors
  static const Color soilCharcoal = Color(
    0xFF3C3C3C,
  ); // Soil Charcoal (Primary Text)
  static const Color textPrimaryDark = Color(0xFFF2F2F2);

  static const Color soilTaupe = Color(
    0xFF6E6E6E,
  ); // Soil Taupe (Secondary Text)
  static const Color textSecondaryDark = Color(0xFFBDBDBD);

  // Additional semantic colors for better theming
  static const Color success = leafGreen;
  static const Color successDark = leafGreenDark;
  static const Color warning = sunsetAmber;
  static const Color warningDark = sunsetAmberDark;
  static const Color error = appleRed;
  static const Color errorDark = appleRedDark;

  // Light Theme Color Scheme
  static ColorScheme get lightColorScheme {
    return const ColorScheme.light(
      primary: marketBlue,
      onPrimary: Colors.white,
      secondary: harvestOrange,
      onSecondary: Colors.white,
      tertiary: leafGreen,
      onTertiary: Colors.white,
      error: appleRed,
      onError: Colors.white,
      surface: eggshell,
      onSurface: soilCharcoal,
      outline: seedBrown,
      surfaceContainerHighest: eggshell,
      onSurfaceVariant: soilTaupe,
    );
  }

  // Dark Theme Color Scheme
  static ColorScheme get darkColorScheme {
    return const ColorScheme.dark(
      primary: marketBlueDark,
      onPrimary: Colors.black,
      secondary: harvestOrangeDark,
      onSecondary: Colors.black,
      tertiary: leafGreenDark,
      onTertiary: Colors.black,
      error: appleRedDark,
      onError: Colors.black,
      surface: surfaceDark,
      onSurface: textPrimaryDark,
      outline: outlineDark,
      surfaceContainerHighest: surfaceDark,
      onSurfaceVariant: textSecondaryDark,
    );
  }

  // Helper methods for color variations
  static Color withOpacityValue(Color color, double opacity) {
    return color.withValues(alpha: opacity);
  }

  // Status colors for different states
  static const Color queuedBorder = sunsetAmber; // For queued items
  static const Color syncedSuccess = leafGreen; // For synced items
  static const Color failedError = appleRed; // For failed items

  // Gradient colors for backgrounds (inspired by the camera preview gradient)
  static const List<Color> gradientPrimary = [
    Color(0xFF6366F1), // Indigo
    Color(0xFF8B5CF6), // Purple
    Color(0xFFEC4899), // Pink
  ];

  // Gradient for Market theme
  static const List<Color> gradientMarket = [
    harvestOrange,
    marketBlue,
    leafGreen,
  ];

  // Shadow colors
  static Color get shadowLight => soilCharcoal.withValues(alpha: 0.1);
  static Color get shadowDark => Colors.black.withValues(alpha: 0.3);

  // Helper for contrast checking (4.5:1 ratio minimum)
  static bool hasGoodContrast(Color foreground, Color background) {
    final fgLuminance = foreground.computeLuminance();
    final bgLuminance = background.computeLuminance();
    final ratio = (fgLuminance + 0.05) / (bgLuminance + 0.05);
    return ratio >= 4.5 || (1 / ratio) >= 4.5;
  }
}
