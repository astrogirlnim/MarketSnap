import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import '../../application/lut_filter_service.dart';
import '../../../../core/models/pending_media.dart';
import '../../../../main.dart';

/// Review screen for captured media with filter application and post functionality
/// Allows users to apply LUT filters and post their captured content
class MediaReviewScreen extends StatefulWidget {
  final String mediaPath;
  final MediaType mediaType;
  final String? caption;

  const MediaReviewScreen({
    super.key,
    required this.mediaPath,
    required this.mediaType,
    this.caption,
  });

  @override
  State<MediaReviewScreen> createState() => _MediaReviewScreenState();
}

class _MediaReviewScreenState extends State<MediaReviewScreen>
    with TickerProviderStateMixin {
  final LutFilterService _lutFilterService = LutFilterService.instance;
  final TextEditingController _captionController = TextEditingController();

  // Filter state
  LutFilterType _selectedFilter = LutFilterType.none;
  String? _filteredImagePath;
  bool _isApplyingFilter = false;
  bool _isPosting = false;

  // Video player (if media is video)
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;

  // Animation controllers
  late AnimationController _filterAnimationController;
  late Animation<double> _filterAnimation;

  @override
  void initState() {
    super.initState();
    debugPrint(
      '[MediaReviewScreen] Initializing review screen for: ${widget.mediaPath}',
    );

    // Initialize caption with provided text
    if (widget.caption != null) {
      _captionController.text = widget.caption!;
    }

    // Initialize animation controller
    _filterAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _filterAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _filterAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    // Initialize video player if media is video
    if (widget.mediaType == MediaType.video) {
      _initializeVideoPlayer();
    }

    // Initialize LUT filter service
    _initializeLutService();
  }

  @override
  void dispose() {
    debugPrint('[MediaReviewScreen] Disposing review screen');

    _captionController.dispose();
    _filterAnimationController.dispose();
    _videoController?.dispose();

    // Clean up filtered image if it exists
    if (_filteredImagePath != null && _filteredImagePath != widget.mediaPath) {
      _cleanupFilteredImage();
    }

    // Clear preview cache to free memory
    _lutFilterService.clearPreviewCache();

    super.dispose();
  }

  /// Initialize LUT filter service
  Future<void> _initializeLutService() async {
    debugPrint('[MediaReviewScreen] Initializing LUT filter service...');
    try {
      await _lutFilterService.initialize();
      debugPrint(
        '[MediaReviewScreen] LUT filter service initialized successfully',
      );
    } catch (e) {
      debugPrint(
        '[MediaReviewScreen] Error initializing LUT filter service: $e',
      );
    }
  }

  /// Initialize video player for video media
  Future<void> _initializeVideoPlayer() async {
    debugPrint(
      '[MediaReviewScreen] Initializing video player for: ${widget.mediaPath}',
    );

    try {
      _videoController = VideoPlayerController.file(File(widget.mediaPath));
      await _videoController!.initialize();

      // Set video to loop and start playing
      await _videoController!.setLooping(true);
      await _videoController!.play();

      if (mounted) {
        setState(() {
          _isVideoInitialized = true;
        });
      }

      debugPrint('[MediaReviewScreen] Video player initialized successfully');
    } catch (e) {
      debugPrint('[MediaReviewScreen] Error initializing video player: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading video: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Apply selected filter to the image
  Future<void> _applyFilter(LutFilterType filterType) async {
    if (widget.mediaType == MediaType.video) {
      debugPrint(
        '[MediaReviewScreen] Filter application not supported for videos',
      );
      return;
    }

    debugPrint(
      '[MediaReviewScreen] Applying filter: ${filterType.displayName}',
    );

    setState(() {
      _isApplyingFilter = true;
      _selectedFilter = filterType;
    });

    try {
      // Clean up previous filtered image
      if (_filteredImagePath != null &&
          _filteredImagePath != widget.mediaPath) {
        await _cleanupFilteredImage();
      }

      // Apply the filter
      final String? filteredPath = await _lutFilterService.applyFilterToImage(
        inputImagePath: widget.mediaPath,
        filterType: filterType,
      );

      if (filteredPath != null) {
        setState(() {
          _filteredImagePath = filteredPath;
        });

        // Animate filter application
        _filterAnimationController.forward().then((_) {
          _filterAnimationController.reset();
        });

        debugPrint(
          '[MediaReviewScreen] Filter applied successfully: $filteredPath',
        );
      } else {
        throw Exception('Failed to apply filter');
      }
    } catch (e) {
      debugPrint('[MediaReviewScreen] Error applying filter: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error applying filter: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isApplyingFilter = false;
        });
      }
    }
  }

  /// Clean up filtered image file
  Future<void> _cleanupFilteredImage() async {
    if (_filteredImagePath != null && _filteredImagePath != widget.mediaPath) {
      try {
        final File filteredFile = File(_filteredImagePath!);
        if (await filteredFile.exists()) {
          await filteredFile.delete();
          debugPrint(
            '[MediaReviewScreen] Cleaned up filtered image: $_filteredImagePath',
          );
        }
      } catch (e) {
        debugPrint('[MediaReviewScreen] Error cleaning up filtered image: $e');
      }
    }
  }

  /// Post the media with applied filters and caption
  Future<void> _postMedia() async {
    debugPrint('[MediaReviewScreen] Posting media...');

    setState(() {
      _isPosting = true;
    });

    try {
      // Determine the final media path (filtered or original)
      final String finalMediaPath = _filteredImagePath ?? widget.mediaPath;
      final String caption = _captionController.text.trim();

      debugPrint('[MediaReviewScreen] Final media path: $finalMediaPath');
      debugPrint('[MediaReviewScreen] Caption: $caption');

      // Create pending media item for upload queue
      final PendingMediaItem pendingItem = PendingMediaItem(
        filePath: finalMediaPath,
        mediaType: widget.mediaType,
        caption: caption.isNotEmpty ? caption : null,
        location: null, // TODO: Add location support in future
      );

      // Add to Hive queue for background upload
      await hiveService.addPendingMedia(pendingItem);

      debugPrint(
        '[MediaReviewScreen] Media added to upload queue: ${pendingItem.id}',
      );

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Media posted successfully! Uploading in background...'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );

        // Navigate back to camera (or main screen)
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      debugPrint('[MediaReviewScreen] Error posting media: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Error posting media: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPosting = false;
        });
      }
    }
  }

  /// Build media preview (image or video)
  Widget _buildMediaPreview() {
    if (widget.mediaType == MediaType.video) {
      return _buildVideoPreview();
    } else {
      return _buildImagePreview();
    }
  }

  /// Build image preview with filter animation
  Widget _buildImagePreview() {
    final String displayPath = _filteredImagePath ?? widget.mediaPath;

    return AnimatedBuilder(
      animation: _filterAnimation,
      builder: (context, child) {
        return Stack(
          children: [
            // Main image
            Container(
              width: double.infinity,
              height: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                image: DecorationImage(
                  image: FileImage(File(displayPath)),
                  fit: BoxFit.cover,
                ),
              ),
            ),

            // Filter application overlay
            if (_isApplyingFilter)
              Container(
                width: double.infinity,
                height: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.black.withValues(alpha: 0.3),
                ),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: Colors.white),
                      SizedBox(height: 16),
                      Text(
                        'Applying filter...',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),

            // Filter animation overlay
            if (_filterAnimation.value > 0)
              Container(
                width: double.infinity,
                height: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.white.withValues(
                    alpha: _filterAnimation.value * 0.3,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  /// Build video preview
  Widget _buildVideoPreview() {
    if (!_isVideoInitialized || _videoController == null) {
      return Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.black,
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 16),
              Text(
                'Loading video...',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AspectRatio(
        aspectRatio: _videoController!.value.aspectRatio,
        child: VideoPlayer(_videoController!),
      ),
    );
  }

  /// Build filter selection row
  Widget _buildFilterSelection() {
    // Video doesn't support filters yet
    if (widget.mediaType == MediaType.video) {
      return const SizedBox.shrink();
    }

    return Container(
      height: 100,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: LutFilterType.values.length,
        // Add caching to prevent rebuilding thumbnails
        cacheExtent: 500,
        itemBuilder: (context, index) {
          final filterType = LutFilterType.values[index];
          final isSelected = _selectedFilter == filterType;

          return GestureDetector(
            onTap: () => _applyFilter(filterType),
            child: Container(
              width: 70,
              margin: const EdgeInsets.only(right: 12),
              child: Column(
                children: [
                  // Filter preview thumbnail
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected
                            ? Colors.deepPurple
                            : Colors.grey.shade300,
                        width: isSelected ? 3 : 1,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: _buildFilterThumbnail(filterType),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Filter name
                  Text(
                    filterType.displayName,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: isSelected
                          ? Colors.deepPurple
                          : Colors.grey.shade700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Build filter thumbnail preview
  Widget _buildFilterThumbnail(LutFilterType filterType) {
    if (filterType == LutFilterType.none) {
      // Show original image thumbnail
      return Image.file(
        File(widget.mediaPath),
        fit: BoxFit.cover,
        // Add memory cache optimization
        cacheWidth: 56,
        cacheHeight: 56,
      );
    }

    // For other filters, show a preview with caching and error handling
    return FutureBuilder<Uint8List?>(
      future: _lutFilterService.getFilterPreview(
        inputImagePath: widget.mediaPath,
        filterType: filterType,
        previewSize: 56, // Match the container size
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          // Show simplified loading indicator
          return Container(
            color: Colors.grey.shade200,
            child: Icon(Icons.image, color: Colors.grey.shade400, size: 24),
          );
        } else if (snapshot.hasData && snapshot.data != null) {
          return Image.memory(
            snapshot.data!,
            fit: BoxFit.cover,
            // Add memory cache optimization
            cacheWidth: 56,
            cacheHeight: 56,
          );
        } else {
          // Fallback to original image with filter name overlay
          return Stack(
            children: [
              Image.file(
                File(widget.mediaPath),
                fit: BoxFit.cover,
                cacheWidth: 56,
                cacheHeight: 56,
              ),
              Container(
                color: _getFilterColor(filterType).withValues(alpha: 0.3),
                child: Center(
                  child: Text(
                    filterType.name.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          );
        }
      },
    );
  }

  /// Get color representation for filter type
  Color _getFilterColor(LutFilterType filterType) {
    switch (filterType) {
      case LutFilterType.warm:
        return Colors.orange;
      case LutFilterType.cool:
        return Colors.blue;
      case LutFilterType.contrast:
        return Colors.grey;
      case LutFilterType.none:
        return Colors.transparent;
    }
  }

  /// Build caption input section
  Widget _buildCaptionInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Add a caption',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _captionController,
            maxLines: 2,
            maxLength: 200,
            decoration: InputDecoration(
              hintText:
                  'What\'s the story behind this ${widget.mediaType.name}?',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Colors.deepPurple,
                  width: 2,
                ),
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
        ],
      ),
    );
  }

  /// Build post button
  Widget _buildPostButton() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          onPressed: _isPosting ? null : _postMedia,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 4,
          ),
          child: _isPosting
              ? const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    SizedBox(width: 12),
                    Text('Posting...', style: TextStyle(fontSize: 16)),
                  ],
                )
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.send, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Post',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Set status bar to light content
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
    );

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () {
            debugPrint('[MediaReviewScreen] Back button pressed');
            Navigator.of(context).pop();
          },
          icon: const Icon(Icons.arrow_back, color: Colors.black),
        ),
        title: Text(
          'Review ${widget.mediaType.name.capitalize()}',
          style: const TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          // Share/save options could go here
          IconButton(
            onPressed: () {
              // TODO: Implement share functionality
              debugPrint('[MediaReviewScreen] Share button pressed');
            },
            icon: const Icon(Icons.share, color: Colors.grey),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Media preview section - Fixed height
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.5,
              child: Container(
                margin: const EdgeInsets.all(16),
                child: _buildMediaPreview(),
              ),
            ),

            // Scrollable bottom section
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Filter selection (only for photos)
                    if (widget.mediaType == MediaType.photo)
                      _buildFilterSelection(),

                    // Caption input
                    _buildCaptionInput(),

                    // Post button
                    _buildPostButton(),

                    // Bottom padding for safe area
                    SizedBox(
                      height: MediaQuery.of(context).padding.bottom + 16,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Extension to capitalize strings
extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
