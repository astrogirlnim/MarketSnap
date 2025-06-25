import 'package:flutter/material.dart';
import 'app_colors.dart';

/// MarketSnap Typography System
/// Based on the design system defined in snap_design.md
/// Font stack: Inter → Roboto → system sans-serif
class AppTypography {
  // Font family - Inter preferred, fallback to Roboto, then system
  static const String _fontFamily = 'Inter';

  // Display Style - Hero headlines (e.g., "Share your fresh finds")
  static TextStyle get display => const TextStyle(
    fontFamily: _fontFamily,
    fontSize: 32,
    height: 38 / 32, // line height / font size
    fontWeight: FontWeight.w800,
    color: AppColors.soilCharcoal,
    letterSpacing: -0.5,
  );

  // H1 Style - Section titles
  static TextStyle get h1 => const TextStyle(
    fontFamily: _fontFamily,
    fontSize: 28,
    height: 34 / 28,
    fontWeight: FontWeight.w700,
    color: AppColors.soilCharcoal,
    letterSpacing: -0.3,
  );

  // H2 Style - Card titles, dialog headers
  static TextStyle get h2 => const TextStyle(
    fontFamily: _fontFamily,
    fontSize: 24,
    height: 30 / 24,
    fontWeight: FontWeight.w600,
    color: AppColors.soilCharcoal,
    letterSpacing: -0.2,
  );

  // Body-LG Style - Descriptive copy
  static TextStyle get bodyLG => const TextStyle(
    fontFamily: _fontFamily,
    fontSize: 18,
    height: 26 / 18,
    fontWeight: FontWeight.w500,
    color: AppColors.soilCharcoal,
  );

  // Body Style - Default text
  static TextStyle get body => const TextStyle(
    fontFamily: _fontFamily,
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w400,
    color: AppColors.soilCharcoal,
  );

  // Caption Style - Metadata, timestamps
  static TextStyle get caption => const TextStyle(
    fontFamily: _fontFamily,
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w500,
    color: AppColors.soilTaupe,
  );

  // Label Style - Input labels
  static TextStyle get label => const TextStyle(
    fontFamily: _fontFamily,
    fontSize: 11,
    height: 14 / 11,
    fontWeight: FontWeight.w600,
    color: AppColors.soilTaupe,
    letterSpacing: 0.5,
  );

  // Button text styles
  static TextStyle get buttonLarge =>
      bodyLG.copyWith(fontWeight: FontWeight.w600, color: Colors.white);

  static TextStyle get buttonMedium =>
      body.copyWith(fontWeight: FontWeight.w600, color: Colors.white);

  static TextStyle get buttonSmall => caption.copyWith(
    fontWeight: FontWeight.w600,
    fontSize: 14,
    height: 18 / 14,
  );

  // Special text styles for MarketSnap branding
  static TextStyle get brandTitle => display.copyWith(
    fontWeight: FontWeight.w800,
    letterSpacing: 1.5,
    color: AppColors.marketBlue,
  );

  static TextStyle get brandSubtitle => bodyLG.copyWith(
    fontWeight: FontWeight.w500,
    color: AppColors.soilTaupe,
    letterSpacing: 0.2,
  );

  // Error and success text styles
  static TextStyle get errorText =>
      body.copyWith(color: AppColors.appleRed, fontWeight: FontWeight.w500);

  static TextStyle get successText =>
      body.copyWith(color: AppColors.leafGreen, fontWeight: FontWeight.w500);

  static TextStyle get warningText => body.copyWith(
    color: AppColors.harvestOrange,
    fontWeight: FontWeight.w500,
  );

  // Input text styles
  static TextStyle get inputText =>
      body.copyWith(color: AppColors.soilCharcoal);

  static TextStyle get inputHint => body.copyWith(color: AppColors.soilTaupe);

  static TextStyle get inputLabel => label.copyWith(color: AppColors.soilTaupe);

  // Complete Material Design TextTheme for ThemeData
  static TextTheme get textTheme => TextTheme(
    displayLarge: display,
    displayMedium: display.copyWith(fontSize: 28, height: 34 / 28),
    displaySmall: h1,
    headlineLarge: h1,
    headlineMedium: h1.copyWith(fontSize: 24, height: 30 / 24),
    headlineSmall: h2,
    titleLarge: h2,
    titleMedium: h2.copyWith(
      fontSize: 20,
      height: 26 / 20,
      fontWeight: FontWeight.w600,
    ),
    titleSmall: h2.copyWith(
      fontSize: 18,
      height: 24 / 18,
      fontWeight: FontWeight.w600,
    ),
    bodyLarge: bodyLG,
    bodyMedium: body,
    bodySmall: body.copyWith(fontSize: 14, height: 20 / 14),
    labelLarge: label.copyWith(fontSize: 14, height: 18 / 14),
    labelMedium: label.copyWith(fontSize: 12, height: 16 / 12),
    labelSmall: label,
  );

  // Dark theme variations
  static TextTheme get darkTextTheme => textTheme.apply(
    bodyColor: AppColors.textPrimaryDark,
    displayColor: AppColors.textPrimaryDark,
  );

  // Utility methods for text styling
  static TextStyle withColor(TextStyle style, Color color) {
    return style.copyWith(color: color);
  }

  static TextStyle withWeight(TextStyle style, FontWeight weight) {
    return style.copyWith(fontWeight: weight);
  }

  static TextStyle withSize(TextStyle style, double size) {
    return style.copyWith(fontSize: size);
  }

  // Common text style combinations
  static TextStyle get cardTitle =>
      h2.copyWith(color: AppColors.soilCharcoal, fontWeight: FontWeight.w600);

  static TextStyle get cardSubtitle =>
      body.copyWith(color: AppColors.soilTaupe, fontWeight: FontWeight.w400);

  static TextStyle get linkText => body.copyWith(
    color: AppColors.marketBlue,
    fontWeight: FontWeight.w600,
    decoration: TextDecoration.underline,
  );

  // OTP input style (large, bold numbers)
  static TextStyle get otpInput => const TextStyle(
    fontFamily: _fontFamily,
    fontSize: 24,
    height: 30 / 24,
    fontWeight: FontWeight.w700,
    color: AppColors.soilCharcoal,
    letterSpacing: 2.0,
  );

  // Timer/countdown text
  static TextStyle get timerText => const TextStyle(
    fontFamily: _fontFamily,
    fontSize: 18,
    height: 24 / 18,
    fontWeight: FontWeight.w600,
    color: AppColors.marketBlue,
    letterSpacing: 1.0,
  );

  // Price/monetary text
  static TextStyle get priceText => const TextStyle(
    fontFamily: _fontFamily,
    fontSize: 20,
    height: 26 / 20,
    fontWeight: FontWeight.w700,
    color: AppColors.leafGreen,
  );
}
