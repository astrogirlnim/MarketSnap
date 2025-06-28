import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../domain/models/story_item_model.dart';
import '../../application/feed_service.dart';
import '../../../../shared/presentation/theme/app_colors.dart';
import '../../../../shared/presentation/theme/app_typography.dart';
import '../../../../shared/presentation/theme/app_spacing.dart';
import '../../../../main.dart'; // Import to access global services

/// Horizontal carousel widget for displaying vendor stories
/// Shows story rings with progress indicators and vendor names
class StoryCarouselWidget extends StatefulWidget {
  final List<StoryItem> stories;
  final Function(StoryItem)? onStoryTap;

  const StoryCarouselWidget({
    super.key,
    required this.stories,
    this.onStoryTap,
  });

  @override
  State<StoryCarouselWidget> createState() => _StoryCarouselWidgetState();
}

class _StoryCarouselWidgetState extends State<StoryCarouselWidget> {
  // Use global feed service instance
  final FeedService _feedService = feedService;

  // Track which stories are being deleted
  final Set<String> _deletingStoryIds = {};

  @override
  Widget build(BuildContext context) {
    if (widget.stories.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      height: 100,
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        itemCount: widget.stories.length,
        itemBuilder: (context, index) {
          final story = widget.stories[index];
          return _buildStoryItem(story);
        },
      ),
    );
  }

  /// Build individual story item with ring and vendor name
  Widget _buildStoryItem(StoryItem story) {
    final isCurrentUser = _feedService.currentUserId == story.vendorId;
    final isDeleting = _deletingStoryIds.contains(story.vendorId);

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onStoryTap?.call(story);
      },
      onLongPress: isCurrentUser ? () => _showStoryDeleteOptions(story) : null,
      child: Container(
        width: 70,
        margin: const EdgeInsets.only(right: AppSpacing.sm),
        child: Column(
          children: [
            // Story ring with progress indicator and delete overlay
            Stack(
              children: [
                // Progress ring background
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: story.hasUnseenSnaps
                          ? AppColors.harvestOrange
                          : AppColors.seedBrown,
                      width: 2,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(3),
                    child: CircleAvatar(
                      backgroundColor: AppColors.marketBlue,
                      backgroundImage: story.vendorAvatarUrl.isNotEmpty
                          ? NetworkImage(story.vendorAvatarUrl)
                          : null,
                      child: story.vendorAvatarUrl.isEmpty
                          ? Text(
                              story.vendorName.isNotEmpty
                                  ? story.vendorName[0].toUpperCase()
                                  : 'V',
                              style: AppTypography.bodyLG.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            )
                          : null,
                    ),
                  ),
                ),

                // Deleting overlay
                if (isDeleting)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.soilCharcoal.withAlpha(179),
                      ),
                      child: const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),

                // Current user indicator (small badge)
                if (isCurrentUser && !isDeleting)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: AppColors.marketBlue,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1),
                      ),
                      child: const Icon(
                        Icons.person,
                        size: 10,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: AppSpacing.xs),

            // Vendor name
            Text(
              story.vendorName,
              style: AppTypography.caption.copyWith(
                color: isCurrentUser
                    ? AppColors.marketBlue
                    : AppColors.soilCharcoal,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  /// Show delete options for the current user's story
  Future<void> _showStoryDeleteOptions(StoryItem story) async {
    HapticFeedback.mediumImpact();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete Story?',
          style: AppTypography.h2.copyWith(color: AppColors.soilCharcoal),
        ),
        content: Text(
          'This will delete all ${story.snaps.length} ${story.snaps.length == 1 ? 'post' : 'posts'} in this story. This action cannot be undone.',
          style: AppTypography.body.copyWith(color: AppColors.soilTaupe),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: AppTypography.bodyLG.copyWith(
                color: AppColors.soilTaupe,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteStory(story);
            },
            style: TextButton.styleFrom(
              backgroundColor: AppColors.appleRed.withAlpha(26),
            ),
            child: Text(
              'Delete All',
              style: AppTypography.bodyLG.copyWith(
                color: AppColors.appleRed,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Delete all snaps in a story
  Future<void> _deleteStory(StoryItem story) async {
    debugPrint(
      '[StoryCarouselWidget] 🗑️ Starting story deletion for vendor: ${story.vendorId}',
    );
    debugPrint(
      '[StoryCarouselWidget] 📝 Story contains ${story.snaps.length} snaps',
    );

    setState(() {
      _deletingStoryIds.add(story.vendorId);
    });

    int successCount = 0;
    int failureCount = 0;

    try {
      // Delete each snap in the story
      for (int i = 0; i < story.snaps.length; i++) {
        final snap = story.snaps[i];
        debugPrint(
          '[StoryCarouselWidget] 🗑️ Deleting snap ${i + 1}/${story.snaps.length}: ${snap.id}',
        );

        final success = await _feedService.deleteSnap(snap.id);
        if (success) {
          successCount++;
          debugPrint(
            '[StoryCarouselWidget] ✅ Successfully deleted snap: ${snap.id}',
          );
        } else {
          failureCount++;
          debugPrint(
            '[StoryCarouselWidget] ❌ Failed to delete snap: ${snap.id}',
          );
        }
      }

      if (mounted) {
        setState(() {
          _deletingStoryIds.remove(story.vendorId);
        });

        if (failureCount == 0) {
          // All snaps deleted successfully
          debugPrint(
            '[StoryCarouselWidget] 🎉 Story deletion completed successfully',
          );

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Story deleted successfully ($successCount ${successCount == 1 ? 'post' : 'posts'})',
                    style: AppTypography.body.copyWith(color: Colors.white),
                  ),
                ],
              ),
              backgroundColor: AppColors.leafGreen,
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(AppSpacing.md),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
        } else if (successCount > 0) {
          // Partial success
          debugPrint(
            '[StoryCarouselWidget] ⚠️ Story deletion partially completed: $successCount/$successCount+$failureCount',
          );

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(
                    Icons.warning_outlined,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Partially deleted: $successCount succeeded, $failureCount failed',
                      style: AppTypography.body.copyWith(color: Colors.white),
                    ),
                  ),
                ],
              ),
              backgroundColor: AppColors.sunsetAmber,
              duration: const Duration(seconds: 5),
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(AppSpacing.md),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
        } else {
          // Complete failure
          debugPrint(
            '[StoryCarouselWidget] ❌ Story deletion completely failed',
          );

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Failed to delete story. Please try again.',
                    style: AppTypography.body.copyWith(color: Colors.white),
                  ),
                ],
              ),
              backgroundColor: AppColors.appleRed,
              duration: const Duration(seconds: 5),
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(AppSpacing.md),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              action: SnackBarAction(
                label: 'Retry',
                textColor: Colors.white,
                onPressed: () => _showStoryDeleteOptions(story),
              ),
            ),
          );
        }
      }
    } catch (error) {
      debugPrint('[StoryCarouselWidget] ❌ Story deletion error: $error');

      if (mounted) {
        setState(() {
          _deletingStoryIds.remove(story.vendorId);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'An error occurred while deleting. Please try again.',
                  style: AppTypography.body.copyWith(color: Colors.white),
                ),
              ],
            ),
            backgroundColor: AppColors.appleRed,
            duration: const Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(AppSpacing.md),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _showStoryDeleteOptions(story),
            ),
          ),
        );
      }
    }
  }
}
