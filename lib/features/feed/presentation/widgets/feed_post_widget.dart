import 'package:flutter/material.dart';
import 'package:marketsnap/features/feed/domain/models/snap_model.dart';
import 'package:marketsnap/shared/presentation/theme/app_colors.dart';
import 'package:cached_network_image/cached_network_image.dart';

class FeedPostWidget extends StatelessWidget {
  final Snap snap;

  const FeedPostWidget({super.key, required this.snap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          _buildMedia(),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundImage: NetworkImage(snap.vendorAvatarUrl),
          ),
          const SizedBox(width: 12),
          Text(
            snap.vendorName,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildMedia() {
    return CachedNetworkImage(
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
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (snap.caption != null && snap.caption!.isNotEmpty) ...[
            Text(snap.caption!),
            const SizedBox(height: 8),
          ],
          Text(
            'Posted: ${snap.createdAt.toLocal()}',
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }
} 