import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'dart:developer' as developer;

import '../../../../core/models/broadcast.dart';
import '../../../../shared/presentation/theme/app_colors.dart';
import '../../../../shared/presentation/theme/app_typography.dart';
import '../../../../shared/presentation/theme/app_spacing.dart';
import '../../../../shared/presentation/widgets/market_snap_components.dart';

/// Widget for displaying a broadcast message in the feed
/// Shows vendor info, message text, location (if available), and timestamp
class BroadcastWidget extends StatelessWidget {
  final Broadcast broadcast;
  final bool isCurrentUserPost;
  final VoidCallback? onDelete;

  const BroadcastWidget({
    super.key,
    required this.broadcast,
    this.isCurrentUserPost = false,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(
          color: AppColors.seedBrown.withAlpha((0.3 * 255).round()),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with vendor info
          _buildHeader(context),

          // Message content
          _buildMessage(),

          // Location info (if available)
          if (broadcast.hasLocation) _buildLocationInfo(),

          // Footer with timestamp
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          // Broadcast icon
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.marketBlue.withAlpha((0.1 * 255).round()),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: Icon(Icons.campaign, color: AppColors.marketBlue, size: 20),
          ),

          const SizedBox(width: AppSpacing.md),

          // Vendor avatar
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.seedBrown.withAlpha((0.2 * 255).round()),
            backgroundImage: broadcast.vendorAvatarUrl.isNotEmpty
                ? CachedNetworkImageProvider(broadcast.vendorAvatarUrl)
                : null,
            child: broadcast.vendorAvatarUrl.isEmpty
                ? Icon(Icons.store, color: AppColors.seedBrown, size: 20)
                : null,
          ),

          const SizedBox(width: AppSpacing.md),

          // Vendor info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  broadcast.vendorName,
                  style: AppTypography.body.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                if (broadcast.stallName.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    broadcast.stallName,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Delete button for current user's broadcasts
          if (isCurrentUserPost && onDelete != null)
            IconButton(
              onPressed: () => _showDeleteDialog(context),
              icon: Icon(
                Icons.delete_outline,
                color: AppColors.textSecondary,
                size: 20,
              ),
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
        ],
      ),
    );
  }

  Widget _buildMessage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Container(
        width: double.infinity,
        padding: AppSpacing.edgeInsetsCard,
        decoration: BoxDecoration(
          color: AppColors.eggshell,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        child: Text(
          broadcast.message,
          style: AppTypography.body.copyWith(
            color: AppColors.textPrimary,
            height: 1.4,
          ),
        ),
      ),
    );
  }

  Widget _buildLocationInfo() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        0,
      ),
      child: Row(
        children: [
          Icon(Icons.location_on, color: AppColors.leafGreen, size: 16),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              broadcast.locationName ?? 'Market Area',
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          // Distance indicator (could be enhanced with actual distance calculation)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              color: AppColors.leafGreen.withAlpha((0.1 * 255).round()),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: Text(
              'Nearby',
              style: AppTypography.caption.copyWith(
                color: AppColors.leafGreen,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Icon(Icons.access_time, color: AppColors.textSecondary, size: 14),
          const SizedBox(width: AppSpacing.sm),
          Text(
            timeago.format(broadcast.createdAt, allowFromNow: true),
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const Spacer(),
          // Broadcast indicator
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              color: AppColors.marketBlue.withAlpha((0.1 * 255).round()),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: Text(
              'Broadcast',
              style: AppTypography.caption.copyWith(
                color: AppColors.marketBlue,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Broadcast'),
        content: const Text(
          'Are you sure you want to delete this broadcast? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteBroadcast(context);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.appleRed),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _deleteBroadcast(BuildContext context) {
    try {
      developer.log('[BroadcastWidget] Deleting broadcast: ${broadcast.id}');
      onDelete?.call();

      // Show success feedback
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: MarketSnapStatusMessage(
            message: 'Broadcast deleted',
            type: StatusType.success,
            showIcon: true,
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      developer.log('[BroadcastWidget] Error deleting broadcast: $e');

      // Show error feedback
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: MarketSnapStatusMessage(
            message: 'Failed to delete broadcast',
            type: StatusType.error,
            showIcon: true,
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}
