import 'package:flutter/material.dart';

/// MarketSnap typography system based on design system
/// Font stack: Inter → Roboto → system sans-serif
class AppTypography {
  // Prevent instantiation
  AppTypography._();

  // ======================================
  // FONT FAMILIES
  // ======================================

  /// Primary font family (system fonts for fast loading)
  static const String fontFamily = 'Inter';

  /// Fallback font families
  static const List<String> fontFamilyFallback = ['Roboto', 'system-ui', 'sans-serif'];

  // ======================================
  // TEXT STYLES
  // ======================================

  /// Display style: 32/38, weight 800
  /// Usage: Hero headlines (e.g., "Share your fresh finds")
  static const TextStyle display = TextStyle(
    fontFamily: fontFamily,
    fontSize: 32.0,
    height: 38.0 / 32.0,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.5,
  );

  /// H1 style: 28/34, weight 700
  /// Usage: Section titles
  static const TextStyle h1 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 28.0,
    height: 34.0 / 28.0,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
  );

  /// H2 style: 24/30, weight 600
  /// Usage: Card titles, dialog headers
  static const TextStyle h2 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 24.0,
    height: 30.0 / 24.0,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
  );

  /// Body Large style: 18/26, weight 500
  /// Usage: Descriptive copy
  static const TextStyle bodyLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 18.0,
    height: 26.0 / 18.0,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.0,
  );

  /// Body style: 16/24, weight 400
  /// Usage: Default text
  static const TextStyle body = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16.0,
    height: 24.0 / 16.0,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.0,
  );

  /// Caption style: 12/16, weight 500
  /// Usage: Metadata, timestamps
  static const TextStyle caption = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12.0,
    height: 16.0 / 12.0,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.2,
  );

  /// Label style: 11/14, weight 600
  /// Usage: Input labels
  static const TextStyle label = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11.0,
    height: 14.0 / 11.0,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
  );

  // ======================================
  // SEMANTIC TEXT STYLES
  // ======================================

  /// Button text style
  static const TextStyle button = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16.0,
    height: 20.0 / 16.0,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
  );

  /// Small button text style
  static const TextStyle buttonSmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14.0,
    height: 18.0 / 14.0,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
  );

  /// Story vendor name style
  static const TextStyle storyVendor = TextStyle(
    fontFamily: fontFamily,
    fontSize: 10.0,
    height: 12.0 / 10.0,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
  );

  /// TTL badge text style
  static const TextStyle ttlBadge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 10.0,
    height: 12.0 / 10.0,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.3,
  );

  /// Snap caption style
  static const TextStyle snapCaption = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14.0,
    height: 20.0 / 14.0,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.0,
  );

  /// Feed vendor name style
  static const TextStyle feedVendor = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14.0,
    height: 18.0 / 14.0,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
  );

  /// Feed timestamp style
  static const TextStyle feedTimestamp = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12.0,
    height: 16.0 / 12.0,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.2,
  );

  // ======================================
  // THEMED TEXT STYLES
  // ======================================

  /// Get display style with color
  static TextStyle displayWithColor(Color color) => display.copyWith(color: color);

  /// Get h1 style with color
  static TextStyle h1WithColor(Color color) => h1.copyWith(color: color);

  /// Get h2 style with color
  static TextStyle h2WithColor(Color color) => h2.copyWith(color: color);

  /// Get body large style with color
  static TextStyle bodyLargeWithColor(Color color) => bodyLarge.copyWith(color: color);

  /// Get body style with color
  static TextStyle bodyWithColor(Color color) => body.copyWith(color: color);

  /// Get caption style with color
  static TextStyle captionWithColor(Color color) => caption.copyWith(color: color);

  /// Get label style with color
  static TextStyle labelWithColor(Color color) => label.copyWith(color: color);

  // ======================================
  // TEXT THEME
  // ======================================

  /// Complete text theme for the app
  static const TextTheme textTheme = TextTheme(
    displayLarge: display,
    displayMedium: h1,
    displaySmall: h2,
    headlineLarge: h1,
    headlineMedium: h2,
    headlineSmall: bodyLarge,
    titleLarge: h2,
    titleMedium: bodyLarge,
    titleSmall: body,
    bodyLarge: bodyLarge,
    bodyMedium: body,
    bodySmall: caption,
    labelLarge: button,
    labelMedium: label,
    labelSmall: caption,
  );

  // ======================================
  // UTILITY METHODS
  // ======================================

  /// Apply color to any text style
  static TextStyle withColor(TextStyle style, Color color) {
    return style.copyWith(color: color);
  }

  /// Apply weight to any text style
  static TextStyle withWeight(TextStyle style, FontWeight weight) {
    return style.copyWith(fontWeight: weight);
  }

  /// Apply size to any text style
  static TextStyle withSize(TextStyle style, double size) {
    return style.copyWith(fontSize: size);
  }

  /// Apply multiple properties to text style
  static TextStyle withProperties(
    TextStyle style, {
    Color? color,
    FontWeight? weight,
    double? size,
    double? letterSpacing,
    double? height,
  }) {
    return style.copyWith(
      color: color,
      fontWeight: weight,
      fontSize: size,
      letterSpacing: letterSpacing,
      height: height,
    );
  }
}