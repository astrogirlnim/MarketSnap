import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import '../../application/camera_service.dart';
import 'media_review_screen.dart';
import '../../../../core/models/pending_media.dart';
import '../../../../core/services/hive_service.dart';

/// Custom painter for drawing viewfinder grid overlay
class ViewfinderGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    // Draw rule of thirds grid
    final double thirdWidth = size.width / 3;
    final double thirdHeight = size.height / 3;

    // Vertical lines
    canvas.drawLine(
      Offset(thirdWidth, 0),
      Offset(thirdWidth, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(thirdWidth * 2, 0),
      Offset(thirdWidth * 2, size.height),
      paint,
    );

    // Horizontal lines
    canvas.drawLine(
      Offset(0, thirdHeight),
      Offset(size.width, thirdHeight),
      paint,
    );
    canvas.drawLine(
      Offset(0, thirdHeight * 2),
      Offset(size.width, thirdHeight * 2),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Camera preview screen with photo capture functionality
/// Provides a full-screen camera interface with controls for taking photos
class CameraPreviewScreen extends StatefulWidget {
  final HiveService hiveService;

  const CameraPreviewScreen({super.key, required this.hiveService});

  @override
  State<CameraPreviewScreen> createState() => _CameraPreviewScreenState();
}

class _CameraPreviewScreenState extends State<CameraPreviewScreen>
    with WidgetsBindingObserver {
  final CameraService _cameraService = CameraService.instance;

  bool _isInitializing = true;
  bool _isTakingPhoto = false;
  String? _errorMessage;
  FlashMode _currentFlashMode = FlashMode.off;

  // Video recording state
  bool _isRecordingVideo = false;
  int _recordingCountdown = 0;
  StreamSubscription<int>? _countdownSubscription;

  // ✅ BUFFER OVERFLOW FIX: Track widget visibility for camera lifecycle management
  bool _isWidgetVisible = false;

  @override
  void initState() {
    super.initState();
    debugPrint('[CameraPreviewScreen] ========== INIT STATE START ==========');

    // Add lifecycle observer for app state changes
    WidgetsBinding.instance.addObserver(this);

    // ✅ CAMERA UNAVAILABLE FIX: Initialize widget visibility state
    _isWidgetVisible = true;

    debugPrint(
      '[CameraPreviewScreen] Lifecycle observer added, widget marked as visible',
    );

    // ✅ CAMERA UNAVAILABLE FIX: Initialize camera with post-frame callback to ensure widget is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPrint(
        '[CameraPreviewScreen] Post-frame callback: initializing camera...',
      );
      if (mounted) {
        _initializeCamera();
      } else {
        debugPrint(
          '[CameraPreviewScreen] Widget not mounted in post-frame callback',
        );
      }
    });

    // ✅ CAMERA UNAVAILABLE FIX: Add periodic check to update UI state if camera becomes available
    Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      // If we're showing loading but camera is actually ready, update UI
      if (_isInitializing &&
          _cameraService.controller?.value.isInitialized == true &&
          _errorMessage == null) {
        debugPrint(
          '[CameraPreviewScreen] Periodic check: Camera ready, updating UI state',
        );
        setState(() {
          _isInitializing = false;
        });
        timer.cancel();
      }
    });

    debugPrint('[CameraPreviewScreen] ========== INIT STATE END ==========');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    debugPrint(
      '[CameraPreviewScreen] ========== DEPENDENCIES CHANGED ==========',
    );

    // ✅ CAMERA UNAVAILABLE FIX: Reinitialize camera when dependencies change (like tab switching)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _isWidgetVisible) {
        debugPrint(
          '[CameraPreviewScreen] Dependencies changed, reinitializing camera...',
        );
        _initializeCameraWithDelay();
      }
    });
  }

  @override
  void dispose() {
    // ✅ BUFFER OVERFLOW FIX: Mark widget as not visible
    _isWidgetVisible = false;

    // ✅ BUFFER OVERFLOW FIX: Enhanced disposal with proper cleanup order
    WidgetsBinding.instance.removeObserver(this);

    // Cancel countdown subscription first
    _countdownSubscription?.cancel();
    _countdownSubscription = null;

    // ✅ BUFFER OVERFLOW FIX: Ensure camera is properly disposed when widget is destroyed
    // This is critical for preventing buffer overflow when navigating away from camera
    _cameraService.disposeController().catchError((error) {
      debugPrint('[CameraPreviewScreen] Error during camera disposal: $error');
    });

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.inactive:
        // App is becoming inactive (e.g., phone call, notification)
        _cameraService.pauseCamera();
        break;

      case AppLifecycleState.paused:
        // App is going to background
        _cameraService.handleAppInBackground();
        break;

      case AppLifecycleState.resumed:
        // App is resuming from background
        _handleAppResumed();
        break;

      case AppLifecycleState.detached:
        // App is being detached
        _cameraService.disposeController();
        break;

      case AppLifecycleState.hidden:
        // App is hidden (iOS specific)
        _cameraService.pauseCamera();
        break;
    }
  }

  /// ✅ CAMERA UNAVAILABLE FIX: Enhanced app resumed handling with better error recovery
  Future<void> _handleAppResumed() async {
    debugPrint(
      '[CameraPreviewScreen] ========== APP RESUMED HANDLING ==========',
    );

    try {
      final success = await _cameraService.handleAppInForeground();

      debugPrint(
        '[CameraPreviewScreen] Camera service resume result: $success',
      );

      if (!success && mounted) {
        debugPrint(
          '[CameraPreviewScreen] Camera resume failed, attempting full reinitialization...',
        );
        await _initializeCamera();
      }
    } catch (e) {
      debugPrint('[CameraPreviewScreen] Error during app resume: $e');
      if (mounted) {
        debugPrint(
          '[CameraPreviewScreen] Fallback to full reinitialization after error',
        );
        await _initializeCamera();
      }
    }

    debugPrint(
      '[CameraPreviewScreen] ========== APP RESUMED HANDLING COMPLETE ==========',
    );
  }

  /// ✅ CAMERA UNAVAILABLE FIX: Enhanced initialization with comprehensive retry logic and better error handling
  Future<void> _initializeCamera() async {
    debugPrint(
      '[CameraPreviewScreen] ========== CAMERA INITIALIZATION START ==========',
    );
    debugPrint(
      '[CameraPreviewScreen] Widget state - visible: $_isWidgetVisible, mounted: $mounted',
    );

    // ✅ CAMERA UNAVAILABLE FIX: Only initialize if widget is ready and mounted
    if (!_isWidgetVisible || !mounted) {
      debugPrint(
        '[CameraPreviewScreen] Skipping initialization - widget not ready',
      );
      return;
    }

    // ✅ CAMERA UNAVAILABLE FIX: Check if already initialized and working
    if (_cameraService.controller?.value.isInitialized == true &&
        !_isInitializing) {
      debugPrint(
        '[CameraPreviewScreen] Camera already initialized and working, skipping initialization',
      );
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _errorMessage = null;
        });
      }
      return;
    }

    // ✅ CAMERA UNAVAILABLE FIX: Prevent concurrent initialization attempts with timeout protection
    if (_isInitializing) {
      debugPrint(
        '[CameraPreviewScreen] Already initializing, waiting for completion...',
      );
      // Wait for current initialization to complete with timeout
      int waitAttempts = 0;
      const int maxWaitAttempts = 50; // 5 seconds max wait
      while (_isInitializing && waitAttempts < maxWaitAttempts && mounted) {
        await Future.delayed(const Duration(milliseconds: 100));
        waitAttempts++;
      }

      // Check if initialization completed successfully
      if (_cameraService.controller?.value.isInitialized == true) {
        debugPrint(
          '[CameraPreviewScreen] Initialization completed while waiting',
        );
        return;
      }

      // If still initializing after timeout, force reset
      if (_isInitializing) {
        debugPrint(
          '[CameraPreviewScreen] Initialization timeout, forcing reset...',
        );
        if (mounted) {
          setState(() {
            _isInitializing = false;
          });
        }
      }
    }

    // ✅ CAMERA UNAVAILABLE FIX: Check if camera service is stuck and force reset if needed
    if (_cameraService.isInitializingStuck) {
      debugPrint(
        '[CameraPreviewScreen] Camera service stuck initializing, forcing reset...',
      );
      _cameraService.forceResetInitialization();
    }

    if (mounted) {
      setState(() {
        _isInitializing = true;
        _errorMessage = null;
      });
    }

    try {
      // ✅ CAMERA UNAVAILABLE FIX: Enhanced service initialization check
      if (!_cameraService.isInitialized) {
        debugPrint(
          '[CameraPreviewScreen] Camera service not initialized, initializing...',
        );
        final serviceInitialized = await _cameraService.initialize();
        if (!serviceInitialized) {
          final error =
              _cameraService.lastError ?? 'Failed to initialize camera service';
          debugPrint(
            '[CameraPreviewScreen] ERROR: Service initialization failed - $error',
          );
          throw Exception(error);
        }
        debugPrint(
          '[CameraPreviewScreen] ✅ Camera service initialized successfully',
        );
      }

      // ✅ CAMERA UNAVAILABLE FIX: Use enhanced initialization with retry logic
      debugPrint(
        '[CameraPreviewScreen] Initializing camera controller with retry logic...',
      );
      final controllerInitialized = await _cameraService
          .initializeCameraWithRetry();

      if (!controllerInitialized) {
        final error =
            _cameraService.lastError ??
            'Failed to initialize camera controller after retries';
        debugPrint(
          '[CameraPreviewScreen] ERROR: Controller initialization failed - $error',
        );
        throw Exception(error);
      }

      debugPrint(
        '[CameraPreviewScreen] ✅ Camera controller initialized successfully',
      );

      // Set initial flash mode
      _currentFlashMode = _cameraService.getCurrentFlashMode();
      debugPrint('[CameraPreviewScreen] Flash mode set to: $_currentFlashMode');

      if (mounted) {
        setState(() {
          _isInitializing = false;
          _errorMessage = null;
        });
        debugPrint('[CameraPreviewScreen] ✅ UI state updated - camera ready');
      }
    } catch (e) {
      debugPrint('[CameraPreviewScreen] ❌ Camera initialization failed: $e');

      if (mounted) {
        setState(() {
          _isInitializing = false;
          _errorMessage = e.toString();
        });
        debugPrint('[CameraPreviewScreen] UI state updated with error message');
      }
    }

    debugPrint(
      '[CameraPreviewScreen] ========== CAMERA INITIALIZATION END ==========',
    );
  }

  /// ✅ CAMERA UNAVAILABLE FIX: Enhanced initialization method with delayed retry for tab switching
  Future<void> _initializeCameraWithDelay() async {
    debugPrint(
      '[CameraPreviewScreen] Delayed camera initialization starting...',
    );

    // Small delay to allow tab switching to complete
    await Future.delayed(const Duration(milliseconds: 200));

    if (!mounted) {
      debugPrint(
        '[CameraPreviewScreen] Widget no longer mounted, skipping delayed initialization',
      );
      return;
    }

    await _initializeCamera();
  }

  /// Capture a photo using the camera service
  Future<void> _capturePhoto() async {
    if (_isTakingPhoto || _isRecordingVideo) {
      return;
    }

    setState(() {
      _isTakingPhoto = true;
    });

    try {
      // Provide haptic feedback
      await HapticFeedback.mediumImpact();

      final photoPath = await _cameraService.capturePhoto();

      if (photoPath != null) {
        // ✅ BUFFER OVERFLOW FIX: Pause camera before navigating to review screen
        await _cameraService.pauseCamera();

        // Navigate to review screen
        if (mounted) {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => MediaReviewScreen(
                mediaPath: photoPath,
                mediaType: MediaType.photo,
                hiveService: widget.hiveService,
              ),
            ),
          );
          // ✅ BUFFER OVERFLOW FIX: Resume camera when returning from review screen
          await _cameraService.resumeCamera();
        }
      } else {
        throw Exception(_cameraService.lastError ?? 'Failed to capture photo');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Failed to capture photo: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isTakingPhoto = false;
        });
      }
    }
  }

  /// Start video recording with 5-second countdown
  Future<void> _startVideoRecording() async {
    if (_isTakingPhoto || _isRecordingVideo) {
      return;
    }

    try {
      // Provide haptic feedback
      await HapticFeedback.mediumImpact();

      // Start video recording
      final success = await _cameraService.startVideoRecording();

      if (success) {
        // Log that recording has started, but wait for stop to get the path
        setState(() {
          _isRecordingVideo = true;
          _recordingCountdown = _cameraService.maxRecordingDuration;
        });

        // Listen to countdown updates
        _countdownSubscription = _cameraService.countdownStream?.listen(
          (remainingTime) {
            if (mounted) {
              setState(() {
                _recordingCountdown = remainingTime;
              });
            }

            // Auto-stop when countdown reaches 0 (handled by service, but we update UI)
            if (remainingTime <= 0) {
              _handleVideoRecordingComplete();
            }
          },
          onError: (error) {
            debugPrint('[CameraPreviewScreen] Countdown stream error: $error');
          },
          onDone: () {
            _handleVideoRecordingComplete();
          },
        );
      } else {
        throw Exception(
          _cameraService.lastError ?? 'Failed to start video recording',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Failed to start video recording: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      // Reset state on error
      setState(() {
        _isRecordingVideo = false;
        _recordingCountdown = 0;
      });
    }
  }

  /// Stop video recording manually (before 5 seconds)
  Future<void> _stopVideoRecording() async {
    if (!_isRecordingVideo) {
      return;
    }

    String? videoPath;

    try {
      // Stop video recording
      videoPath = await _cameraService.stopVideoRecording();

      if (videoPath != null) {
        // ✅ BUFFER OVERFLOW FIX: Pause camera before navigating
        await _cameraService.pauseCamera();

        // Navigation is now handled by _handleVideoRecordingComplete
      } else {
        throw Exception(_cameraService.lastError ?? 'Failed to save video');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Failed to save video: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }

    _handleVideoRecordingComplete(videoPath: videoPath);
  }

  /// Handle video recording completion (auto or manual stop)
  void _handleVideoRecordingComplete({String? videoPath}) {
    debugPrint('[CameraPreviewScreen] _handleVideoRecordingComplete called');
    debugPrint('[CameraPreviewScreen] Passed videoPath: $videoPath');
    debugPrint(
      '[CameraPreviewScreen] Service lastVideoPath: ${_cameraService.lastVideoPath}',
    );

    // Cancel countdown subscription
    _countdownSubscription?.cancel();
    _countdownSubscription = null;

    // Reset UI state
    if (mounted) {
      setState(() {
        _isRecordingVideo = false;
        _recordingCountdown = 0;
      });
    }

    // ✅ FIX: Navigate to review screen if a path is available.
    // This handles both manual stops (path passed directly) and automatic stops (path from service).
    final finalVideoPath = videoPath ?? _cameraService.lastVideoPath;

    debugPrint(
      '[CameraPreviewScreen] Final video path to use: $finalVideoPath',
    );

    if (finalVideoPath != null) {
      debugPrint(
        '[CameraPreviewScreen] Navigating to MediaReviewScreen with video: $finalVideoPath',
      );
      // Use a post-frame callback to avoid navigation during build
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return; // Early return if widget is not mounted

        // Capture context before async operations
        final navigator = Navigator.of(context);

        // ✅ BUFFER OVERFLOW FIX: Pause camera before navigating
        await _cameraService.pauseCamera();

        // Check mounted again after async operation
        if (!mounted) return;

        await navigator.push(
          MaterialPageRoute(
            builder: (context) => MediaReviewScreen(
              mediaPath: finalVideoPath,
              mediaType: MediaType.video,
              hiveService: widget.hiveService,
            ),
          ),
        );

        // ✅ BUFFER OVERFLOW FIX: Resume camera when returning from review screen
        await _cameraService.resumeCamera();
      });
    } else {
      debugPrint(
        '[CameraPreviewScreen] ERROR: No video path available for navigation',
      );
    }
  }

  /// Cancel video recording without saving
  Future<void> _cancelVideoRecording() async {
    if (!_isRecordingVideo) {
      return;
    }

    try {
      await _cameraService.cancelVideoRecording();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.cancel, color: Colors.white),
                SizedBox(width: 8),
                Text('Video recording cancelled'),
              ],
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint(
        '[CameraPreviewScreen] Video recording cancellation failed: $e',
      );
    }

    _handleVideoRecordingComplete();
  }

  /// Switch between front and back cameras
  Future<void> _switchCamera() async {
    try {
      final success = await _cameraService.switchCamera();
      if (success) {
        // Update flash mode after switching cameras
        setState(() {
          _currentFlashMode = _cameraService.getCurrentFlashMode();
        });
      } else {
        throw Exception(_cameraService.lastError ?? 'Failed to switch camera');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to switch camera: $e'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  /// Toggle flash mode
  Future<void> _toggleFlash() async {
    // Cycle through flash modes: off -> auto -> on -> off
    FlashMode nextMode;
    switch (_currentFlashMode) {
      case FlashMode.off:
        nextMode = FlashMode.auto;
        break;
      case FlashMode.auto:
        nextMode = FlashMode.always;
        break;
      case FlashMode.always:
        nextMode = FlashMode.off;
        break;
      default:
        nextMode = FlashMode.off;
    }

    final success = await _cameraService.setFlashMode(nextMode);
    if (success) {
      setState(() {
        _currentFlashMode = nextMode;
      });
    }
  }

  /// Get flash icon based on current flash mode
  IconData _getFlashIcon() {
    switch (_currentFlashMode) {
      case FlashMode.off:
        return Icons.flash_off;
      case FlashMode.auto:
        return Icons.flash_auto;
      case FlashMode.always:
        return Icons.flash_on;
      default:
        return Icons.flash_off;
    }
  }

  /// Build camera preview widget
  Widget _buildCameraPreview() {
    // Handle simulator mode with mock camera preview
    if (_cameraService.isSimulatorMode) {
      return _buildSimulatorPreview();
    }

    // Handle real camera
    if (_cameraService.controller == null ||
        !_cameraService.controller!.value.isInitialized) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: Text(
            'Camera not available',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
        ),
      );
    }

    final controller = _cameraService.controller!;
    final size = MediaQuery.of(context).size;
    final deviceRatio = size.width / size.height;
    final cameraRatio = controller.value.aspectRatio;

    // Enhanced debugging info for camera display
    debugPrint(
      '[CameraPreviewScreen] ========== CAMERA DISPLAY DEBUG ==========',
    );
    debugPrint('[CameraPreviewScreen] Device ratio: $deviceRatio');
    debugPrint('[CameraPreviewScreen] Camera ratio: $cameraRatio');
    debugPrint(
      '[CameraPreviewScreen] Preview size: ${controller.value.previewSize}',
    );
    debugPrint(
      '[CameraPreviewScreen] Using device ratio + BoxFit.cover for full-screen preview',
    );
    debugPrint(
      '[CameraPreviewScreen] ==========================================',
    );

    // ✅ PROPER FULL-SCREEN CAMERA: Use device ratio, not camera ratio
    // This fills the entire screen by cropping camera output, just like default camera apps
    return ClipRect(
      child: OverflowBox(
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: size.width,
            height: size.width / deviceRatio, // Force device aspect ratio
            child: CameraPreview(controller),
          ),
        ),
      ),
    );
  }

  /// Build simulator camera preview
  Widget _buildSimulatorPreview() {
    return Container(
      color: Colors.black,
      child: Stack(
        children: [
          // Mock camera viewfinder with gradient background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF6366F1), // Indigo
                  Color(0xFF8B5CF6), // Purple
                  Color(0xFFEC4899), // Pink
                ],
              ),
            ),
          ),

          // Camera viewfinder overlay
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Camera icon
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.2),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.5),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.camera_alt,
                    color: Colors.white,
                    size: 48,
                  ),
                ),

                const SizedBox(height: 24),

                // Simulator mode text
                const Text(
                  'MarketSnap',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),

                const SizedBox(height: 8),

                const Text(
                  'Simulator Camera',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),

                const SizedBox(height: 16),

                // Instructions
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: Colors.black.withValues(alpha: 0.3),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    _isRecordingVideo
                        ? 'Recording video... $_recordingCountdown seconds left'
                        : 'Tap red button for 5-sec video or photo button',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),

          // Viewfinder grid (optional)
          if (_showViewfinderGrid()) _buildViewfinderGrid(),
        ],
      ),
    );
  }

  /// Check if viewfinder grid should be shown
  bool _showViewfinderGrid() {
    return true; // Always show grid in simulator for better visual feedback
  }

  /// Build viewfinder grid overlay
  Widget _buildViewfinderGrid() {
    return CustomPaint(size: Size.infinite, painter: ViewfinderGridPainter());
  }

  /// Build camera controls overlay
  Widget _buildCameraControls() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Colors.black.withValues(alpha: 0.8),
              Colors.black.withValues(alpha: 0.4),
              Colors.transparent,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Recording countdown display
              if (_isRecordingVideo) _buildRecordingCountdown(),

              const SizedBox(height: 16),

              // Control buttons row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Flash toggle button
                  _buildControlButton(
                    onPressed: _cameraService.hasFlash && !_isRecordingVideo
                        ? _toggleFlash
                        : null,
                    icon: _getFlashIcon(),
                    label: 'Flash',
                  ),

                  // Main capture button (photo or video)
                  _buildMainCaptureButton(),

                  // Camera switch button
                  _buildControlButton(
                    onPressed:
                        (_cameraService.cameras?.length ?? 0) > 1 &&
                            !_isTakingPhoto &&
                            !_isRecordingVideo
                        ? _switchCamera
                        : null,
                    icon: Icons.cameraswitch,
                    label: 'Switch',
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Mode selector (Photo/Video)
              if (!_isRecordingVideo && !_isTakingPhoto) _buildModeSelector(),
            ],
          ),
        ),
      ),
    );
  }

  /// Build recording countdown display
  Widget _buildRecordingCountdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(25),
        color: Colors.red.withValues(alpha: 0.9),
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Recording indicator (pulsing red dot)
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.5, end: 1.0),
            duration: const Duration(milliseconds: 500),
            builder: (context, value, child) {
              return Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: value),
                ),
              );
            },
          ),

          const SizedBox(width: 12),

          // Countdown text
          Text(
            'REC $_recordingCountdown',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),

          const SizedBox(width: 12),

          // Cancel button
          GestureDetector(
            onTap: _cancelVideoRecording,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.2),
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 16),
            ),
          ),
        ],
      ),
    );
  }

  /// Build main capture button (adapts based on mode)
  Widget _buildMainCaptureButton() {
    return GestureDetector(
      onTap: _isRecordingVideo
          ? _stopVideoRecording
          : _isTakingPhoto
          ? null
          : _startVideoRecording,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _isRecordingVideo ? Colors.red : Colors.white,
          border: Border.all(
            color: _isRecordingVideo ? Colors.white : Colors.white,
            width: 4,
          ),
        ),
        child: _isTakingPhoto
            ? const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                  ),
                ),
              )
            : _isRecordingVideo
            ? const Icon(Icons.stop, color: Colors.white, size: 32)
            : Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.red,
                ),
              ),
      ),
    );
  }

  /// Build mode selector (Photo/Video)
  Widget _buildModeSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.black.withValues(alpha: 0.5),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Photo mode button
          GestureDetector(
            onTap: () => _capturePhoto(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Colors.white.withValues(alpha: 0.2),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.camera_alt, color: Colors.white, size: 16),
                  SizedBox(width: 6),
                  Text(
                    'Photo',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Video mode button (currently selected)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: Colors.red.withValues(alpha: 0.8),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.videocam, color: Colors.white, size: 16),
                SizedBox(width: 6),
                Text(
                  'Video (5s)',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build individual control button
  Widget _buildControlButton({
    required VoidCallback? onPressed,
    required IconData icon,
    required String label,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black.withValues(alpha: 0.5),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: IconButton(
            onPressed: onPressed,
            icon: Icon(
              icon,
              color: onPressed != null ? Colors.white : Colors.grey,
              size: 24,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: onPressed != null ? Colors.white : Colors.grey,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  /// Build top controls (close button, camera info, sign out button)
  Widget _buildTopControls() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.6),
              Colors.black.withValues(alpha: 0.3),
              Colors.transparent,
            ],
          ),
        ),
        child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Close button
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withValues(alpha: 0.5),
                ),
                child: IconButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.close, color: Colors.white, size: 24),
                ),
              ),

              // Center info (camera info)
              if (_cameraService.isInitialized)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: Colors.black.withValues(alpha: 0.5),
                  ),
                  child: Text(
                    _cameraService.isSimulatorMode
                        ? 'Simulator Mode'
                        : _cameraService.isFrontCamera
                        ? 'Front Camera'
                        : 'Back Camera',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
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
    // Set status bar to light content for dark camera interface
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
    );

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera preview or loading/error state
          if (_isInitializing)
            Container(
              color: Colors.black,
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Initializing camera...',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            )
          else if (_errorMessage != null)
            Container(
              color: Colors.black,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.camera_alt_outlined,
                        color: Colors.white,
                        size: 64,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Camera Error',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _initializeCamera,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            // Camera preview
            SizedBox.expand(child: _buildCameraPreview()),

          // Camera controls overlay
          if (!_isInitializing && _errorMessage == null) ...[
            _buildTopControls(),
            _buildCameraControls(),
          ],
        ],
      ),
    );
  }
}
