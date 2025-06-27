import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import '../../domain/models/snap_model.dart';
import '../../../../shared/presentation/theme/app_colors.dart';
import '../../../../shared/presentation/theme/app_typography.dart';
import '../../../../shared/presentation/theme/app_spacing.dart';
import '../../../../core/services/rag_service.dart';

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

  // RAG Enhancement State
  final RAGService _ragService = RAGService();
  SnapEnhancementData? _enhancementData;
  bool _isLoadingEnhancements = false;
  bool _hasEnhancementError = false;
  bool _isRecipeExpanded = false;
  bool _isFAQExpanded = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
    _initializeRAGService();
  }

  /// Initialize video player if the snap contains video content
  void _initializeVideo() {
    if (widget.snap.mediaType == MediaType.video &&
        widget.snap.mediaUrl.isNotEmpty) {
      final videoUri = Uri.parse(widget.snap.mediaUrl);
      _videoController = VideoPlayerController.networkUrl(videoUri)
        ..initialize().then((_) {
          if (mounted) {
            setState(() {
              _isVideoInitialized = true;
            });
          }
        });
    }
  }

  /// Initialize RAG service and load enhancements for this snap
  Future<void> _initializeRAGService() async {
    if (widget.snap.caption == null || widget.snap.caption!.isEmpty) {
      debugPrint('[FeedPostWidget] No caption available for RAG enhancements');
      return;
    }

    setState(() {
      _isLoadingEnhancements = true;
      _hasEnhancementError = false;
    });

    try {
      debugPrint(
        '[FeedPostWidget] ========== INITIALIZING RAG SERVICE ==========',
      );
      debugPrint('[FeedPostWidget] Snap ID: ${widget.snap.id}');
      debugPrint('[FeedPostWidget] Caption: "${widget.snap.caption}"');
      debugPrint('[FeedPostWidget] Vendor ID: ${widget.snap.vendorId}');
      debugPrint('[FeedPostWidget] Media Type: ${widget.snap.mediaType}');

      await _ragService.initialize();
      debugPrint('[FeedPostWidget] RAG service initialized successfully');

      final enhancementData = await _ragService.getSnapEnhancements(
        caption: widget.snap.caption!,
        vendorId: widget.snap.vendorId,
        mediaType: widget.snap.mediaType
            .toString()
            .split('.')
            .last, // photo or video
      );

      debugPrint('[FeedPostWidget] ========== RAG SERVICE RESPONSE ==========');
      debugPrint('[FeedPostWidget] Enhancement data received:');
      debugPrint(
        '[FeedPostWidget] - Recipe: ${enhancementData.recipe != null}',
      );
      debugPrint(
        '[FeedPostWidget] - Recipe name: ${enhancementData.recipe?.recipeName}',
      );
      debugPrint(
        '[FeedPostWidget] - Recipe relevance: ${enhancementData.recipe?.relevanceScore}',
      );
      debugPrint(
        '[FeedPostWidget] - FAQs count: ${enhancementData.faqs.length}',
      );
      debugPrint('[FeedPostWidget] - Has data: ${enhancementData.hasData}');
      debugPrint('[FeedPostWidget] - From cache: ${enhancementData.fromCache}');

      if (enhancementData.faqs.isNotEmpty) {
        debugPrint('[FeedPostWidget] FAQ Details:');
        for (int i = 0; i < enhancementData.faqs.length; i++) {
          final faq = enhancementData.faqs[i];
          debugPrint(
            '[FeedPostWidget] FAQ $i: Q="${faq.question}" A="${faq.answer}" Score=${faq.score}',
          );
        }
      } else {
        debugPrint('[FeedPostWidget] No FAQs in enhancement data');
      }

      if (mounted) {
        setState(() {
          _enhancementData = enhancementData;
          _isLoadingEnhancements = false;
        });

        debugPrint(
          '[FeedPostWidget] Enhancement data set in state - Recipe: ${enhancementData.recipe != null}, FAQs: ${enhancementData.faqs.length}',
        );
        debugPrint(
          '[FeedPostWidget] Valid recipe: ${enhancementData.hasValidRecipe}',
        );
        if (enhancementData.recipe != null) {
          debugPrint(
            '[FeedPostWidget] Recipe details - Name: "${enhancementData.recipe!.recipeName}", Category: ${enhancementData.recipe!.category}, Relevance: ${enhancementData.recipe!.relevanceScore}',
          );
        }
        debugPrint(
          '[FeedPostWidget] UI will display: Recipe card=${enhancementData.hasValidRecipe}, FAQ card=${enhancementData.faqs.isNotEmpty}',
        );
      }
    } catch (e) {
      debugPrint('[FeedPostWidget] ========== RAG SERVICE ERROR ==========');
      debugPrint('[FeedPostWidget] Error loading RAG enhancements: $e');
      debugPrint('[FeedPostWidget] Error type: ${e.runtimeType}');
      if (mounted) {
        setState(() {
          _isLoadingEnhancements = false;
          _hasEnhancementError = true;
        });
      }
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

          // RAG Enhancement Cards
          _buildEnhancementCards(),
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
            backgroundImage: widget.snap.vendorAvatarUrl.isNotEmpty
                ? NetworkImage(widget.snap.vendorAvatarUrl)
                : null,
            child: widget.snap.vendorAvatarUrl.isEmpty
                ? Text(
                    widget.snap.vendorName.isNotEmpty
                        ? widget.snap.vendorName[0].toUpperCase()
                        : 'V',
                    style: AppTypography.bodyLG.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  )
                : null,
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
      // Different constraints for videos vs photos
      constraints: widget.snap.mediaType == MediaType.video
          ? null // No height constraint for videos - let them use natural aspect ratio
          : const BoxConstraints(
              maxHeight: 400,
            ), // Keep height constraint for photos
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(8),
          bottom: Radius.circular(8),
        ),
        child: widget.snap.mediaType == MediaType.video
            ? _buildVideoPlayer() // Videos use their natural aspect ratio
            : AspectRatio(
                aspectRatio: 1.0, // Enforce square aspect ratio for photos only
                child: _buildImageDisplay(),
              ),
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

    // Get video aspect ratio
    final videoAspectRatio = _videoController!.value.aspectRatio;

    // Determine overlay color from the snap's filterType
    Color overlayColor = Colors.transparent;
    final filterType = widget.snap.filterType;

    debugPrint(
      '[FeedPostWidget] 🎥 Processing video for snap ${widget.snap.id}',
    );
    debugPrint(
      '[FeedPostWidget] 📐 Video aspect ratio: $videoAspectRatio (${videoAspectRatio > 1 ? 'landscape' : 'portrait'})',
    );
    debugPrint('[FeedPostWidget] 🎨 Video filterType: "$filterType"');

    if (filterType != null && filterType != 'none') {
      if (filterType == 'warm') {
        overlayColor = Colors.orange.withValues(alpha: 0.3);
      } else if (filterType == 'cool') {
        overlayColor = Colors.blue.withValues(alpha: 0.3);
      } else if (filterType == 'contrast') {
        overlayColor = Colors.black.withValues(alpha: 0.3);
      }
    }

    debugPrint(
      '[FeedPostWidget] 🎨 Applied overlay color: $overlayColor for filter: $filterType',
    );

    return AspectRatio(
      aspectRatio: videoAspectRatio, // Use the pre-calculated aspect ratio
      child: Stack(
        alignment: Alignment.center,
        children: [
          VideoPlayer(_videoController!),

          // Filter overlay
          Positioned.fill(child: Container(color: overlayColor)),

          // Play/pause overlay
          GestureDetector(
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
              color: Colors.transparent, // Makes the whole area tappable
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
        ],
      ),
    );
  }

  /// Build image display widget
  Widget _buildImageDisplay() {
    // Determine overlay color from the snap's filterType
    Color overlayColor = Colors.transparent;
    final filterType = widget.snap.filterType;

    debugPrint(
      '[FeedPostWidget] Processing image for snap ${widget.snap.id} with filterType: "$filterType"',
    );

    if (filterType != null && filterType != 'none') {
      if (filterType == 'warm') {
        overlayColor = Colors.orange.withValues(alpha: 0.3);
      } else if (filterType == 'cool') {
        overlayColor = Colors.blue.withValues(alpha: 0.3);
      } else if (filterType == 'contrast') {
        overlayColor = Colors.black.withValues(alpha: 0.3);
      }
    }

    debugPrint(
      '[FeedPostWidget] Applied overlay color: $overlayColor for filter: $filterType',
    );

    return Stack(
      children: [
        // Main image
        Image.network(
          widget.snap.mediaUrl,
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              width: double.infinity,
              height: double.infinity,
              color: Colors.grey[300],
              child: const Center(
                child: CircularProgressIndicator(color: AppColors.marketBlue),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: double.infinity,
              height: double.infinity,
              color: Colors.grey[300],
              child: const Center(
                child: Icon(Icons.error, color: Colors.red, size: 48),
              ),
            );
          },
        ),

        // Filter overlay
        if (overlayColor != Colors.transparent)
          Container(
            width: double.infinity,
            height: double.infinity,
            color: overlayColor,
          ),
      ],
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

  /// Build RAG Enhancement Cards
  Widget _buildEnhancementCards() {
    // Show loading state
    if (_isLoadingEnhancements) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.marketBlue,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'Loading suggestions...',
              style: AppTypography.caption.copyWith(color: AppColors.soilTaupe),
            ),
          ],
        ),
      );
    }

    // Show error state (minimal)
    if (_hasEnhancementError) {
      debugPrint('[FeedPostWidget] RAG enhancements failed to load');
      return const SizedBox.shrink();
    }

    // Show enhancement cards if we have data
    if (_enhancementData?.hasData == true) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(children: [_buildRecipeCard(), _buildFAQCard()]),
      );
    }

    return const SizedBox.shrink();
  }

  /// Build Recipe Card
  Widget _buildRecipeCard() {
    final recipe = _enhancementData?.recipe;
    if (recipe == null) return const SizedBox.shrink();

    // Don't show recipe card for non-food items or empty recipes
    if (recipe.recipeName.isEmpty ||
        recipe.category == 'non_food' ||
        recipe.relevanceScore < 0.3) {
      debugPrint(
        '[FeedPostWidget] Skipping recipe card - non-food item or low relevance: "${recipe.recipeName}" (${recipe.category}, ${recipe.relevanceScore})',
      );
      return const SizedBox.shrink();
    }

    debugPrint(
      '[FeedPostWidget] Rendering recipe card: "${recipe.recipeName}" (${recipe.category}, ${recipe.relevanceScore})',
    );

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.harvestOrange.withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.soilTaupe.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.harvestOrange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.restaurant_menu,
                color: AppColors.harvestOrange,
                size: 20,
              ),
            ),
            title: Text(
              '🍽️ Recipe Suggestion',
              style: AppTypography.bodyLG.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.soilCharcoal,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  recipe.recipeName,
                  style: AppTypography.body.copyWith(
                    color: AppColors.harvestOrange,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                if (!_isRecipeExpanded && recipe.ingredients.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    recipe.ingredients.take(3).join(' • '),
                    style: AppTypography.body.copyWith(
                      color: AppColors.soilTaupe,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (!_isRecipeExpanded) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Tap to see full recipe',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.harvestOrange.withValues(alpha: 0.7),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
            trailing: Icon(
              _isRecipeExpanded ? Icons.expand_less : Icons.expand_more,
              color: AppColors.soilTaupe,
            ),
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() {
                _isRecipeExpanded = !_isRecipeExpanded;
              });
            },
          ),
          if (_isRecipeExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recipe.snippet,
                    style: AppTypography.body.copyWith(
                      color: AppColors.soilCharcoal,
                    ),
                  ),
                  if (recipe.ingredients.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Ingredients:',
                      style: AppTypography.bodyLG.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.soilCharcoal,
                      ),
                    ),
                    const SizedBox(height: 4),
                    ...recipe.ingredients.map(
                      (ingredient) => Text(
                        '• $ingredient',
                        style: AppTypography.body.copyWith(
                          color: AppColors.soilTaupe,
                        ),
                      ),
                    ),
                  ],
                  if (recipe.fromCache) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Icon(
                          Icons.cached,
                          size: 14,
                          color: AppColors.soilTaupe.withValues(alpha: 0.7),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Cached suggestion',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.soilTaupe.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Build FAQ Card
  Widget _buildFAQCard() {
    final faqs = _enhancementData?.faqs ?? [];
    if (faqs.isEmpty) return const SizedBox.shrink();

    debugPrint(
      '[FeedPostWidget] Rendering FAQ card with ${faqs.length} results',
    );

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.leafGreen.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: AppColors.soilTaupe.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.leafGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.help_outline,
                color: AppColors.leafGreen,
                size: 20,
              ),
            ),
            title: Text(
              '❓ Related Questions',
              style: AppTypography.bodyLG.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.soilCharcoal,
              ),
            ),
            subtitle: Text(
              '${faqs.length} answer${faqs.length == 1 ? '' : 's'} found',
              style: AppTypography.body.copyWith(
                color: AppColors.leafGreen,
                fontWeight: FontWeight.w500,
              ),
            ),
            trailing: Icon(
              _isFAQExpanded ? Icons.expand_less : Icons.expand_more,
              color: AppColors.soilTaupe,
            ),
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() {
                _isFAQExpanded = !_isFAQExpanded;
              });
            },
          ),
          if (_isFAQExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                children: faqs
                    .take(3)
                    .map(
                      (faq) => Container(
                        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: AppColors.eggshell.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Q: ${faq.question}',
                              style: AppTypography.body.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppColors.soilCharcoal,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'A: ${faq.answer}',
                              style: AppTypography.body.copyWith(
                                color: AppColors.soilTaupe,
                              ),
                            ),
                            if (faq.score > 0) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.star,
                                    size: 12,
                                    color: AppColors.sunsetAmber,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    '${(faq.score * 100).toInt()}% match',
                                    style: AppTypography.caption.copyWith(
                                      color: AppColors.soilTaupe.withValues(
                                        alpha: 0.7,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
