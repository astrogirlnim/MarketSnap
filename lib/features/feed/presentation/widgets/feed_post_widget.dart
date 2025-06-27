import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import '../../domain/models/snap_model.dart';
import '../../application/feed_service.dart';
import '../../../../shared/presentation/theme/app_colors.dart';
import '../../../../shared/presentation/theme/app_typography.dart';
import '../../../../shared/presentation/theme/app_spacing.dart';
import '../../../../core/services/rag_service.dart';
import '../../../../core/models/rag_feedback.dart';
import '../../../../main.dart'; // Import to access global services

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
  // Use global feed service instance
  final FeedService _feedService = feedService;
  
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  bool _isDeleting = false; // Track deletion state

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
            color: AppColors.soilTaupe.withAlpha(26),
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

          // Delete button for current user's posts
          if (widget.isCurrentUserPost) ...[
            const SizedBox(width: AppSpacing.sm),
            _isDeleting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.appleRed,
                    ),
                  )
                : IconButton(
                    onPressed: _showDeleteConfirmation,
                    icon: const Icon(
                      Icons.delete_outline,
                      color: AppColors.appleRed,
                      size: 20,
                    ),
                    tooltip: 'Delete post',
                    visualDensity: VisualDensity.compact,
                  ),
          ],
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
        overlayColor = Colors.orange.withAlpha(77);
      } else if (filterType == 'cool') {
        overlayColor = Colors.blue.withAlpha(77);
      } else if (filterType == 'contrast') {
        overlayColor = Colors.black.withAlpha(77);
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
                      color: AppColors.soilCharcoal.withAlpha(179),
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
        overlayColor = Colors.orange.withAlpha(77);
      } else if (filterType == 'cool') {
        overlayColor = Colors.blue.withAlpha(77);
      } else if (filterType == 'contrast') {
        overlayColor = Colors.black.withAlpha(77);
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
    if (recipe == null || !(_enhancementData?.hasValidRecipe ?? false)) {
      return const SizedBox.shrink();
    }

    debugPrint(
      '[FeedPostWidget] Rendering recipe card: "${recipe.recipeName}" (${recipe.category}, ${recipe.relevanceScore})',
    );

    final recipeHash = _generateRecipeHash(recipe);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.harvestOrange.withAlpha(77),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.soilTaupe.withAlpha(26),
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
                color: AppColors.harvestOrange.withAlpha(26),
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
            subtitle: Text(
              recipe.recipeName,
              style: AppTypography.body.copyWith(
                color: AppColors.harvestOrange,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            trailing: Icon(
              _isRecipeExpanded ? Icons.expand_less : Icons.expand_more,
              color: AppColors.soilTaupe,
            ),
            onTap: () {
              HapticFeedback.lightImpact();
              // This is a tracking action, not feedback.
              _trackAction(
                contentType: 'recipe',
                contentId: recipeHash,
                contentTitle: recipe.recipeName,
                action: RAGFeedbackAction.expand,
                relevanceScore: recipe.relevanceScore,
              );
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
                  const SizedBox(height: AppSpacing.md),
                  // New, isolated feedback widget
                  _FeedbackInteraction(
                    key: ValueKey('recipe_feedback_$recipeHash'),
                    onUpvote: () => _recordFeedback(
                      contentType: 'recipe',
                      contentId: recipeHash,
                      contentTitle: recipe.recipeName,
                      action: RAGFeedbackAction.upvote,
                      relevanceScore: recipe.relevanceScore,
                    ),
                    onDownvote: () => _recordFeedback(
                      contentType: 'recipe',
                      contentId: recipeHash,
                      contentTitle: recipe.recipeName,
                      action: RAGFeedbackAction.downvote,
                      relevanceScore: recipe.relevanceScore,
                    ),
                  ),
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
        border: Border.all(color: AppColors.leafGreen.withAlpha(77)),
        boxShadow: [
          BoxShadow(
            color: AppColors.soilTaupe.withAlpha(26),
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
                color: AppColors.leafGreen.withAlpha(26),
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
            trailing: Icon(
              _isFAQExpanded ? Icons.expand_less : Icons.expand_more,
              color: AppColors.soilTaupe,
            ),
            onTap: () {
              HapticFeedback.lightImpact();
              // Track expand action for first FAQ
              if (faqs.isNotEmpty) {
                _trackAction(
                  contentType: 'faq',
                  contentId: faqs.first.vendorId, // Using vendorId as FAQ ID for now
                  contentTitle: faqs.first.question,
                  action: RAGFeedbackAction.expand,
                  relevanceScore: faqs.first.score,
                );
              }
              setState(() {
                _isFAQExpanded = !_isFAQExpanded;
              });
            },
          ),
          if (_isFAQExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.md),
              child: Column(
                children: faqs
                    .take(3)
                    .map(
                      (faq) => _buildFAQItem(faq),
                    )
                    .toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Build individual FAQ item with feedback buttons
  Widget _buildFAQItem(FAQResult faq) {
    final faqId = '${faq.vendorId}_${faq.question.hashCode}';

    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.eggshell.withAlpha(128),
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
          const SizedBox(height: AppSpacing.md),
          _FeedbackInteraction(
            key: ValueKey('faq_feedback_$faqId'),
            onUpvote: () => _recordFeedback(
              contentType: 'faq',
              contentId: faqId,
              contentTitle: faq.question,
              action: RAGFeedbackAction.upvote,
              relevanceScore: faq.score,
            ),
            onDownvote: () => _recordFeedback(
              contentType: 'faq',
              contentId: faqId,
              contentTitle: faq.question,
              action: RAGFeedbackAction.downvote,
              relevanceScore: faq.score,
            ),
          ),
        ],
      ),
    );
  }

  /// Track user actions (expand, view) without blocking feedback UI
  void _trackAction({
    required String contentType,
    required String contentId,
    required String contentTitle,
    required RAGFeedbackAction action,
    required double relevanceScore,
  }) {
    debugPrint(
      '[FeedPostWidget] Tracking $action action for $contentType: $contentTitle',
    );

    // Record action via RAG service (non-blocking, no UI changes)
    _ragService.recordFeedback(
      snapId: widget.snap.id,
      vendorId: widget.snap.vendorId,
      action: action,
      contentType: contentType == 'recipe' ? RAGContentType.recipe : RAGContentType.faq,
      contentId: contentId,
      contentTitle: contentTitle,
      relevanceScore: relevanceScore,
    );
  }

  /// Record user feedback on RAG suggestions
  void _recordFeedback({
    required String contentType,
    required String contentId,
    required String contentTitle,
    required RAGFeedbackAction action,
    required double relevanceScore,
  }) {
    debugPrint(
      '[FeedPostWidget] Recording $action feedback for $contentType: $contentTitle',
    );

    // Record feedback via RAG service (non-blocking)
    _ragService.recordFeedback(
      snapId: widget.snap.id,
      vendorId: widget.snap.vendorId,
      action: action,
      contentType:
          contentType == 'recipe' ? RAGContentType.recipe : RAGContentType.faq,
      contentId: contentId,
      contentTitle: contentTitle,
      relevanceScore: relevanceScore,
    );

    // Show brief feedback message
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            action == RAGFeedbackAction.upvote
                ? '👍 Helpful! Thanks for the feedback.'
                : '👎 Noted. This helps us improve.',
            style: AppTypography.body.copyWith(color: Colors.white),
          ),
          backgroundColor: action == RAGFeedbackAction.upvote
              ? AppColors.leafGreen
              : AppColors.soilTaupe,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(AppSpacing.md),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    }
  }

  /// Generate consistent recipe hash for tracking
  String _generateRecipeHash(RecipeSnippet recipe) {
    final combinedString = '${recipe.recipeName}_${recipe.ingredients.join('_')}';
    return combinedString.hashCode.toString();
  }

  /// Show confirmation dialog before deleting the snap
  Future<void> _showDeleteConfirmation() async {
    HapticFeedback.mediumImpact();
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Delete ${widget.snap.mediaType == MediaType.video ? 'Video' : 'Photo'}?',
          style: AppTypography.h2.copyWith(
            color: AppColors.soilCharcoal,
          ),
        ),
        content: Text(
          'This action cannot be undone. Your ${widget.snap.mediaType == MediaType.video ? 'video' : 'photo'} and caption will be permanently deleted.',
          style: AppTypography.body.copyWith(
            color: AppColors.soilTaupe,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: AppTypography.bodyLG.copyWith(
                color: AppColors.soilTaupe,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              backgroundColor: AppColors.appleRed.withAlpha(26),
            ),
            child: Text(
              'Delete',
              style: AppTypography.bodyLG.copyWith(
                color: AppColors.appleRed,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteSnap();
    }
  }

  /// Delete the snap using FeedService
  Future<void> _deleteSnap() async {
    debugPrint('[FeedPostWidget] 🗑️ Starting snap deletion for ${widget.snap.id}');
    
    setState(() {
      _isDeleting = true;
    });

    try {
      final success = await _feedService.deleteSnap(widget.snap.id);
      
      if (mounted) {
        if (success) {
          debugPrint('[FeedPostWidget] ✅ Snap deletion successful');
          
          // Show success message
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
                    '${widget.snap.mediaType == MediaType.video ? 'Video' : 'Photo'} deleted successfully',
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
          
          // Note: The UI will automatically update via the FeedService streams
          // No need to manually remove this widget from the UI
          
        } else {
          debugPrint('[FeedPostWidget] ❌ Snap deletion failed');
          
          // Show error message
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
                    'Failed to delete ${widget.snap.mediaType == MediaType.video ? 'video' : 'photo'}. Please try again.',
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
                onPressed: _showDeleteConfirmation,
              ),
            ),
          );
        }
        
        setState(() {
          _isDeleting = false;
        });
      }
      
    } catch (error) {
      debugPrint('[FeedPostWidget] ❌ Snap deletion error: $error');
      
      if (mounted) {
        setState(() {
          _isDeleting = false;
        });
        
        // Show error message
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
              onPressed: _showDeleteConfirmation,
            ),
          ),
        );
      }
    }
  }
}

class _FeedbackInteraction extends StatefulWidget {
  final VoidCallback onUpvote;
  final VoidCallback onDownvote;

  const _FeedbackInteraction({
    super.key,
    required this.onUpvote,
    required this.onDownvote,
  });

  @override
  State<_FeedbackInteraction> createState() => _FeedbackInteractionState();
}

class _FeedbackInteractionState extends State<_FeedbackInteraction> {
  bool _feedbackGiven = false;

  void _handleFeedback(VoidCallback feedbackAction) {
    if (_feedbackGiven) return;
    HapticFeedback.lightImpact();
    setState(() {
      _feedbackGiven = true;
    });
    feedbackAction();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.cornsilk.withAlpha(128),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.seedBrown.withAlpha(51),
        ),
      ),
      child: _feedbackGiven
          ? _buildThanksWidget()
          : _buildPromptWidget(),
    );
  }

  Widget _buildPromptWidget() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Was this helpful?',
          style: AppTypography.body.copyWith(
            color: AppColors.soilCharcoal,
            fontWeight: FontWeight.w600,
          ),
        ),
        Row(
          children: [
            _buildFeedbackButton(
              icon: Icons.thumb_up_outlined,
              label: 'Yes',
              color: AppColors.leafGreen,
              onTap: () => _handleFeedback(widget.onUpvote),
            ),
            const SizedBox(width: AppSpacing.sm),
            _buildFeedbackButton(
              icon: Icons.thumb_down_outlined,
              label: 'No',
              color: AppColors.appleRed,
              onTap: () => _handleFeedback(widget.onDownvote),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildThanksWidget() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.check_circle,
          size: 18,
          color: AppColors.leafGreen,
        ),
        const SizedBox(width: 6),
        Text(
          'Thanks for your feedback!',
          style: AppTypography.body.copyWith(
            color: AppColors.leafGreen,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildFeedbackButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: color.withAlpha(128),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: AppTypography.caption.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
