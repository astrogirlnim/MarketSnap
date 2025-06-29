import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // ✅ ADD: For defaultTargetPlatform
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
          debugPrint('[StoryCarousel] Building story item for: ${story.vendorName}');
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
        if (widget.onStoryTap != null) {
          widget.onStoryTap!(story);
        }
      },
      onLongPress: isCurrentUser ? () => _showStoryDeleteOptions(story) : null,
      child: Container(
        width: 80,
        margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
        child: Column(
          children: [
            Stack(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [AppColors.marketBlue, AppColors.harvestOrange],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  padding: const EdgeInsets.all(2),
                  child: CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.eggshell,
                    backgroundImage: story.vendorAvatarUrl.isNotEmpty
                        ? NetworkImage(_rewriteUrlForCurrentPlatform(story.vendorAvatarUrl))
                        : null,
                    child: story.vendorAvatarUrl.isEmpty
                        ? Text(
                            story.vendorName.isNotEmpty
                                ? story.vendorName[0].toUpperCase()
                                : '?',
                            style: AppTypography.bodyLG.copyWith(
                              color: AppColors.marketBlue,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                    onBackgroundImageError: (exception, stackTrace) {
                      debugPrint('[StoryCarousel] ❌ Avatar load error for ${story.vendorName}: $exception');
                    },
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
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
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

  /// ✅ CROSS-PLATFORM URL REWRITING: Ensures avatars work across iOS/Android emulators
  /// iOS emulator: localhost URLs need to be rewritten to use the device's host
  /// Android emulator: 10.0.2.2 URLs need to be rewritten to use localhost for iOS
  String _rewriteUrlForCurrentPlatform(String originalUrl) {
    // Only rewrite Firebase Storage emulator URLs
    if (!originalUrl.contains('googleapis.com') && 
        (originalUrl.contains('localhost') || originalUrl.contains('10.0.2.2'))) {
      
      debugPrint('[StoryCarousel] 🔄 URL rewriting for cross-platform compatibility');
      debugPrint('[StoryCarousel] - Original URL: $originalUrl');
      
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        // iOS: Convert Android emulator URL to iOS format
        final rewritten = originalUrl.replaceAll('10.0.2.2', 'localhost');
        debugPrint('[StoryCarousel] - iOS rewrite: $rewritten');
        return rewritten;
      } else if (defaultTargetPlatform == TargetPlatform.android) {
        // Android: Convert iOS emulator URL to Android format  
        final rewritten = originalUrl.replaceAll('localhost', '10.0.2.2');
        debugPrint('[StoryCarousel] - Android rewrite: $rewritten');
        return rewritten;
      }
    }
    
    // No rewriting needed for production URLs or non-emulator environments
    return originalUrl;
  }
}
