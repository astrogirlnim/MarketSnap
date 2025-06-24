import 'package:flutter/material.dart';
import '../../../core/models/vendor.dart';
import '../../../core/models/snap.dart';
import '../../../core/models/following.dart';
import '../theme/app_spacing.dart';
import 'story_circle.dart';

/// Horizontal story carousel displaying vendor stories
/// Similar to Snapchat/Instagram story UI
class StoryCarousel extends StatelessWidget {
  final Map<String, List<Snap>> snapsByVendor;
  final Map<String, Vendor> vendors;
  final Map<String, Following> following;
  final String? currentUserUid;
  final Function(String vendorId, List<Snap> snaps)? onStoryTap;
  final VoidCallback? onAddStoryTap;
  final bool isLoading;

  const StoryCarousel({
    super.key,
    required this.snapsByVendor,
    required this.vendors,
    required this.following,
    this.currentUserUid,
    this.onStoryTap,
    this.onAddStoryTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return _buildLoadingState();
    }

    if (snapsByVendor.isEmpty) {
      return _buildEmptyState();
    }

    return Container(
      height: AppSpacing.storyCarouselHeight,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
        itemCount: _getItemCount(),
        itemBuilder: (context, index) => _buildItem(context, index),
      ),
    );
  }

  /// Get total item count (add story + vendor stories)
  int _getItemCount() {
    final baseCount = snapsByVendor.length;
    // Add "Add Story" item if current user is a vendor
    return currentUserUid != null ? baseCount + 1 : baseCount;
  }

  /// Build individual item (Add Story or Vendor Story)
  Widget _buildItem(BuildContext context, int index) {
    // First item is "Add Story" for current user
    if (index == 0 && currentUserUid != null) {
      return Padding(
        padding: EdgeInsets.only(right: AppSpacing.storySpacing),
        child: AddStoryCircle(onTap: onAddStoryTap),
      );
    }

    // Adjust index for vendor stories if "Add Story" is present
    final vendorIndex = currentUserUid != null ? index - 1 : index;
    final vendorIds = snapsByVendor.keys.toList();
    
    if (vendorIndex >= vendorIds.length) {
      return const SizedBox.shrink();
    }

    final vendorId = vendorIds[vendorIndex];
    final vendor = vendors[vendorId];
    final snaps = snapsByVendor[vendorId] ?? [];
    final followingData = following[vendorId];

    if (vendor == null) {
      return const SizedBox.shrink();
    }

    // Check if user has new content (hasn't viewed recently)
    final hasNewContent = followingData?.hasNewContent ?? true;

    return Padding(
      padding: EdgeInsets.only(right: AppSpacing.storySpacing),
      child: StoryCircle(
        vendor: vendor,
        snaps: snaps,
        hasNewContent: hasNewContent,
        onTap: () => onStoryTap?.call(vendorId, snaps),
      ),
    );
  }

  /// Build loading state with shimmer circles
  Widget _buildLoadingState() {
    return Container(
      height: AppSpacing.storyCarouselHeight,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
        itemCount: 5, // Show 5 shimmer placeholders
        itemBuilder: (context, index) {
          return Padding(
            padding: EdgeInsets.only(right: AppSpacing.storySpacing),
            child: const StoryCircleShimmer(),
          );
        },
      ),
    );
  }

  /// Build empty state when no stories available
  Widget _buildEmptyState() {
    return Container(
      height: AppSpacing.storyCarouselHeight,
      padding: AppSpacing.screenEdge,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.photo_camera_outlined,
              size: 32,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'No stories yet',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Follow vendors to see their stories',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Story carousel with refresh indicator
class RefreshableStoryCarousel extends StatelessWidget {
  final Map<String, List<Snap>> snapsByVendor;
  final Map<String, Vendor> vendors;
  final Map<String, Following> following;
  final String? currentUserUid;
  final Function(String vendorId, List<Snap> snaps)? onStoryTap;
  final VoidCallback? onAddStoryTap;
  final VoidCallback? onRefresh;
  final bool isLoading;
  final bool isRefreshing;

  const RefreshableStoryCarousel({
    super.key,
    required this.snapsByVendor,
    required this.vendors,
    required this.following,
    this.currentUserUid,
    this.onStoryTap,
    this.onAddStoryTap,
    this.onRefresh,
    this.isLoading = false,
    this.isRefreshing = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Pull to refresh indicator (if refreshing)
        if (isRefreshing)
          Container(
            padding: EdgeInsets.all(AppSpacing.sm),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ),

        // Story carousel
        StoryCarousel(
          snapsByVendor: snapsByVendor,
          vendors: vendors,
          following: following,
          currentUserUid: currentUserUid,
          onStoryTap: onStoryTap,
          onAddStoryTap: onAddStoryTap,
          isLoading: isLoading,
        ),
      ],
    );
  }
}

/// Story carousel section with header
class StoryCarouselSection extends StatelessWidget {
  final String title;
  final Map<String, List<Snap>> snapsByVendor;
  final Map<String, Vendor> vendors;
  final Map<String, Following> following;
  final String? currentUserUid;
  final Function(String vendorId, List<Snap> snaps)? onStoryTap;
  final VoidCallback? onAddStoryTap;
  final VoidCallback? onRefresh;
  final VoidCallback? onSeeAll;
  final bool isLoading;
  final bool isRefreshing;
  final bool showSeeAll;

  const StoryCarouselSection({
    super.key,
    this.title = 'Stories',
    required this.snapsByVendor,
    required this.vendors,
    required this.following,
    this.currentUserUid,
    this.onStoryTap,
    this.onAddStoryTap,
    this.onRefresh,
    this.onSeeAll,
    this.isLoading = false,
    this.isRefreshing = false,
    this.showSeeAll = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Padding(
          padding: AppSpacing.screenEdge,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (showSeeAll && snapsByVendor.isNotEmpty)
                TextButton(
                  onPressed: onSeeAll,
                  child: const Text('See All'),
                ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.sm),

        // Story carousel
        RefreshableStoryCarousel(
          snapsByVendor: snapsByVendor,
          vendors: vendors,
          following: following,
          currentUserUid: currentUserUid,
          onStoryTap: onStoryTap,
          onAddStoryTap: onAddStoryTap,
          onRefresh: onRefresh,
          isLoading: isLoading,
          isRefreshing: isRefreshing,
        ),
      ],
    );
  }
}