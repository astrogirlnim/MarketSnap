import 'package:flutter/material.dart';

/// MarketSnap Spacing System
/// Based on the design system defined in snap_design.md
/// Uses a 4px grid system for consistent spacing
class AppSpacing {
  // Base spacing unit (4px grid)
  static const double _baseUnit = 4.0;

  // Spacing scale based on 4px grid
  static const double xs = _baseUnit * 1; // 4px
  static const double sm = _baseUnit * 2; // 8px
  static const double md = _baseUnit * 4; // 16px
  static const double lg = _baseUnit * 6; // 24px
  static const double xl = _baseUnit * 8; // 32px
  static const double xxl = _baseUnit * 12; // 48px

  // Additional spacing for larger layouts
  static const double xxxl = _baseUnit * 16; // 64px
  static const double xxxxl = _baseUnit * 20; // 80px

  // Common component-specific spacings

  // Button padding
  static const double buttonPaddingHorizontal = lg; // 24px
  static const double buttonPaddingVertical = md; // 16px
  static const double buttonMinHeight = 56.0; // 48px + padding

  // Input field padding
  static const double inputPaddingHorizontal = md; // 16px
  static const double inputPaddingVertical = md; // 16px
  static const double inputMinHeight = 56.0; // 48px + padding

  // Card padding
  static const double cardPadding = lg; // 24px
  static const double cardMargin = sm; // 8px

  // Screen padding
  static const double screenPaddingHorizontal = lg; // 24px
  static const double screenPaddingVertical = lg; // 24px

  // List item spacing
  static const double listItemPadding = md; // 16px
  static const double listItemSpacing = sm; // 8px

  // Icon sizes (following touch target guidelines)
  static const double iconXs = 16.0;
  static const double iconSm = 20.0;
  static const double iconMd = 24.0;
  static const double iconLg = 32.0;
  static const double iconXl = 48.0;
  static const double iconXxl = 64.0;
  static const double iconXxxl = 80.0;

  // Touch target sizes (minimum 48x48 for accessibility)
  static const double minTouchTarget = 48.0;
  static const double preferredTouchTarget = 56.0;
  static const double largeTouchTarget = 64.0;

  // Border radius (following the 12px radius from snap_design.md)
  static const double radiusXs = 4.0;
  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0; // Primary border radius
  static const double radiusLg = 16.0;
  static const double radiusXl = 24.0;
  static const double radiusXxl = 32.0;
  static const double radiusRound = 999.0; // For circular elements

  // Elevation levels
  static const double elevationNone = 0.0;
  static const double elevationXs = 1.0;
  static const double elevationSm = 2.0;
  static const double elevationMd = 4.0;
  static const double elevationLg = 8.0;
  static const double elevationXl = 16.0;

  // Line heights (relative to font size - defined in typography)
  static const double lineHeightTight = 1.2; // 120%
  static const double lineHeightNormal = 1.5; // 150%
  static const double lineHeightRelaxed = 1.6; // 160%

  // Container constraints
  static const double maxContentWidth = 400.0; // Max width for form content
  static const double maxCardWidth = 600.0; // Max width for cards
  static const double maxScreenWidth = 1200.0; // Max app width

  // Animation durations (matching snap_design.md motion guidelines)
  static const Duration animationFast = Duration(milliseconds: 150); // Snap-In
  static const Duration animationMedium = Duration(
    milliseconds: 300,
  ); // Story Ring Sweep
  static const Duration animationSlow = Duration(milliseconds: 500);
  static const Duration animationPulse = Duration(
    milliseconds: 1000,
  ); // Queue Pulse

  // Common edge insets
  static const edgeInsetsXs = EdgeInsets.all(xs);
  static const edgeInsetsSm = EdgeInsets.all(sm);
  static const edgeInsetsMd = EdgeInsets.all(md);
  static const edgeInsetsLg = EdgeInsets.all(lg);
  static const edgeInsetsXl = EdgeInsets.all(xl);
  static const edgeInsetsXxl = EdgeInsets.all(xxl);

  // Symmetric edge insets
  static const edgeInsetsHorizontalXs = EdgeInsets.symmetric(horizontal: xs);
  static const edgeInsetsHorizontalSm = EdgeInsets.symmetric(horizontal: sm);
  static const edgeInsetsHorizontalMd = EdgeInsets.symmetric(horizontal: md);
  static const edgeInsetsHorizontalLg = EdgeInsets.symmetric(horizontal: lg);
  static const edgeInsetsHorizontalXl = EdgeInsets.symmetric(horizontal: xl);

  static const edgeInsetsVerticalXs = EdgeInsets.symmetric(vertical: xs);
  static const edgeInsetsVerticalSm = EdgeInsets.symmetric(vertical: sm);
  static const edgeInsetsVerticalMd = EdgeInsets.symmetric(vertical: md);
  static const edgeInsetsVerticalLg = EdgeInsets.symmetric(vertical: lg);
  static const edgeInsetsVerticalXl = EdgeInsets.symmetric(vertical: xl);

  // Screen-specific padding
  static const edgeInsetsScreen = EdgeInsets.all(screenPaddingHorizontal);
  static const edgeInsetsScreenHorizontal = EdgeInsets.symmetric(
    horizontal: screenPaddingHorizontal,
  );
  static const edgeInsetsScreenVertical = EdgeInsets.symmetric(
    vertical: screenPaddingVertical,
  );

  // Card-specific spacing
  static const edgeInsetsCard = EdgeInsets.all(cardPadding);
  static const edgeInsetsCardMargin = EdgeInsets.all(cardMargin);

  // Button-specific spacing
  static const edgeInsetsButton = EdgeInsets.symmetric(
    horizontal: buttonPaddingHorizontal,
    vertical: buttonPaddingVertical,
  );

  // Input-specific spacing
  static const edgeInsetsInput = EdgeInsets.symmetric(
    horizontal: inputPaddingHorizontal,
    vertical: inputPaddingVertical,
  );

  // List item spacing
  static const edgeInsetsListItem = EdgeInsets.all(listItemPadding);

  // Utility methods for dynamic spacing
  static double scale(double value, double factor) {
    return value * factor;
  }

  static double responsive(
    double mobile,
    double tablet,
    double desktop,
    double screenWidth,
  ) {
    if (screenWidth >= 1200) return desktop;
    if (screenWidth >= 768) return tablet;
    return mobile;
  }

  // Grid spacing helpers
  static double grid(int multiplier) {
    return _baseUnit * multiplier;
  }

  // Safe area additions (for notched devices)
  static const double safeAreaTop = 44.0; // Typical iOS notch
  static const double safeAreaBottom = 34.0; // Typical iOS home indicator
}
