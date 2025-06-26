import 'package:flutter/material.dart';
import 'package:marketsnap/features/feed/domain/models/story_item_model.dart';
import 'package:marketsnap/shared/presentation/theme/app_colors.dart';
import 'dart:convert';
import 'dart:typed_data';

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
                    backgroundImage: _getImageProvider(story.vendorAvatarUrl),
                    backgroundColor: AppColors.eggshell,
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

  /// Helper method to get the appropriate ImageProvider for URLs or data URLs
  ImageProvider _getImageProvider(String imageUrl) {
    if (imageUrl.startsWith('data:image/')) {
      // Handle data URL
      try {
        final base64String = imageUrl.split(',')[1];
        final bytes = base64Decode(base64String);
        return MemoryImage(bytes);
      } catch (e) {
        // Fallback to a placeholder if data URL parsing fails
        return const AssetImage('assets/images/icon.png');
      }
    } else {
      // Handle regular URL
      return NetworkImage(imageUrl);
    }
  }
} 