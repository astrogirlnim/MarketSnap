import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../theme/app_spacing.dart';

/// Widget to display app version information in a subtle way
/// Can be positioned at the bottom of screens or in settings
class VersionDisplayWidget extends StatefulWidget {
  const VersionDisplayWidget({
    super.key,
    this.showBuildNumber = true,
    this.alignment = Alignment.center,
    this.style,
  });

  /// Whether to show the build number along with version
  final bool showBuildNumber;

  /// Text alignment for the version display
  final Alignment alignment;

  /// Custom text style (defaults to caption style)
  final TextStyle? style;

  @override
  State<VersionDisplayWidget> createState() => _VersionDisplayWidgetState();
}

class _VersionDisplayWidgetState extends State<VersionDisplayWidget> {
  String _versionText = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadVersionInfo();
  }

  /// Load version information from package info
  Future<void> _loadVersionInfo() async {
    try {
      debugPrint('[VersionDisplayWidget] Loading package info...');

      final PackageInfo packageInfo = await PackageInfo.fromPlatform();

      // Create version text based on configuration
      String versionText = 'v${packageInfo.version}';

      if (widget.showBuildNumber && packageInfo.buildNumber.isNotEmpty) {
        versionText += ' (${packageInfo.buildNumber})';
      }

      debugPrint('[VersionDisplayWidget] Version loaded: $versionText');

      if (mounted) {
        setState(() {
          _versionText = versionText;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[VersionDisplayWidget] Error loading version info: $e');

      if (mounted) {
        setState(() {
          _versionText = 'Version unavailable';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox.shrink(); // Hide while loading
    }

    return Container(
      alignment: widget.alignment,
      child: Text(
        _versionText,
        style:
            widget.style ??
            AppTypography.caption.copyWith(
              color: AppColors.soilTaupe.withValues(alpha: 0.7),
              fontSize: 10,
            ),
        textAlign: _getTextAlign(),
      ),
    );
  }

  /// Convert alignment to TextAlign
  TextAlign _getTextAlign() {
    switch (widget.alignment) {
      case Alignment.centerLeft:
      case Alignment.topLeft:
      case Alignment.bottomLeft:
        return TextAlign.left;
      case Alignment.centerRight:
      case Alignment.topRight:
      case Alignment.bottomRight:
        return TextAlign.right;
      case Alignment.center:
      case Alignment.topCenter:
      case Alignment.bottomCenter:
      default:
        return TextAlign.center;
    }
  }
}

/// Compact version display for corners of screens
class CompactVersionDisplay extends StatelessWidget {
  const CompactVersionDisplay({
    super.key,
    this.position = Alignment.bottomRight,
    this.padding,
  });

  /// Position of the version display on screen
  final Alignment position;

  /// Custom padding (defaults to small padding)
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        alignment: position,
        padding: padding ?? const EdgeInsets.all(AppSpacing.sm),
        child: const VersionDisplayWidget(
          showBuildNumber: false,
          alignment: Alignment.center,
        ),
      ),
    );
  }
}

/// Debug version display with additional information
class DebugVersionDisplay extends StatefulWidget {
  const DebugVersionDisplay({super.key});

  @override
  State<DebugVersionDisplay> createState() => _DebugVersionDisplayState();
}

class _DebugVersionDisplayState extends State<DebugVersionDisplay> {
  PackageInfo? _packageInfo;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDebugInfo();
  }

  Future<void> _loadDebugInfo() async {
    try {
      final PackageInfo packageInfo = await PackageInfo.fromPlatform();

      if (mounted) {
        setState(() {
          _packageInfo = packageInfo;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[DebugVersionDisplay] Error loading package info: $e');

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _packageInfo == null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Debug Info',
            style: AppTypography.caption.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'App: ${_packageInfo!.appName}',
            style: AppTypography.caption.copyWith(color: Colors.white70),
          ),
          Text(
            'Package: ${_packageInfo!.packageName}',
            style: AppTypography.caption.copyWith(color: Colors.white70),
          ),
          Text(
            'Version: ${_packageInfo!.version}',
            style: AppTypography.caption.copyWith(color: Colors.white70),
          ),
          Text(
            'Build: ${_packageInfo!.buildNumber}',
            style: AppTypography.caption.copyWith(color: Colors.white70),
          ),
          Text(
            'Build Signature: ${_packageInfo!.buildSignature}',
            style: AppTypography.caption.copyWith(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}
