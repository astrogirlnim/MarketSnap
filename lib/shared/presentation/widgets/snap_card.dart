import 'package:flutter/material.dart';
import '../../../core/models/snap.dart';
import '../../../core/models/vendor.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../theme/app_spacing.dart';
import 'ttl_badge.dart';

/// Snap card widget for displaying individual snaps in the feed
/// Shows vendor info, media, caption, and TTL badge
class SnapCard extends StatelessWidget {
  final Snap snap;
  final Vendor vendor;
  final VoidCallback? onTap;
  final VoidCallback? onVendorTap;
  final VoidCallback? onLike;
  final VoidCallback? onShare;
  final bool isLiked;

  const SnapCard({
    super.key,
    required this.snap,
    required this.vendor,
    this.onTap,
    this.onVendorTap,
    this.onLike,
    this.onShare,
    this.isLiked = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(
        horizontal: AppSpacing.screenPadding,
        vertical: AppSpacing.feedSpacing / 2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Vendor header
          _buildVendorHeader(context),

          // Media content
          _buildMediaContent(context),

          // Caption and actions
          _buildCaptionAndActions(context),
        ],
      ),
    );
  }

  /// Build vendor header with avatar and name
  Widget _buildVendorHeader(BuildContext context) {
    return Padding(
      padding: AppSpacing.cardContent,
      child: Row(
        children: [
          // Vendor avatar
          GestureDetector(
            onTap: onVendorTap,
            child: _buildVendorAvatar(),
          ),

          const SizedBox(width: AppSpacing.sm),

          // Vendor info
          Expanded(
            child: GestureDetector(
              onTap: onVendorTap,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    vendor.stallName,
                    style: AppTypography.feedVendor,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.xs / 2),
                  Text(
                    vendor.marketCity,
                    style: AppTypography.feedTimestamp.copyWith(
                      color: AppColors.soilTaupe,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),

          // Time ago and TTL badge
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _getTimeAgoString(),
                style: AppTypography.feedTimestamp.copyWith(
                  color: AppColors.soilTaupe,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              if (!snap.hasExpired)
                TTLBadge(
                  timeRemaining: snap.timeUntilExpiry,
                  isSmall: true,
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// Build vendor avatar with fallback
  Widget _buildVendorAvatar() {
    return Container(
      width: AppSpacing.avatarMedium,
      height: AppSpacing.avatarMedium,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.seedBrown.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: ClipOval(
        child: vendor.avatarUrl != null && vendor.avatarUrl!.isNotEmpty
            ? Image.network(
                vendor.avatarUrl!,
                width: AppSpacing.avatarMedium,
                height: AppSpacing.avatarMedium,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return _buildAvatarFallback();
                },
                errorBuilder: (context, error, stackTrace) {
                  return _buildAvatarFallback();
                },
              )
            : _buildAvatarFallback(),
      ),
    );
  }

  /// Build fallback avatar with vendor initials
  Widget _buildAvatarFallback() {
    return Container(
      width: AppSpacing.avatarMedium,
      height: AppSpacing.avatarMedium,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.marketBlue.withValues(alpha: 0.7),
            AppColors.harvestOrange.withValues(alpha: 0.7),
          ],
        ),
      ),
      child: Center(
        child: Text(
          vendor.initials,
          style: AppTypography.feedVendor.copyWith(
            color: AppColors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  /// Build media content with placeholder support
  Widget _buildMediaContent(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(
          minHeight: AppSpacing.snapCardMinHeight,
          maxHeight: AppSpacing.snapCardMaxHeight,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.snapCardBorderRadius),
          child: _buildMedia(),
        ),
      ),
    );
  }

  /// Build media widget with loading/error states
  Widget _buildMedia() {
    if (snap.isUploading) {
      return _buildUploadingState();
    }

    final mediaUrl = snap.displayUrl; // Uses thumbnail if available

    return Stack(
      children: [
        // Media image/video
        Image.network(
          mediaUrl,
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return _buildLoadingPlaceholder();
          },
          errorBuilder: (context, error, stackTrace) {
            return _buildErrorPlaceholder();
          },
        ),

        // Video indicator
        if (snap.isVideo) _buildVideoIndicator(),

        // Upload overlay if uploading
        if (snap.isUploading) _buildUploadOverlay(),
      ],
    );
  }

  /// Build uploading state
  Widget _buildUploadingState() {
    return Container(
      height: AppSpacing.snapCardMinHeight,
      color: AppColors.eggshell,
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: AppSpacing.sm),
            Text('Uploading...'),
          ],
        ),
      ),
    );
  }

  /// Build loading placeholder
  Widget _buildLoadingPlaceholder() {
    return Container(
      height: AppSpacing.snapCardMinHeight,
      color: AppColors.eggshell,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              snap.isPhoto ? Icons.image_outlined : Icons.video_library_outlined,
              size: 48,
              color: AppColors.soilTaupe,
            ),
            const SizedBox(height: AppSpacing.sm),
            const CircularProgressIndicator(),
            const SizedBox(height: AppSpacing.sm),
            const Text('Loading...'),
          ],
        ),
      ),
    );
  }

  /// Build error placeholder
  Widget _buildErrorPlaceholder() {
    return Container(
      height: AppSpacing.snapCardMinHeight,
      color: AppColors.eggshell,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: AppColors.appleRed,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Failed to load ${snap.mediaType}',
              style: AppTypography.body.copyWith(
                color: AppColors.appleRed,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build video indicator overlay
  Widget _buildVideoIndicator() {
    return Positioned(
      top: AppSpacing.sm,
      left: AppSpacing.sm,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: AppColors.black.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.play_arrow,
              color: AppColors.white,
              size: 16,
            ),
            const SizedBox(width: AppSpacing.xs),
            if (snap.durationSeconds != null)
              Text(
                _formatDuration(snap.durationSeconds!),
                style: AppTypography.caption.copyWith(
                  color: AppColors.white,
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Build upload overlay
  Widget _buildUploadOverlay() {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.black.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(AppSpacing.snapCardBorderRadius),
        ),
        child: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.white),
          ),
        ),
      ),
    );
  }

  /// Build caption and actions
  Widget _buildCaptionAndActions(BuildContext context) {
    return Padding(
      padding: AppSpacing.cardContent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Caption
          if (snap.caption != null && snap.caption!.isNotEmpty) ...[
            Text(
              snap.caption!,
              style: AppTypography.snapCaption,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppSpacing.sm),
          ],

          // Actions row
          Row(
            children: [
              // Like button
              IconButton(
                onPressed: onLike,
                icon: Icon(
                  isLiked ? Icons.favorite : Icons.favorite_border,
                  color: isLiked ? AppColors.appleRed : AppColors.soilTaupe,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: AppSpacing.touchTarget,
                  minHeight: AppSpacing.touchTarget,
                ),
              ),

              // Share button
              IconButton(
                onPressed: onShare,
                icon: const Icon(
                  Icons.share_outlined,
                  color: AppColors.soilTaupe,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: AppSpacing.touchTarget,
                  minHeight: AppSpacing.touchTarget,
                ),
              ),

              const Spacer(),

              // File size indicator (if available)
              if (snap.fileSizeBytes != null)
                Text(
                  _formatFileSize(snap.fileSizeBytes!),
                  style: AppTypography.caption.copyWith(
                    color: AppColors.soilTaupe,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// Get time ago string
  String _getTimeAgoString() {
    final diff = DateTime.now().difference(snap.createdAt);
    
    if (diff.inDays > 0) {
      return '${diff.inDays}d ago';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}h ago';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}m ago';
    } else {
      return 'now';
    }
  }

  /// Format duration in seconds to readable string
  String _formatDuration(int seconds) {
    if (seconds < 60) {
      return '${seconds}s';
    } else {
      final minutes = seconds ~/ 60;
      final remainingSeconds = seconds % 60;
      return '${minutes}:${remainingSeconds.toString().padLeft(2, '0')}';
    }
  }

  /// Format file size in bytes to readable string
  String _formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '${bytes}B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)}KB';
    } else {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    }
  }
}