import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../domain/models/story_item_model.dart';
import '../../../../shared/presentation/theme/app_colors.dart';
import '../../../../shared/presentation/theme/app_typography.dart';
import '../../../../shared/presentation/theme/app_spacing.dart';

/// Horizontal carousel widget for displaying vendor stories
/// Shows story rings with progress indicators and vendor names
class StoryCarouselWidget extends StatelessWidget {
  final List<StoryItem> stories;
  final Function(StoryItem)? onStoryTap;

  const StoryCarouselWidget({
    super.key,
    required this.stories,
    this.onStoryTap,
  });

  @override
  Widget build(BuildContext context) {
    if (stories.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      height: 100,
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        itemCount: stories.length,
        itemBuilder: (context, index) {
          final story = stories[index];
          return _buildStoryItem(story);
        },
      ),
    );
  }

  /// Build individual story item with ring and vendor name
  Widget _buildStoryItem(StoryItem story) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onStoryTap?.call(story);
      },
      child: Container(
        width: 70,
        margin: const EdgeInsets.only(right: AppSpacing.sm),
        child: Column(
          children: [
            // Story ring with progress indicator
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
                      child: Text(
                        story.vendorName.isNotEmpty 
                            ? story.vendorName[0].toUpperCase()
                            : 'V',
                        style: AppTypography.bodyLG.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
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
                color: AppColors.soilCharcoal,
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
} 