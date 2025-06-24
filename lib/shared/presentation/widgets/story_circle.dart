import 'package:flutter/material.dart';
import '../../../core/models/vendor.dart';
import '../../../core/models/snap.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../theme/app_spacing.dart';
import 'ttl_badge.dart';

/// Story circle widget that displays vendor avatar with story ring
/// Mimics Snapchat story UI with TTL badge
class StoryCircle extends StatelessWidget {
  final Vendor vendor;
  final List<Snap> snaps;
  final bool hasNewContent;
  final VoidCallback? onTap;

  const StoryCircle({
    super.key,
    required this.vendor,
    required this.snaps,
    this.hasNewContent = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasStories = snaps.isNotEmpty;
    final latestSnap = hasStories ? snaps.first : null;
    final timeRemaining = latestSnap?.timeUntilExpiry ?? Duration.zero;

    return GestureDetector(
      onTap: hasStories ? onTap : null,
      child: Container(
        width: AppSpacing.storyCircleSize + AppSpacing.md,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Story circle with ring
            Stack(
              children: [
                // Story ring (border)
                Container(
                  width: AppSpacing.storyCircleSize,
                  height: AppSpacing.storyCircleSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _getStoryRingColor(hasStories, hasNewContent),
                      width: AppSpacing.storyBorderWidth,
                    ),
                  ),
                  child: Container(
                    margin: EdgeInsets.all(AppSpacing.storyBorderWidth),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.eggshell,
                    ),
                    child: _buildAvatar(),
                  ),
                ),

                // TTL badge (top right)
                if (hasStories && timeRemaining.inSeconds > 0)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: AnimatedTTLBadge(
                      timeRemaining: timeRemaining,
                      isSmall: true,
                    ),
                  ),

                // New content indicator (top left)
                if (hasNewContent)
                  Positioned(
                    top: AppSpacing.xs,
                    left: AppSpacing.xs,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        color: AppColors.leafGreen,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: AppSpacing.xs),

            // Vendor name
            Text(
              vendor.stallName,
              style: AppTypography.storyVendor.copyWith(
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  /// Build vendor avatar with fallback to initials
  Widget _buildAvatar() {
    if (vendor.avatarUrl != null && vendor.avatarUrl!.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          vendor.avatarUrl!,
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return _buildAvatarFallback();
          },
          errorBuilder: (context, error, stackTrace) {
            return _buildAvatarFallback();
          },
        ),
      );
    } else {
      return _buildAvatarFallback();
    }
  }

  /// Build fallback avatar with vendor initials
  Widget _buildAvatarFallback() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.marketBlue.withValues(alpha: 0.8),
            AppColors.harvestOrange.withValues(alpha: 0.8),
          ],
        ),
      ),
      child: Center(
        child: Text(
          vendor.initials,
          style: AppTypography.h2.copyWith(
            color: AppColors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  /// Get story ring color based on status
  Color _getStoryRingColor(bool hasStories, bool hasNewContent) {
    if (!hasStories) {
      return AppColors.soilTaupe.withValues(alpha: 0.3);
    }
    
    if (hasNewContent) {
      return AppColors.storyUnviewed;
    } else {
      return AppColors.storyViewed;
    }
  }
}

/// Story circle for "Add Your Story" button
class AddStoryCircle extends StatelessWidget {
  final VoidCallback? onTap;

  const AddStoryCircle({
    super.key,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: AppSpacing.storyCircleSize + AppSpacing.md,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Add story circle
            Container(
              width: AppSpacing.storyCircleSize,
              height: AppSpacing.storyCircleSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.harvestOrange,
                  width: AppSpacing.storyBorderWidth,
                ),
              ),
              child: Container(
                margin: EdgeInsets.all(AppSpacing.storyBorderWidth),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.eggshell,
                ),
                child: Stack(
                  children: [
                    // Background gradient
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.harvestOrange.withValues(alpha: 0.1),
                            AppColors.marketBlue.withValues(alpha: 0.1),
                          ],
                        ),
                      ),
                    ),

                    // Plus icon
                    const Center(
                      child: Icon(
                        Icons.add,
                        color: AppColors.harvestOrange,
                        size: 32,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.xs),

            // Label
            Text(
              'Your Story',
              style: AppTypography.storyVendor.copyWith(
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Shimmer loading placeholder for story circles
class StoryCircleShimmer extends StatefulWidget {
  const StoryCircleShimmer({super.key});

  @override
  State<StoryCircleShimmer> createState() => _StoryCircleShimmerState();
}

class _StoryCircleShimmerState extends State<StoryCircleShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppSpacing.storyCircleSize + AppSpacing.md,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Shimmer circle
          AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return Container(
                width: AppSpacing.storyCircleSize,
                height: AppSpacing.storyCircleSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment(-1.0 + 2.0 * _animation.value, 0.0),
                    end: Alignment(1.0 + 2.0 * _animation.value, 0.0),
                    colors: [
                      AppColors.soilTaupe.withValues(alpha: 0.1),
                      AppColors.soilTaupe.withValues(alpha: 0.3),
                      AppColors.soilTaupe.withValues(alpha: 0.1),
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: AppSpacing.xs),

          // Shimmer text
          AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return Container(
                width: AppSpacing.storyCircleSize * 0.8,
                height: 12,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  gradient: LinearGradient(
                    begin: Alignment(-1.0 + 2.0 * _animation.value, 0.0),
                    end: Alignment(1.0 + 2.0 * _animation.value, 0.0),
                    colors: [
                      AppColors.soilTaupe.withValues(alpha: 0.1),
                      AppColors.soilTaupe.withValues(alpha: 0.3),
                      AppColors.soilTaupe.withValues(alpha: 0.1),
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}