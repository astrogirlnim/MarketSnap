/// MarketSnap spacing system based on 4px grid
/// Following the design system guidelines
class AppSpacing {
  // Prevent instantiation
  AppSpacing._();

  // ======================================
  // BASE SPACING SCALE (4px grid)
  // ======================================

  /// Extra small spacing: 4px
  static const double xs = 4.0;

  /// Small spacing: 8px
  static const double sm = 8.0;

  /// Medium spacing: 16px
  static const double md = 16.0;

  /// Large spacing: 24px
  static const double lg = 24.0;

  /// Extra large spacing: 32px
  static const double xl = 32.0;

  /// Extra extra large spacing: 48px
  static const double xxl = 48.0;

  // ======================================
  // SEMANTIC SPACING
  // ======================================

  /// Padding inside cards and containers
  static const double cardPadding = md;

  /// Padding for screen edges
  static const double screenPadding = md;

  /// Spacing between list items
  static const double listItemSpacing = sm;

  /// Spacing between sections
  static const double sectionSpacing = lg;

  /// Spacing for buttons
  static const double buttonPadding = md;

  /// Small button padding
  static const double buttonPaddingSmall = sm;

  /// Icon padding/margin
  static const double iconSpacing = sm;

  /// Story item spacing
  static const double storySpacing = sm;

  /// Feed item spacing
  static const double feedSpacing = md;

  // ======================================
  // COMPONENT-SPECIFIC SPACING
  // ======================================

  /// Story carousel height
  static const double storyCarouselHeight = 120.0;

  /// Story circle size
  static const double storyCircleSize = 80.0;

  /// Story circle border width
  static const double storyBorderWidth = 3.0;

  /// Snap card aspect ratio spacing
  static const double snapCardBorderRadius = 12.0;

  /// TTL badge size
  static const double ttlBadgeSize = 24.0;

  /// Avatar size (small)
  static const double avatarSmall = 32.0;

  /// Avatar size (medium)
  static const double avatarMedium = 48.0;

  /// Avatar size (large)
  static const double avatarLarge = 80.0;

  /// Minimum touch target size (accessibility)
  static const double touchTarget = 48.0;

  // ======================================
  // LAYOUT SPACING
  // ======================================

  /// Safe area padding
  static const double safeAreaPadding = md;

  /// Navigation bar height
  static const double navigationHeight = 60.0;

  /// Tab bar height
  static const double tabBarHeight = 50.0;

  /// App bar height
  static const double appBarHeight = 56.0;

  /// Bottom sheet drag handle space
  static const double bottomSheetHandle = lg;

  // ======================================
  // SNAP SPECIFIC SPACING
  // ======================================

  /// Snap card minimum height
  static const double snapCardMinHeight = 200.0;

  /// Snap card maximum height
  static const double snapCardMaxHeight = 400.0;

  /// Story viewer padding
  static const double storyViewerPadding = md;

  /// Caption max lines spacing
  static const double captionLineHeight = 20.0;

  /// Story progress bar height
  static const double storyProgressHeight = 3.0;

  // ======================================
  // UTILITY METHODS
  // ======================================

  /// Get spacing value by name
  static double getSpacing(String name) {
    switch (name) {
      case 'xs':
        return xs;
      case 'sm':
        return sm;
      case 'md':
        return md;
      case 'lg':
        return lg;
      case 'xl':
        return xl;
      case 'xxl':
        return xxl;
      default:
        return md; // Default to medium
    }
  }

  /// Get padding with all sides equal
  static EdgeInsets all(double value) => EdgeInsets.all(value);

  /// Get symmetric padding
  static EdgeInsets symmetric({double horizontal = 0, double vertical = 0}) {
    return EdgeInsets.symmetric(horizontal: horizontal, vertical: vertical);
  }

  /// Get padding with individual sides
  static EdgeInsets only({
    double left = 0,
    double top = 0,
    double right = 0,
    double bottom = 0,
  }) {
    return EdgeInsets.only(left: left, top: top, right: right, bottom: bottom);
  }

  /// Common padding presets
  static EdgeInsets get paddingXS => all(xs);
  static EdgeInsets get paddingSM => all(sm);
  static EdgeInsets get paddingMD => all(md);
  static EdgeInsets get paddingLG => all(lg);
  static EdgeInsets get paddingXL => all(xl);
  static EdgeInsets get paddingXXL => all(xxl);

  /// Screen edge padding
  static EdgeInsets get screenEdge => all(screenPadding);

  /// Card content padding
  static EdgeInsets get cardContent => all(cardPadding);

  /// Button content padding
  static EdgeInsets get buttonContent => symmetric(horizontal: buttonPadding, vertical: sm);

  /// List item padding
  static EdgeInsets get listItem => symmetric(horizontal: md, vertical: sm);
}