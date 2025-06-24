import 'package:flutter/material.dart';

/// MarketSnap color palette based on design system
/// Inspired by Snapchat's playful minimalism + farmers market warmth
class AppColors {
  // Prevent instantiation
  AppColors._();

  // ======================================
  // PRIMARY COLORS
  // ======================================

  /// Market Blue - Primary CTA color (Snapchat blue tuned for sunlight)
  static const Color marketBlue = Color(0xFF007AFF);
  static const Color marketBlueDark = Color(0xFF4D9DFF);

  /// Harvest Orange - Secondary CTA color (carrots, pumpkins)
  static const Color harvestOrange = Color(0xFFFF9500);
  static const Color harvestOrangeDark = Color(0xFFFFAD33);

  /// Leaf Green - Success/in-stock indicator
  static const Color leafGreen = Color(0xFF34C759);
  static const Color leafGreenDark = Color(0xFF66D98A);

  /// Sunset Amber - Warning/queued items
  static const Color sunsetAmber = Color(0xFFFFCC00);
  static const Color sunsetAmberDark = Color(0xFFFFD633);

  /// Apple Red - Error/failed upload
  static const Color appleRed = Color(0xFFFF3B30);
  static const Color appleRedDark = Color(0xFFFF665C);

  // ======================================
  // BACKGROUND COLORS
  // ======================================

  /// Cornsilk - Light background
  static const Color cornsilk = Color(0xFFFFF6D9);
  static const Color cornsilkDark = Color(0xFF1E1E1E);

  /// Eggshell - Card and input backgrounds
  static const Color eggshell = Color(0xFFFFFCEA);
  static const Color eggshellDark = Color(0xFF2A2A2A);

  /// Seed Brown - Borders for secondary buttons
  static const Color seedBrown = Color(0xFFC8B185);
  static const Color seedBrownDark = Color(0xFF3F3F3F);

  // ======================================
  // TEXT COLORS
  // ======================================

  /// Soil Charcoal - Primary text (AA 4.5:1 contrast)
  static const Color soilCharcoal = Color(0xFF3C3C3C);
  static const Color soilCharcoalDark = Color(0xFFF2F2F2);

  /// Soil Taupe - Secondary text (labels, captions)
  static const Color soilTaupe = Color(0xFF6E6E6E);
  static const Color soilTaupeDark = Color(0xFFBDBDBD);

  // ======================================
  // UTILITY COLORS
  // ======================================

  /// Pure white
  static const Color white = Color(0xFFFFFFFF);

  /// Pure black (avoid in dark mode, use cornsilkDark instead)
  static const Color black = Color(0xFF000000);

  /// Transparent
  static const Color transparent = Color(0x00000000);

  // ======================================
  // STORY/TTL COLORS
  // ======================================

  /// Story ring colors for unviewed stories
  static const Color storyUnviewed = marketBlue;

  /// Story ring color for viewed stories
  static const Color storyViewed = soilTaupe;

  /// TTL badge background (urgent)
  static const Color ttlUrgent = appleRed;

  /// TTL badge background (warning)
  static const Color ttlWarning = sunsetAmber;

  /// TTL badge background (normal)
  static const Color ttlNormal = leafGreen;

  // ======================================
  // THEMED COLOR GETTERS
  // ======================================

  /// Get primary color based on brightness
  static Color primary(Brightness brightness) {
    return brightness == Brightness.light ? marketBlue : marketBlueDark;
  }

  /// Get secondary color based on brightness
  static Color secondary(Brightness brightness) {
    return brightness == Brightness.light ? harvestOrange : harvestOrangeDark;
  }

  /// Get success color based on brightness
  static Color success(Brightness brightness) {
    return brightness == Brightness.light ? leafGreen : leafGreenDark;
  }

  /// Get warning color based on brightness
  static Color warning(Brightness brightness) {
    return brightness == Brightness.light ? sunsetAmber : sunsetAmberDark;
  }

  /// Get error color based on brightness
  static Color error(Brightness brightness) {
    return brightness == Brightness.light ? appleRed : appleRedDark;
  }

  /// Get background color based on brightness
  static Color background(Brightness brightness) {
    return brightness == Brightness.light ? cornsilk : cornsilkDark;
  }

  /// Get surface color based on brightness
  static Color surface(Brightness brightness) {
    return brightness == Brightness.light ? eggshell : eggshellDark;
  }

  /// Get outline color based on brightness
  static Color outline(Brightness brightness) {
    return brightness == Brightness.light ? seedBrown : seedBrownDark;
  }

  /// Get primary text color based on brightness
  static Color textPrimary(Brightness brightness) {
    return brightness == Brightness.light ? soilCharcoal : soilCharcoalDark;
  }

  /// Get secondary text color based on brightness
  static Color textSecondary(Brightness brightness) {
    return brightness == Brightness.light ? soilTaupe : soilTaupeDark;
  }

  // ======================================
  // COLOR SCHEMES
  // ======================================

  /// Light color scheme for the app
  static const ColorScheme lightScheme = ColorScheme.light(
    primary: marketBlue,
    secondary: harvestOrange,
    surface: eggshell,
    background: cornsilk,
    error: appleRed,
    onPrimary: white,
    onSecondary: white,
    onSurface: soilCharcoal,
    onBackground: soilCharcoal,
    onError: white,
    outline: seedBrown,
  );

  /// Dark color scheme for the app
  static const ColorScheme darkScheme = ColorScheme.dark(
    primary: marketBlueDark,
    secondary: harvestOrangeDark,
    surface: eggshellDark,
    background: cornsilkDark,
    error: appleRedDark,
    onPrimary: black,
    onSecondary: black,
    onSurface: soilCharcoalDark,
    onBackground: soilCharcoalDark,
    onError: black,
    outline: seedBrownDark,
  );
}