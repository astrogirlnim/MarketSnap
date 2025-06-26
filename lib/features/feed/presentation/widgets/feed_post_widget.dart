import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import '../../domain/models/snap_model.dart';
import '../../../../shared/presentation/theme/app_colors.dart';
import '../../../../shared/presentation/theme/app_typography.dart';
import '../../../../shared/presentation/theme/app_spacing.dart';

/// Individual feed post widget displaying a snap with media and interactions
/// Handles both photo and video content with proper aspect ratios
class FeedPostWidget extends StatefulWidget {
  final Snap snap;
  final VoidCallback? onLike;
  final VoidCallback? onComment;
  final VoidCallback? onShare;
  final bool isCurrentUserPost;

  const FeedPostWidget({
    super.key,
    required this.snap,
    this.onLike,
    this.onComment,
    this.onShare,
    this.isCurrentUserPost = false,
  });

  @override
  State<FeedPostWidget> createState() => _FeedPostWidgetState();
}

class _FeedPostWidgetState extends State<FeedPostWidget> {
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  /// Initialize video player if the snap contains video content
  void _initializeVideo() {
    if (widget.snap.mediaType == MediaType.video &&
        widget.snap.mediaUrl.isNotEmpty) {
      _videoController = VideoPlayerController.file(File(widget.snap.mediaUrl))
        ..initialize().then((_) {
          if (mounted) {
            setState(() {
              _isVideoInitialized = true;
            });
          }
        });
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.eggshell,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.soilTaupe.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with vendor info
          _buildHeader(),

          // Media content
          _buildMediaContent(),

          // Caption and interactions
          _buildContent(),

          // Action buttons
          _buildActionButtons(),
        ],
      ),
    );
  }

  /// Build the header section with vendor information
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          // Vendor avatar
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.marketBlue,
            child: Text(
              widget.snap.vendorName.isNotEmpty
                  ? widget.snap.vendorName[0].toUpperCase()
                  : 'V',
              style: AppTypography.bodyLG.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),

          // Vendor info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.snap.vendorName,
                  style: AppTypography.h2.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: widget.isCurrentUserPost
                        ? AppColors.marketBlue
                        : AppColors.soilCharcoal,
                  ),
                ),
                if (widget.isCurrentUserPost) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Your post',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.marketBlue,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Timestamp
          Text(
            _formatTimestamp(widget.snap.createdAt),
            style: AppTypography.caption.copyWith(color: AppColors.soilTaupe),
          ),
        ],
      ),
    );
  }

  /// Build the media content section
  Widget _buildMediaContent() {
    if (widget.snap.mediaUrl.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxHeight: 400),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(8),
          bottom: Radius.circular(8),
        ),
        child: widget.snap.mediaType == MediaType.video
            ? _buildVideoPlayer()
            : _buildImageDisplay(),
      ),
    );
  }

  /// Build video player widget
  Widget _buildVideoPlayer() {
    if (_videoController == null || !_isVideoInitialized) {
      return Container(
        height: 300,
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(color: AppColors.marketBlue),
        ),
      );
    }

    return AspectRatio(
      aspectRatio: _videoController!.value.aspectRatio,
      child: Stack(
        children: [
          VideoPlayer(_videoController!),

          // Play/pause overlay
          Positioned.fill(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  if (_videoController!.value.isPlaying) {
                    _videoController!.pause();
                  } else {
                    _videoController!.play();
                  }
                });
              },
              child: Container(
                color: Colors.transparent,
                child: Center(
                  child: AnimatedOpacity(
                    opacity: _videoController!.value.isPlaying ? 0.0 : 1.0,
                    duration: const Duration(milliseconds: 300),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.soilCharcoal.withValues(alpha: 0.7),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.play_arrow,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build image display widget
  Widget _buildImageDisplay() {
    return Image.file(
      File(widget.snap.mediaUrl),
      fit: BoxFit.cover,
      width: double.infinity,
      errorBuilder: (context, error, stackTrace) {
        debugPrint('[FeedPostWidget] Error loading image: $error');
        return Container(
          height: 200,
          color: AppColors.seedBrown,
          child: const Center(
            child: Icon(
              Icons.image_not_supported,
              size: 48,
              color: AppColors.soilTaupe,
            ),
          ),
        );
      },
    );
  }

  /// Build the content section with caption
  Widget _buildContent() {
    if (widget.snap.caption == null || widget.snap.caption!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Text(widget.snap.caption!, style: AppTypography.body),
    );
  }

  /// Build action buttons (like, comment, share)
  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          _buildActionButton(
            icon: Icons.favorite_border,
            label: 'Like',
            onTap: widget.onLike,
          ),
          const SizedBox(width: AppSpacing.lg),
          _buildActionButton(
            icon: Icons.chat_bubble_outline,
            label: 'Comment',
            onTap: widget.onComment,
          ),
          const SizedBox(width: AppSpacing.lg),
          _buildActionButton(
            icon: Icons.share_outlined,
            label: 'Share',
            onTap: widget.onShare,
          ),
        ],
      ),
    );
  }

  /// Build individual action button
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap?.call();
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: AppColors.soilTaupe),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTypography.caption.copyWith(color: AppColors.soilTaupe),
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
      return 'now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }
}
