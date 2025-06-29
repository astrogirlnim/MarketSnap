import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../domain/models/story_item_model.dart';
import '../../domain/models/snap_model.dart' as snap_models;
import '../../../../shared/presentation/theme/app_colors.dart';
import '../../../../shared/presentation/theme/app_typography.dart';

/// Story viewer screen that displays stories from different vendors
/// Allows horizontal swiping between vendors and auto-advance through individual snaps
class StoryViewerScreen extends StatefulWidget {
  final List<StoryItem> stories;
  final int initialStoryIndex;

  const StoryViewerScreen({
    super.key,
    required this.stories,
    this.initialStoryIndex = 0,
  });

  @override
  State<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends State<StoryViewerScreen>
    with TickerProviderStateMixin {
  
  // Page controllers
  late PageController _storyPageController;
  late PageController _snapPageController;
  
  // Current indices
  int _currentStoryIndex = 0;
  int _currentSnapIndex = 0;
  
  // Progress animation controllers
  late List<AnimationController> _progressControllers;
  late List<Animation<double>> _progressAnimations;
  
  // Video player controller
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  
  // Auto-advance timer
  Timer? _autoAdvanceTimer;
  bool _isPaused = false;
  
  // Story duration constants
  static const Duration _imageDuration = Duration(seconds: 5);
  static const Duration _videoDuration = Duration(seconds: 10);

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _initializeProgressAnimations();
    _currentStoryIndex = widget.initialStoryIndex.clamp(0, widget.stories.length - 1);
    _startCurrentSnap();
  }

  @override
  void dispose() {
    _disposeControllers();
    _autoAdvanceTimer?.cancel();
    _videoController?.dispose();
    super.dispose();
  }

  /// Initialize page controllers
  void _initializeControllers() {
    _storyPageController = PageController(initialPage: widget.initialStoryIndex);
    _snapPageController = PageController();
  }

  /// Initialize progress animations for current story
  void _initializeProgressAnimations() {
    final currentStory = widget.stories[_currentStoryIndex];
    _progressControllers = List.generate(
      currentStory.snaps.length,
      (index) => AnimationController(
        duration: _getSnapDuration(currentStory.snaps[index]),
        vsync: this,
      ),
    );
    
    _progressAnimations = _progressControllers.map((controller) =>
      Tween<double>(begin: 0.0, end: 1.0).animate(controller)
    ).toList();
  }

  /// Dispose all controllers
  void _disposeControllers() {
    _storyPageController.dispose();
    _snapPageController.dispose();
    for (final controller in _progressControllers) {
      controller.dispose();
    }
  }

  /// Get duration for a snap based on media type
  Duration _getSnapDuration(snap_models.Snap snap) {
    return snap.mediaType == snap_models.MediaType.video ? _videoDuration : _imageDuration;
  }

  /// Start playing the current snap
  void _startCurrentSnap() {
    final currentStory = widget.stories[_currentStoryIndex];
    final currentSnap = currentStory.snaps[_currentSnapIndex];
    
    debugPrint('[StoryViewer] Starting snap ${_currentSnapIndex + 1}/${currentStory.snaps.length} for vendor ${currentStory.vendorName}');
    
    // Initialize video if needed
    if (currentSnap.mediaType == snap_models.MediaType.video) {
      _initializeVideo(currentSnap.mediaUrl);
    } else {
      _videoController?.dispose();
      _videoController = null;
      _isVideoInitialized = false;
    }
    
    // Start progress animation
    if (_currentSnapIndex < _progressControllers.length) {
      _progressControllers[_currentSnapIndex].forward();
      
      // Set up auto-advance timer
      _autoAdvanceTimer?.cancel();
      _autoAdvanceTimer = Timer(_getSnapDuration(currentSnap), () {
        if (!_isPaused) {
          _advanceToNextSnap();
        }
      });
    }
  }

  /// Rewrite Firebase Storage URL for cross-platform compatibility
  /// iOS simulator needs localhost, Android emulator needs 10.0.2.2
  String _rewriteStorageUrl(String originalUrl) {
    // Validate input URL
    if (originalUrl.isEmpty) {
      debugPrint('[StoryViewer] ⚠️ Empty URL provided for rewriting');
      return originalUrl;
    }
    
    // Check if this is a Firebase Storage emulator URL that needs rewriting
    bool isEmulatorUrl = originalUrl.contains(':9199') && 
                        (originalUrl.contains('10.0.2.2') || originalUrl.contains('localhost'));
    
    if (!isEmulatorUrl) {
      debugPrint('[StoryViewer] 📝 No URL rewriting needed for: $originalUrl');
      return originalUrl;
    }
    
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      // iOS: Convert 10.0.2.2 URLs to localhost for iOS simulator connectivity
      if (originalUrl.contains('10.0.2.2:9199')) {
        final rewrittenUrl = originalUrl.replaceAll('10.0.2.2:9199', 'localhost:9199');
        debugPrint('[StoryViewer] 🔄 URL rewritten for iOS: $originalUrl -> $rewrittenUrl');
        return rewrittenUrl;
      }
    } else {
      // Android: Convert localhost URLs to 10.0.2.2 for Android emulator connectivity  
      if (originalUrl.contains('localhost:9199')) {
        final rewrittenUrl = originalUrl.replaceAll('localhost:9199', '10.0.2.2:9199');
        debugPrint('[StoryViewer] 🔄 URL rewritten for Android: $originalUrl -> $rewrittenUrl');
        return rewrittenUrl;
      }
    }
    
    // No rewriting needed or already in correct format
    debugPrint('[StoryViewer] 📝 URL already in correct format: $originalUrl');
    return originalUrl;
  }

  /// Initialize video player for video snaps
  Future<void> _initializeVideo(String videoUrl) async {
    try {
      // Dispose existing controller
      _videoController?.dispose();
      _videoController = null;
      _isVideoInitialized = false;
      
      // Apply URL rewriting for cross-platform compatibility
      final rewrittenUrl = _rewriteStorageUrl(videoUrl);
      debugPrint('[StoryViewer] 🎥 Original video URL: $videoUrl');
      debugPrint('[StoryViewer] 🎥 Rewritten video URL: $rewrittenUrl');
      
      // Parse URL and validate
      final uri = Uri.tryParse(rewrittenUrl);
      if (uri == null) {
        debugPrint('[StoryViewer] ❌ Invalid video URL format: $rewrittenUrl');
        return;
      }
      
      // Create video controller
      _videoController = VideoPlayerController.networkUrl(uri);
      
      // Initialize with timeout
      await _videoController!.initialize().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint('[StoryViewer] ⏱️ Video initialization timeout for URL: $rewrittenUrl');
          throw Exception('Video initialization timeout');
        },
      );
      
      if (mounted && _videoController != null) {
        setState(() {
          _isVideoInitialized = true;
        });
        
        // Auto-play video and loop
        await _videoController!.setLooping(true);
        await _videoController!.play();
        
        debugPrint('[StoryViewer] ✅ Video initialized and playing successfully');
      }
    } catch (e) {
      debugPrint('[StoryViewer] ❌ Error initializing video: $e');
      if (mounted) {
        setState(() {
          _isVideoInitialized = false;
        });
      }
      
      // Clean up failed controller
      _videoController?.dispose();
      _videoController = null;
    }
  }

  /// Advance to next snap or story
  void _advanceToNextSnap() {
    final currentStory = widget.stories[_currentStoryIndex];
    
    if (_currentSnapIndex < currentStory.snaps.length - 1) {
      // Move to next snap in current story
      setState(() {
        _currentSnapIndex++;
      });
      _snapPageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      _startCurrentSnap();
    } else {
      // Move to next story
      _advanceToNextStory();
    }
  }

  /// Go back to previous snap or story
  void _goToPreviousSnap() {
    if (_currentSnapIndex > 0) {
      // Go to previous snap in current story
      _progressControllers[_currentSnapIndex].reset();
      setState(() {
        _currentSnapIndex--;
      });
      _snapPageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      _startCurrentSnap();
    } else {
      // Go to previous story
      _goToPreviousStory();
    }
  }

  /// Advance to next story
  void _advanceToNextStory() {
    if (_currentStoryIndex < widget.stories.length - 1) {
      // Reset current story progress
      for (final controller in _progressControllers) {
        controller.reset();
      }
      
      setState(() {
        _currentStoryIndex++;
        _currentSnapIndex = 0;
      });
      
      _storyPageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      
      // Re-initialize for new story
      _disposeProgressControllers();
      _initializeProgressAnimations();
      _startCurrentSnap();
    } else {
      // Exit viewer - we've reached the end
      Navigator.of(context).pop();
    }
  }

  /// Go to previous story
  void _goToPreviousStory() {
    if (_currentStoryIndex > 0) {
      // Reset current story progress
      for (final controller in _progressControllers) {
        controller.reset();
      }
      
      setState(() {
        _currentStoryIndex--;
        _currentSnapIndex = widget.stories[_currentStoryIndex].snaps.length - 1; // Start from last snap
      });
      
      _storyPageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      
      // Re-initialize for new story
      _disposeProgressControllers();
      _initializeProgressAnimations();
      _startCurrentSnap();
    } else {
      // Exit viewer - we're at the beginning
      Navigator.of(context).pop();
    }
  }

  /// Dispose progress controllers only
  void _disposeProgressControllers() {
    for (final controller in _progressControllers) {
      controller.dispose();
    }
  }

  /// Toggle pause/play
  void _togglePause() {
    setState(() {
      _isPaused = !_isPaused;
    });
    
    if (_isPaused) {
      _progressControllers[_currentSnapIndex].stop();
      _autoAdvanceTimer?.cancel();
      if (_videoController?.value.isInitialized == true) {
        _videoController!.pause();
      }
    } else {
      _progressControllers[_currentSnapIndex].forward();
      final currentStory = widget.stories[_currentStoryIndex];
      final currentSnap = currentStory.snaps[_currentSnapIndex];
      
      _autoAdvanceTimer?.cancel();
      _autoAdvanceTimer = Timer(_getSnapDuration(currentSnap), () {
        if (!_isPaused) {
          _advanceToNextSnap();
        }
      });
      
      if (_videoController?.value.isInitialized == true) {
        _videoController!.play();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: GestureDetector(
          onTapDown: (details) {
            final screenWidth = MediaQuery.of(context).size.width;
            if (details.globalPosition.dx < screenWidth / 3) {
              // Left third: go to previous
              _goToPreviousSnap();
            } else if (details.globalPosition.dx > screenWidth * 2 / 3) {
              // Right third: go to next
              _advanceToNextSnap();
            } else {
              // Middle: toggle pause
              _togglePause();
            }
          },
          child: PageView.builder(
            controller: _storyPageController,
            itemCount: widget.stories.length,
            onPageChanged: (index) {
              setState(() {
                _currentStoryIndex = index;
                _currentSnapIndex = 0;
              });
              _disposeProgressControllers();
              _initializeProgressAnimations();
              _startCurrentSnap();
            },
            itemBuilder: (context, storyIndex) {
              return _buildStoryPage(widget.stories[storyIndex]);
            },
          ),
        ),
      ),
    );
  }

  /// Build a single story page
  Widget _buildStoryPage(StoryItem story) {
    return Stack(
      children: [
        // Story content
        PageView.builder(
          controller: _snapPageController,
          itemCount: story.snaps.length,
          onPageChanged: (index) {
            setState(() {
              _currentSnapIndex = index;
            });
            _startCurrentSnap();
          },
          itemBuilder: (context, snapIndex) {
            return _buildSnapContent(story.snaps[snapIndex]);
          },
        ),
        
        // Progress indicators
        _buildProgressIndicators(story),
        
        // Header with vendor info
        _buildHeader(story),
        
        // Caption overlay
        _buildCaptionOverlay(story.snaps[_currentSnapIndex]),
        
        // Pause indicator
        if (_isPaused) _buildPauseIndicator(),
      ],
    );
  }

  /// Build snap content (image or video)
  Widget _buildSnapContent(snap_models.Snap snap) {
    if (snap.mediaType == snap_models.MediaType.video) {
      return _buildVideoContent(snap);
    } else {
      return _buildImageContent(snap);
    }
  }

  /// Build video content with filter overlay
  Widget _buildVideoContent(snap_models.Snap snap) {
    if (!_isVideoInitialized || _videoController == null) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(color: AppColors.marketBlue),
        ),
      );
    }

    // Apply filter overlay for videos
    Color overlayColor = Colors.transparent;
    final filterType = snap.filterType;
    
    if (filterType != null && filterType != 'none') {
      if (filterType == 'warm') {
        overlayColor = Colors.orange.withAlpha(77);
      } else if (filterType == 'cool') {
        overlayColor = Colors.blue.withAlpha(77);
      } else if (filterType == 'contrast') {
        overlayColor = Colors.black.withAlpha(77);
      }
    }

    return Center(
      child: AspectRatio(
        aspectRatio: _videoController!.value.aspectRatio,
        child: Stack(
          children: [
            VideoPlayer(_videoController!),
            Positioned.fill(child: Container(color: overlayColor)),
          ],
        ),
      ),
    );
  }

  /// Build image content with filter overlay
  Widget _buildImageContent(snap_models.Snap snap) {
    // Apply filter overlay for images
    Color overlayColor = Colors.transparent;
    final filterType = snap.filterType;
    
    if (filterType != null && filterType != 'none') {
      if (filterType == 'warm') {
        overlayColor = Colors.orange.withAlpha(77);
      } else if (filterType == 'cool') {
        overlayColor = Colors.blue.withAlpha(77);
      } else if (filterType == 'contrast') {
        overlayColor = Colors.black.withAlpha(77);
      }
    }

    final rewrittenUrl = _rewriteStorageUrl(snap.mediaUrl); // Apply URL rewriting
    debugPrint('[StoryViewer] 🖼️ Image URL for display: $rewrittenUrl');

    return Center(
      child: Stack(
        children: [
          Image.network(
            rewrittenUrl,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(
                color: Colors.black,
                child: const Center(
                  child: CircularProgressIndicator(color: AppColors.marketBlue),
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: Colors.black,
                child: const Center(
                  child: Icon(Icons.error, color: Colors.white, size: 48),
                ),
              );
            },
          ),
          Positioned.fill(child: Container(color: overlayColor)),
        ],
      ),
    );
  }

  /// Build progress indicators at the top
  Widget _buildProgressIndicators(StoryItem story) {
    return Positioned(
      top: 8,
      left: 8,
      right: 8,
      child: Row(
        children: List.generate(story.snaps.length, (index) {
          return Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 1),
              height: 3,
              child: index == _currentSnapIndex 
                ? AnimatedBuilder(
                    animation: _progressAnimations[index],
                    builder: (context, child) {
                      return LinearProgressIndicator(
                        value: _progressAnimations[index].value,
                        backgroundColor: Colors.white.withAlpha(77),
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                      );
                    },
                  )
                : LinearProgressIndicator(
                    value: index < _currentSnapIndex ? 1.0 : 0.0,
                    backgroundColor: Colors.white.withAlpha(77),
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
            ),
          );
        }),
      ),
    );
  }

  /// Build header with vendor info and close button
  Widget _buildHeader(StoryItem story) {
    return Positioned(
      top: 20,
      left: 8,
      right: 8,
      child: Row(
        children: [
          // Vendor avatar
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.marketBlue,
            backgroundImage: story.vendorAvatarUrl.isNotEmpty
                ? NetworkImage(story.vendorAvatarUrl)
                : null,
            child: story.vendorAvatarUrl.isEmpty
                ? Text(
                    story.vendorName.isNotEmpty
                        ? story.vendorName[0].toUpperCase()
                        : 'V',
                    style: AppTypography.caption.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 8),
          
          // Vendor name and time
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  story.vendorName,
                  style: AppTypography.bodyLG.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  _getTimeAgo(story.snaps[_currentSnapIndex].createdAt),
                  style: AppTypography.caption.copyWith(
                    color: Colors.white.withAlpha(179),
                  ),
                ),
              ],
            ),
          ),
          
          // Close button
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: Colors.white),
          ),
        ],
      ),
    );
  }

  /// Build caption overlay at bottom
  Widget _buildCaptionOverlay(snap_models.Snap snap) {
    if (snap.caption == null || snap.caption!.isEmpty) return const SizedBox.shrink();
    
    return Positioned(
      bottom: 80,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(128),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          snap.caption!,
          style: AppTypography.body.copyWith(color: Colors.white),
        ),
      ),
    );
  }

  /// Build pause indicator
  Widget _buildPauseIndicator() {
    return const Center(
      child: Icon(
        Icons.pause,
        color: Colors.white,
        size: 64,
      ),
    );
  }

  /// Get time ago string
  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h';
    } else {
      return '${difference.inDays}d';
    }
  }
}