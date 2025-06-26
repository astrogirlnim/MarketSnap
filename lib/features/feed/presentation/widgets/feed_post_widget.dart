import 'package:flutter/material.dart';
import 'package:marketsnap/features/feed/domain/models/snap_model.dart';
import 'package:marketsnap/shared/presentation/theme/app_colors.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:convert';
import 'dart:typed_data';

class FeedPostWidget extends StatelessWidget {
  final Snap snap;
  final bool isCurrentUserPost;

  const FeedPostWidget({
    super.key, 
    required this.snap,
    this.isCurrentUserPost = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      elevation: isCurrentUserPost ? 6 : 4, // Slightly more elevation for user's posts
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isCurrentUserPost 
          ? const BorderSide(color: AppColors.marketBlue, width: 2) // Blue border for user's posts
          : BorderSide.none,
      ),
      child: Container(
        decoration: isCurrentUserPost
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                colors: [
                  AppColors.marketBlue.withOpacity(0.05),
                  Colors.transparent,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            )
          : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            _buildMedia(),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Row(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundImage: _getImageProvider(snap.vendorAvatarUrl),
                backgroundColor: AppColors.eggshell,
              ),
              // Add a blue ring around user's own avatar
              if (isCurrentUserPost)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.marketBlue,
                        width: 2,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      snap.vendorName,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isCurrentUserPost ? AppColors.marketBlue : null,
                      ),
                    ),
                    if (isCurrentUserPost) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.marketBlue,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'You',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (isCurrentUserPost)
                  const Text(
                    'Your post',
                    style: TextStyle(
                      color: AppColors.marketBlue,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedia() {
    // Handle data URLs differently from regular URLs
    if (snap.mediaUrl.startsWith('data:image/')) {
      return Container(
        height: 300,
        width: double.infinity,
        decoration: BoxDecoration(
          image: DecorationImage(
            image: _getImageProvider(snap.mediaUrl),
            fit: BoxFit.cover,
          ),
          border: isCurrentUserPost 
            ? const Border(
                left: BorderSide(color: AppColors.marketBlue, width: 2),
                right: BorderSide(color: AppColors.marketBlue, width: 2),
              )
            : null,
        ),
      );
    }

    // Use CachedNetworkImage for regular URLs
    return Container(
      decoration: isCurrentUserPost 
        ? const BoxDecoration(
            border: Border(
              left: BorderSide(color: AppColors.marketBlue, width: 2),
              right: BorderSide(color: AppColors.marketBlue, width: 2),
            ),
          )
        : null,
      child: CachedNetworkImage(
        imageUrl: snap.mediaUrl,
        placeholder: (context, url) => Container(
          height: 300,
          color: AppColors.eggshell,
          child: const Center(child: CircularProgressIndicator()),
        ),
        errorWidget: (context, url, error) => Container(
          height: 300,
          color: AppColors.eggshell,
          child: const Icon(Icons.error, color: AppColors.appleRed),
        ),
        fit: BoxFit.cover,
      ),
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (snap.caption != null && snap.caption!.isNotEmpty) ...[
            Text(
              snap.caption!,
              style: TextStyle(
                color: isCurrentUserPost ? AppColors.marketBlue : null,
                fontWeight: isCurrentUserPost ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              Text(
                'Posted: ${_formatTimestamp(snap.createdAt)}',
                style: TextStyle(
                  color: isCurrentUserPost ? AppColors.marketBlue.withOpacity(0.8) : Colors.grey, 
                  fontSize: 12,
                ),
              ),
              if (isCurrentUserPost) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.check_circle,
                  size: 16,
                  color: AppColors.leafGreen,
                ),
                const SizedBox(width: 4),
                Text(
                  'Posted',
                  style: TextStyle(
                    color: AppColors.leafGreen,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// Format timestamp for display
  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  /// Helper method to get the appropriate ImageProvider for URLs or data URLs
  ImageProvider _getImageProvider(String imageUrl) {
    if (imageUrl.startsWith('data:image/')) {
      // Handle data URLs
      try {
        final base64String = imageUrl.split(',')[1];
        final bytes = base64Decode(base64String);
        return MemoryImage(bytes);
      } catch (e) {
        print('[FeedPostWidget] Error decoding data URL: $e');
        // Fallback to a simple colored container
        return const AssetImage('assets/images/icon.png'); // Fallback
      }
    } else {
      // Handle regular URLs
      return NetworkImage(imageUrl);
    }
  }
} 