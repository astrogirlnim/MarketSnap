import 'package:flutter/material.dart';
import 'package:marketsnap/features/feed/domain/models/story_item_model.dart';
import 'package:marketsnap/shared/presentation/theme/app_colors.dart';

class StoryCarouselWidget extends StatelessWidget {
  final List<StoryItem> stories;

  const StoryCarouselWidget({super.key, required this.stories});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 110,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: stories.length,
        itemBuilder: (context, index) {
          final story = stories[index];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Column(
              children: [
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: story.hasUnseenSnaps ? AppColors.harvestOrange : Colors.grey,
                      width: 3,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 32,
                    backgroundImage: NetworkImage(story.vendorAvatarUrl),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  story.vendorName,
                  style: const TextStyle(fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
} 