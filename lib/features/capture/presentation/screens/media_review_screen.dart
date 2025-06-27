import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import '../../application/lut_filter_service.dart';
import '../../../../core/models/pending_media.dart';
import '../../../../core/services/hive_service.dart';
import '../../../../core/services/ai_caption_service.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../../core/services/background_sync_service.dart';
import '../../../../features/profile/application/profile_service.dart';

/// Review screen for captured media with filter application and post functionality
/// Allows users to apply LUT filters and post their captured content
class MediaReviewScreen extends StatefulWidget {
  final String mediaPath;
  final MediaType mediaType;
  final String? caption;
  final HiveService hiveService;

  const MediaReviewScreen({
    super.key,
    required this.mediaPath,
    required this.mediaType,
    required this.hiveService,
    this.caption,
  });

  @override
  State<MediaReviewScreen> createState() => _MediaReviewScreenState();
}

class _MediaReviewScreenState extends State<MediaReviewScreen>
    with TickerProviderStateMixin {
  final LutFilterService _lutFilterService = LutFilterService.instance;
  final TextEditingController _captionController = TextEditingController();
  late final BackgroundSyncService backgroundSyncService;
  final AICaptionService _aiCaptionService = AICaptionService();
  late final ProfileService _profileService;

  // Filter state
  LutFilterType _selectedFilter = LutFilterType.none;
  String? _filteredImagePath;
  bool _isApplyingFilter = false;
  bool _isPosting = false;

  // AI Caption state
  bool _isGeneratingCaption = false;
  bool _aiCaptionAvailable = false;
  String? _lastGeneratedCaption;

  // Video player (if media is video)
  late bool _isPhoto;
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;

  // Animation controllers
  late AnimationController _filterAnimationController;
  late Animation<double> _filterAnimation;
  late AnimationController _aiButtonAnimationController;

  // Posting state
  bool _hasConnectivity = true;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    // Initialize caption with provided text
    if (widget.caption != null) {
      _captionController.text = widget.caption!;
    }

    _isPhoto = widget.mediaType == MediaType.photo;
    if (!_isPhoto) {
      _initializeVideoPlayer();
    }

    // Initialize animation controllers
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

    _aiButtonAnimationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(); // Start the breathing animation immediately

    // Initialize services
    _initializeLutService();
    _initializeAIService();

    // Initialize background sync service
    backgroundSyncService = BackgroundSyncService();

    // Initialize profile service
    _profileService = ProfileService(hiveService: widget.hiveService);

    // Initialize connectivity monitoring
    _initializeConnectivity();
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _captionController.dispose();
    _filterAnimationController.dispose();
    _aiButtonAnimationController.dispose();
    _lutFilterService.clearPreviewCache();
    _connectivitySubscription?.cancel();
    _aiCaptionService.dispose();
    super.dispose();
  }

  /// Initialize LUT filter service
  Future<void> _initializeLutService() async {
    try {
      await _lutFilterService.initialize();
    } catch (e) {
      // Handle error
    }
  }

  /// Initialize AI Caption service
  Future<void> _initializeAIService() async {
    try {
      await _aiCaptionService.initialize();
      if (mounted) {
        setState(() {
          _aiCaptionAvailable = true;
        });
        _aiButtonAnimationController.forward();
      }
    } catch (e) {
      debugPrint('[MediaReviewScreen] Failed to initialize AI service: $e');
    }
  }

  /// Initialize video player for video media
  Future<void> _initializeVideoPlayer() async {
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
    } catch (e) {
      // Handle error
    }
  }

  /// Apply selected filter to the image
  Future<void> _applyFilter(LutFilterType filterType) async {
    // For videos, just update the state to show the color overlay
    if (widget.mediaType == MediaType.video) {
      setState(() {
        _selectedFilter = filterType;
      });
      return;
    }

    // For photos, process the image file
    if (_isApplyingFilter) return;

    setState(() {
      _isApplyingFilter = true;
      _selectedFilter = filterType;
    });

    try {
      final newPath = await _lutFilterService.applyFilterToImage(
        inputImagePath: widget.mediaPath,
        filterType: filterType,
      );

      if (newPath != null) {
        // Clean up the previously filtered image if it exists
        if (_filteredImagePath != null &&
            _filteredImagePath != widget.mediaPath) {
          final oldFile = File(_filteredImagePath!);
          if (await oldFile.exists()) {
            await oldFile.delete();
          }
        }
        setState(() {
          _filteredImagePath = newPath;
        });
      }
    } catch (e) {
      // Handle error
    } finally {
      if (mounted) {
        setState(() {
          _isApplyingFilter = false;
        });
      }
    }
  }

  /// Generate AI caption with 2-second timeout
  Future<void> _generateAICaption() async {
    if (_isGeneratingCaption || !_aiCaptionAvailable) return;

    setState(() {
      _isGeneratingCaption = true;
    });

    try {
      // Get vendor profile for context
      Map<String, dynamic>? vendorProfile;
      try {
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          final profile = _profileService.getCurrentUserProfile();
          vendorProfile = {
            'stallName': profile?.stallName,
            'marketCity': profile?.marketCity,
          };
        }
      } catch (e) {
        debugPrint('[MediaReviewScreen] Error getting vendor profile: $e');
      }

      // Generate caption
      final response = await _aiCaptionService.generateCaption(
        mediaPath: widget.mediaPath,
        mediaType: widget.mediaType.name,
        existingCaption: _captionController.text.isNotEmpty ? _captionController.text : null,
        vendorProfile: vendorProfile,
      );

      if (mounted) {
        setState(() {
          _lastGeneratedCaption = response.caption;
          _captionController.text = response.caption;
        });

        // Show feedback about the caption
        if (response.fromCache) {
          _showCaptionFeedback('🧺 Wicker remembers: ${response.caption.length > 30 ? '${response.caption.substring(0, 30)}...' : response.caption}');
        } else {
          _showCaptionFeedback('🧺 Wicker says: ${response.caption.length > 30 ? '${response.caption.substring(0, 30)}...' : response.caption}');
        }
      }
    } catch (e) {
      debugPrint('[MediaReviewScreen] Error generating AI caption: $e');
      if (mounted) {
        _showCaptionFeedback('🧺 Wicker is taking a break, try again later');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingCaption = false;
        });
      }
    }
  }

  /// Show caption feedback message
  void _showCaptionFeedback(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.orange.shade600,
      ),
    );
  }

  /// Post the media with applied filters and caption
  Future<void> _postMedia() async {
    if (_isPosting) return;

    setState(() {
      _isPosting = true;
    });

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception("User not authenticated");
      }

      final mediaPath = _filteredImagePath ?? widget.mediaPath;
      final caption = _captionController.text;
      final mediaType = widget.mediaType;

      final pendingItem = PendingMediaItem(
        filePath: mediaPath,
        caption: caption,
        mediaType: mediaType,
        vendorId: currentUser.uid,
        filterType: _selectedFilter.name,
      );

      debugPrint('[MediaReviewScreen] Creating PendingMediaItem with filterType: "${_selectedFilter.name}" (from ${_selectedFilter.displayName})');

      await widget.hiveService.addPendingMedia(pendingItem);

      // Show different behavior based on connectivity
      if (_hasConnectivity) {
        // Online: Try immediate sync with timeout
        debugPrint('[MediaReviewScreen] Online - attempting immediate sync with timeout');
        
        try {
          // Set a reasonable timeout for online posting
          await backgroundSyncService.triggerImmediateSync().timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              debugPrint('[MediaReviewScreen] Immediate sync timed out - will continue in background');
              throw TimeoutException('Upload timed out', const Duration(seconds: 10));
            },
          );
          
          // Success - immediate upload completed
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('✅ Posted successfully!'),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.of(context).popUntil((route) => route.isFirst);
          }
        } on TimeoutException {
          // Timeout - let it continue in background
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('📤 Posting in background...'),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 3),
              ),
            );
            Navigator.of(context).popUntil((route) => route.isFirst);
          }
        }
      } else {
        // Offline: Add to queue and show offline message with queue count
        debugPrint('[MediaReviewScreen] Offline - added to queue for later upload');
        
        if (mounted) {
          // Get current queue count for better user feedback
          _showOfflineQueueMessage();
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to post: $e'),
            backgroundColor: Colors.red,
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

  /// Build video preview with filter overlay
  Widget _buildVideoPreview() {
    if (!_isVideoInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    // Define overlay colors for video filters
    Color overlayColor = Colors.transparent;
    switch (_selectedFilter) {
      case LutFilterType.warm:
        overlayColor = Colors.orange.withValues(alpha: 0.3);
        break;
      case LutFilterType.cool:
        overlayColor = Colors.blue.withValues(alpha: 0.3);
        break;
      case LutFilterType.contrast:
        overlayColor = Colors.black.withValues(alpha: 0.3);
        break;
      case LutFilterType.none:
        overlayColor = Colors.transparent;
        break;
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        // Video player
        AspectRatio(
          aspectRatio: _videoController!.value.aspectRatio,
          child: VideoPlayer(_videoController!),
        ),
        // Animated filter overlay
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            color: overlayColor,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ],
    );
  }

  /// Build filter selection row with optimized rendering
  Widget _buildFilterSelection() {
    // Show filters for both images and videos
    // Note: For videos, filters are applied as preview overlays only
    // The actual video file remains unmodified

    return Container(
      height: 100,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: LutFilterType.values.length,
        // ✅ BUFFER OVERFLOW FIX: Optimized caching and rendering
        cacheExtent: 200, // Reduced cache extent to save memory
        addAutomaticKeepAlives:
            false, // Don't keep items alive when scrolled away
        addRepaintBoundaries: true, // Optimize repainting
        itemBuilder: (context, index) {
          final filterType = LutFilterType.values[index];
          final isSelected = _selectedFilter == filterType;

          // ✅ OPTIMIZATION: Use AutomaticKeepAlive for selected item only
          return _FilterThumbnailWidget(
            key: ValueKey('filter_${filterType.name}'),
            filterType: filterType,
            isSelected: isSelected,
            mediaPath: widget.mediaPath,
            onTap: () => _applyFilter(filterType),
            lutFilterService: _lutFilterService,
          );
        },
      ),
    );
  }

  /// Build caption input section with AI helper
  Widget _buildCaptionInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
                        children: [
              const Text(
                'Add a caption',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
              ),
              const Spacer(),
              // Placeholder to maintain layout spacing
              if (_aiCaptionAvailable)
                const SizedBox(width: 48, height: 24),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _captionController,
            maxLines: 2,
            maxLength: 200,
            decoration: InputDecoration(
              hintText: _isGeneratingCaption
                  ? 'Wicker is crafting your caption...'
                  : 'What\'s the story behind this ${widget.mediaType.name}?',
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
              suffixIcon: _lastGeneratedCaption != null &&
                      _captionController.text != _lastGeneratedCaption
                  ? IconButton(
                      onPressed: () {
                        setState(() {
                          _captionController.text = _lastGeneratedCaption!;
                        });
                        _showCaptionFeedback('✨ Restored Wicker\'s caption');
                      },
                      icon: Icon(
                        Icons.restore,
                        color: Colors.deepPurple.shade400,
                        size: 20,
                      ),
                      tooltip: 'Restore Wicker\'s caption',
                    )
                  : null,
            ),
          ),
          if (_lastGeneratedCaption != null && _lastGeneratedCaption!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '🧺 Wicker\'s suggestion available • Caption is editable',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.orange.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Build post button with connectivity awareness
  Widget _buildPostButton() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          // Connectivity status indicator
          if (!_hasConnectivity)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade300),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.wifi_off, size: 16, color: Colors.orange.shade700),
                  const SizedBox(width: 6),
                  Text(
                    'Offline - will post when connected',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          
          // Post button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isPosting ? null : _postMedia,
              style: ElevatedButton.styleFrom(
                backgroundColor: _hasConnectivity 
                  ? Colors.deepPurple 
                  : Colors.blue.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
              ),
              child: _isPosting
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _hasConnectivity ? 'Posting...' : 'Adding to queue...',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _hasConnectivity ? Icons.send : Icons.schedule_send,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _hasConnectivity ? 'Post' : 'Queue for Later',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  /// Show offline queue message with current queue count
  Future<void> _showOfflineQueueMessage() async {
    try {
      // Get current queue count
      final pendingBox = await Hive.openBox<PendingMediaItem>('pendingMediaQueue');
      final queueCount = pendingBox.length;
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.wifi_off, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  queueCount == 1 
                    ? '📱 1 post queued for upload'
                    : '📱 $queueCount posts queued for upload',
                ),
              ),
            ],
          ),
          backgroundColor: Colors.blue.shade600,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      debugPrint('[MediaReviewScreen] Error getting queue count: $e');
      // Fallback to simple message
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.wifi_off, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Expanded(child: Text('📱 Will post when online')),
            ],
          ),
          backgroundColor: Colors.blue.shade600,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  /// Initialize connectivity monitoring
  void _initializeConnectivity() async {
    // Check initial connectivity
    final connectivityResult = await Connectivity().checkConnectivity();
    _updateConnectivityStatus(connectivityResult);

    // Listen for connectivity changes
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      _updateConnectivityStatus,
    );
  }

  /// Update connectivity status
  void _updateConnectivityStatus(List<ConnectivityResult> result) {
    final bool hasConnection = result.any((connectivity) => 
      connectivity != ConnectivityResult.none
    );
    
    if (mounted && _hasConnectivity != hasConnection) {
      setState(() {
        _hasConnectivity = hasConnection;
      });
      
      // Log connectivity change for debugging
      debugPrint('[MediaReviewScreen] Connectivity changed: ${hasConnection ? 'ONLINE' : 'OFFLINE'}');
    }
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

    return Stack(
      children: [
        // Main app content
        Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              onPressed: () {
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
                        // Filter selection (now enabled for videos too)
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
        ),
        
        // Wicker overlay - positioned in the foreground
        if (_aiCaptionAvailable)
          Positioned(
            right: 8,
            bottom: MediaQuery.of(context).size.height * 0.32, // Position near the caption area
            child: AnimatedBuilder(
              animation: _aiButtonAnimationController,
              builder: (context, child) {
                // Friendly breathing animation when idle
                final breathingScale = _isGeneratingCaption 
                    ? 1.0 
                    : 1.0 + (sin(_aiButtonAnimationController.value * 2 * pi) * 0.08);
                
                // Gentle shake when generating
                final shakeOffset = _isGeneratingCaption
                    ? sin(_aiButtonAnimationController.value * 8 * pi) * 3.0
                    : 0.0;
                
                return Transform.translate(
                  offset: Offset(shakeOffset, 0),
                  child: Transform.scale(
                    scale: breathingScale,
                    child: GestureDetector(
                      onTap: _isGeneratingCaption ? null : _generateAICaption,
                      child: Tooltip(
                        message: _isGeneratingCaption
                            ? 'Wicker is crafting your caption...'
                            : 'Ask Wicker for a caption suggestion',
                        child: SizedBox(
                          width: 72,
                          height: 72,
                          child: Image.asset(
                            'assets/images/icons/wicker_mascot.png',
                            width: 72,
                            height: 72,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

/// Extension to capitalize strings
extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}

/// ✅ BUFFER OVERFLOW FIX: Optimized filter thumbnail widget with proper lifecycle management
class _FilterThumbnailWidget extends StatefulWidget {
  final LutFilterType filterType;
  final bool isSelected;
  final String mediaPath;
  final VoidCallback onTap;
  final LutFilterService lutFilterService;

  const _FilterThumbnailWidget({
    super.key,
    required this.filterType,
    required this.isSelected,
    required this.mediaPath,
    required this.onTap,
    required this.lutFilterService,
  });

  @override
  State<_FilterThumbnailWidget> createState() => _FilterThumbnailWidgetState();
}

class _FilterThumbnailWidgetState extends State<_FilterThumbnailWidget>
    with AutomaticKeepAliveClientMixin {
  // ✅ BUFFER OVERFLOW FIX: Cache preview data to prevent regeneration
  Uint8List? _cachedPreviewData;
  bool _isLoading = false;
  bool _hasError = false;

  @override
  bool get wantKeepAlive => widget.isSelected; // Only keep selected item alive

  @override
  void initState() {
    super.initState();
    _loadPreview();
  }

  @override
  void didUpdateWidget(_FilterThumbnailWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only reload if filter type changed
    if (oldWidget.filterType != widget.filterType) {
      _loadPreview();
    }
  }

  /// Load preview with error handling and caching
  Future<void> _loadPreview() async {
    if (widget.filterType == LutFilterType.none || _cachedPreviewData != null) {
      return; // No need to load for 'none' filter or if already cached
    }

    if (_isLoading) return; // Prevent multiple simultaneous loads

    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final previewData = await widget.lutFilterService.getFilterPreview(
        inputImagePath: widget.mediaPath,
        filterType: widget.filterType,
        previewSize: 48,
      );

      if (mounted) {
        setState(() {
          _cachedPreviewData = previewData;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: 70,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          children: [
            // Filter preview thumbnail
            Container(
              width: 48, // Reduced size for memory optimization
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: widget.isSelected
                      ? Colors.deepPurple
                      : Colors.grey.shade300,
                  width: widget.isSelected ? 3 : 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: _buildThumbnailContent(),
              ),
            ),

            const SizedBox(height: 8),

            // Filter name
            Text(
              widget.filterType.displayName,
              style: TextStyle(
                fontSize: 11, // Slightly smaller text
                fontWeight: widget.isSelected
                    ? FontWeight.bold
                    : FontWeight.normal,
                color: widget.isSelected
                    ? Colors.deepPurple
                    : Colors.grey.shade700,
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

  Widget _buildThumbnailContent() {
    if (widget.filterType == LutFilterType.none) {
      // Show original image thumbnail
      return Image.file(
        File(widget.mediaPath),
        fit: BoxFit.cover,
        cacheWidth: 48,
        cacheHeight: 48,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey.shade200,
            child: const Icon(Icons.image_not_supported, size: 20),
          );
        },
      );
    }

    if (_isLoading) {
      return Container(
        color: _getFilterColor().withValues(alpha: 0.2),
        child: Icon(Icons.filter, color: _getFilterColor(), size: 16),
      );
    }

    if (_hasError || _cachedPreviewData == null) {
      return Container(
        color: _getFilterColor().withValues(alpha: 0.3),
        child: Center(
          child: Text(
            widget.filterType.name[0].toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }

    return Image.memory(
      _cachedPreviewData!,
      fit: BoxFit.cover,
      cacheWidth: 48,
      cacheHeight: 48,
      gaplessPlayback: false,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: _getFilterColor().withValues(alpha: 0.3),
          child: Center(
            child: Text(
              widget.filterType.name[0].toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      },
    );
  }

  Color _getFilterColor() {
    switch (widget.filterType) {
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
}
