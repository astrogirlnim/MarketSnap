import 'dart:io';
import 'dart:ui' as ui;
import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/material.dart';

/// Service responsible for camera operations including initialization,
/// photo capture, video recording, and camera management across iOS and Android platforms
/// Includes simulator support with mock camera functionality
///
/// ✅ BUFFER OVERFLOW FIX: Enhanced with proper disposal, lifecycle management,
/// and buffer optimization to prevent ImageReader_JNI buffer overflow warnings
class CameraService {
  static CameraService? _instance;
  static CameraService get instance => _instance ??= CameraService._();

  CameraService._();

  List<CameraDescription>? _cameras;
  CameraController? _controller;
  bool _isInitialized = false;
  bool _isSimulatorMode = false;
  String? _lastError;

  // ✅ BUFFER OVERFLOW FIX: Add disposal tracking and timeout management
  bool _isDisposing = false;
  Timer? _disposalTimeoutTimer;
  static const Duration _disposalTimeout = Duration(seconds: 5);

  // ✅ BUFFER OVERFLOW FIX: Add lifecycle state tracking
  bool _isPaused = false;
  bool _isInBackground = false;

  // ✅ CAMERA UNAVAILABLE FIX: Add initialization retry logic and state tracking
  bool _isInitializing = false;
  int _initializationAttempts = 0;
  static const int _maxInitializationAttempts = 3;
  Timer? _retryTimer;
  static const Duration _retryDelay = Duration(milliseconds: 500);

  // ✅ ZOOM LEVEL FIX: Track zoom levels manually since camera plugin doesn't provide getCurrentZoomLevel()
  double _minAvailableZoom = 1.0;
  double _maxAvailableZoom = 1.0;
  double _currentZoomLevel = 1.0;

  // Video recording state management
  bool _isRecordingVideo = false;
  Timer? _recordingTimer;
  int _recordingDuration = 0;
  static const int _maxRecordingDuration = 5; // 5 seconds max
  StreamController<int>? _countdownController;
  String? _lastVideoPath; // ✅ FIX: Store the path of the last recorded video

  /// Available cameras on the device
  List<CameraDescription>? get cameras => _cameras;

  /// Current camera controller
  CameraController? get controller => _controller;

  /// Whether the camera service is initialized
  bool get isInitialized => _isInitialized;

  /// Whether running in simulator mode (mock camera)
  bool get isSimulatorMode => _isSimulatorMode;

  /// Last error that occurred during camera operations
  String? get lastError => _lastError;

  /// Whether the current camera is the front camera (or simulated front camera)
  bool get isFrontCamera => _isSimulatorMode
      ? false
      : _controller?.description.lensDirection == CameraLensDirection.front;

  /// Whether currently recording video
  bool get isRecordingVideo => _isRecordingVideo;

  /// Current recording duration in seconds
  int get recordingDuration => _recordingDuration;

  /// Maximum recording duration in seconds
  int get maxRecordingDuration => _maxRecordingDuration;

  /// Stream for countdown updates during video recording
  Stream<int>? get countdownStream => _countdownController?.stream;

  /// ✅ FIX: Getter for the last recorded video path
  String? get lastVideoPath => _lastVideoPath;

  /// ✅ BUFFER OVERFLOW FIX: Whether camera is currently paused
  bool get isPaused => _isPaused;

  /// ✅ BUFFER OVERFLOW FIX: Whether app is in background
  bool get isInBackground => _isInBackground;

  /// Check if running on a simulator/emulator
  bool _isRunningOnSimulator() {
    if (kIsWeb) return true;

    // iOS Simulator detection
    if (Platform.isIOS) {
      // iOS simulators typically have no cameras or very limited camera support
      return true; // For now, assume iOS simulator always needs mock mode
    }

    // Android Emulator detection
    if (Platform.isAndroid) {
      // Android emulators may have virtual cameras, so we'll check camera availability
      return false; // Let Android emulators try real camera first
    }

    return false;
  }

  /// Check if running on Android emulator specifically
  bool _isAndroidEmulator() {
    if (!Platform.isAndroid) return false;

    // ✅ PRODUCTION FIX: Proper Android emulator detection
    // Previous logic was always returning true for ALL Android devices,
    // causing ResolutionPreset.low instead of ResolutionPreset.high in production
    try {
      // In production builds, NEVER treat devices as emulators
      // This ensures production Android devices always get high quality
      if (!kDebugMode) {
        debugPrint(
          '[CameraService] Production build detected - using high quality',
        );
        return false;
      }

      // In debug mode, we still prefer high quality unless explicitly detected as emulator
      // In a full implementation, we would check Build.PRODUCT, Build.MODEL, etc.
      // For now, we'll be conservative and prefer high quality even in debug mode
      debugPrint('[CameraService] Debug build - defaulting to high quality');
      return false;
    } catch (e) {
      debugPrint('[CameraService] Error in emulator detection: $e');
      // Always default to production quality on error
      return false;
    }
  }

  /// Initialize the camera service and get available cameras
  Future<bool> initialize() async {
    try {
      debugPrint('[CameraService] Initializing camera service...');
      _lastError = null;

      // Check if we're on a simulator first
      bool simulatorDetected = _isRunningOnSimulator();

      // Get available cameras
      _cameras = await availableCameras();
      debugPrint('[CameraService] Found ${_cameras?.length ?? 0} cameras');

      // If no cameras available or simulator detected, use mock mode
      if (_cameras == null || _cameras!.isEmpty || simulatorDetected) {
        debugPrint(
          '[CameraService] No physical cameras available or simulator detected',
        );
        debugPrint('[CameraService] Enabling simulator mode with mock camera');

        _isSimulatorMode = true;
        _cameras = _createMockCameras();

        debugPrint('[CameraService] Created ${_cameras!.length} mock cameras');
        for (int i = 0; i < _cameras!.length; i++) {
          final camera = _cameras![i];
          debugPrint(
            '[CameraService] Mock Camera $i: ${camera.name} (${camera.lensDirection})',
          );
        }
      } else {
        // Log available real cameras for debugging
        _isSimulatorMode = false;
        for (int i = 0; i < _cameras!.length; i++) {
          final camera = _cameras![i];
          debugPrint(
            '[CameraService] Real Camera $i: ${camera.name} (${camera.lensDirection})',
          );
        }
      }

      _isInitialized = true;
      debugPrint(
        '[CameraService] Camera service initialized successfully (simulator mode: $_isSimulatorMode)',
      );
      return true;
    } catch (e) {
      _lastError = 'Failed to initialize camera: $e';
      debugPrint('[CameraService] ERROR: $_lastError');
      _isInitialized = false;
      return false;
    }
  }

  /// Create mock cameras for simulator testing
  List<CameraDescription> _createMockCameras() {
    return [
      const CameraDescription(
        name: 'Mock Back Camera',
        lensDirection: CameraLensDirection.back,
        sensorOrientation: 90,
      ),
      const CameraDescription(
        name: 'Mock Front Camera',
        lensDirection: CameraLensDirection.front,
        sensorOrientation: 270,
      ),
    ];
  }

  /// Initialize camera controller with the specified camera
  /// Defaults to back camera if available, otherwise uses first available camera
  /// ✅ CAMERA UNAVAILABLE FIX: Enhanced with robust retry logic and race condition protection
  Future<bool> initializeCamera({CameraDescription? camera}) async {
    try {
      debugPrint('[CameraService] ========== CAMERA INITIALIZATION START ==========');
      debugPrint('[CameraService] Attempt ${_initializationAttempts + 1}/$_maxInitializationAttempts');
      debugPrint('[CameraService] Current state - isPaused: $_isPaused, isInBackground: $_isInBackground');
      debugPrint('[CameraService] Current state - isInitializing: $_isInitializing, isDisposing: $_isDisposing');
      
      _lastError = null;

      // ✅ CAMERA UNAVAILABLE FIX: Prevent concurrent initialization attempts
      if (_isInitializing) {
        debugPrint('[CameraService] Already initializing, waiting for completion...');
        // Wait for current initialization to complete
        while (_isInitializing && _initializationAttempts < _maxInitializationAttempts) {
          await Future.delayed(const Duration(milliseconds: 100));
        }
        // Return success if initialization completed while we were waiting
        if (_controller?.value.isInitialized == true) {
          debugPrint('[CameraService] Initialization completed while waiting');
          return true;
        }
      }

      _isInitializing = true;

      // ✅ CAMERA UNAVAILABLE FIX: Enhanced race condition protection
      if (_isDisposing) {
        debugPrint('[CameraService] Controller is being disposed, waiting for completion...');
        int waitAttempts = 0;
        while (_isDisposing && waitAttempts < 20) { // Wait up to 2 seconds
          await Future.delayed(const Duration(milliseconds: 100));
          waitAttempts++;
        }
        if (_isDisposing) {
          _lastError = 'Camera controller disposal timeout';
          debugPrint('[CameraService] ERROR: $_lastError');
          _isInitializing = false;
          return false;
        }
      }

      // ✅ CAMERA UNAVAILABLE FIX: Ensure service is initialized first
      if (!_isInitialized) {
        debugPrint('[CameraService] Service not initialized, initializing first...');
        if (!await initialize()) {
          _lastError = _lastError ?? 'Failed to initialize camera service';
          debugPrint('[CameraService] ERROR: $_lastError');
          _isInitializing = false;
          return false;
        }
      }

      // ✅ CAMERA UNAVAILABLE FIX: Enhanced null safety checks
      if (_cameras == null || _cameras!.isEmpty) {
        _lastError = 'No cameras available on device';
        debugPrint('[CameraService] ERROR: $_lastError');
        _isInitializing = false;
        return false;
      }

      // In simulator mode, we don't create a real camera controller
      if (_isSimulatorMode) {
        debugPrint('[CameraService] Simulator mode - skipping real camera controller initialization');
        _isInitializing = false;
        _initializationAttempts = 0; // Reset attempts on success
        return true;
      }

      // ✅ CAMERA UNAVAILABLE FIX: Dispose existing controller safely before creating new one
      if (_controller != null) {
        debugPrint('[CameraService] Disposing existing controller before reinitializing...');
        await disposeController();
        // Small delay to ensure disposal is complete
        await Future.delayed(const Duration(milliseconds: 50));
      }

      // Select camera to use
      CameraDescription selectedCamera;
      if (camera != null) {
        selectedCamera = camera;
        debugPrint('[CameraService] Using provided camera: ${camera.name}');
      } else {
        // Default to back camera, fallback to first available
        selectedCamera = _cameras!.firstWhere(
          (camera) => camera.lensDirection == CameraLensDirection.back,
          orElse: () => _cameras!.first,
        );
        debugPrint('[CameraService] Using default camera: ${selectedCamera.name} (${selectedCamera.lensDirection})');
      }

      // ✅ CAMERA UNAVAILABLE FIX: Enhanced camera controller creation with timeout protection
      final ResolutionPreset resolution = _isAndroidEmulator()
          ? ResolutionPreset.low // Low resolution for emulators
          : ResolutionPreset.high; // High quality for real devices

      debugPrint('[CameraService] Creating camera controller with resolution: $resolution');

      _controller = CameraController(
        selectedCamera,
        resolution,
        enableAudio: true,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      // ✅ CAMERA UNAVAILABLE FIX: Verify controller creation
      if (_controller == null) {
        _lastError = 'Failed to create camera controller';
        debugPrint('[CameraService] ERROR: $_lastError');
        _isInitializing = false;
        return false;
      }

      debugPrint('[CameraService] Initializing camera controller with timeout protection...');

      // ✅ CAMERA UNAVAILABLE FIX: Initialize with timeout to prevent hanging
      bool initializationSuccess = false;
      try {
        await _controller!.initialize().timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            throw TimeoutException('Camera initialization timeout', const Duration(seconds: 10));
          },
        );
        initializationSuccess = true;
      } on TimeoutException catch (e) {
        _lastError = 'Camera initialization timed out: $e';
        debugPrint('[CameraService] ERROR: $_lastError');
      } catch (e) {
        _lastError = 'Camera initialization failed: $e';
        debugPrint('[CameraService] ERROR: $_lastError');
      }

      // ✅ CAMERA UNAVAILABLE FIX: Verify initialization success
      if (!initializationSuccess || _controller == null || !_controller!.value.isInitialized) {
        _lastError = _lastError ?? 'Camera controller failed to initialize properly';
        debugPrint('[CameraService] ERROR: $_lastError');
        
        // Clean up failed controller
        if (_controller != null) {
          try {
            await _controller!.dispose();
          } catch (e) {
            debugPrint('[CameraService] Warning: Error disposing failed controller: $e');
          }
          _controller = null;
        }
        
        _isInitializing = false;
        return false;
      }

      debugPrint('[CameraService] ✅ Camera controller initialized successfully');
      debugPrint('[CameraService] Camera resolution: ${_controller!.value.previewSize}');

      // ✅ CAMERA UNAVAILABLE FIX: Initialize zoom levels with error handling
      try {
        _minAvailableZoom = await _controller!.getMinZoomLevel();
        _maxAvailableZoom = await _controller!.getMaxZoomLevel();
        _currentZoomLevel = _minAvailableZoom;
        debugPrint('[CameraService] Zoom levels initialized - min: $_minAvailableZoom, max: $_maxAvailableZoom');
      } catch (e) {
        debugPrint('[CameraService] Warning: Failed to initialize zoom levels: $e');
        // Use default values if zoom level initialization fails
        _minAvailableZoom = 1.0;
        _maxAvailableZoom = 1.0;
        _currentZoomLevel = 1.0;
      }

      // ✅ CAMERA UNAVAILABLE FIX: Reset state on successful initialization
      _initializationAttempts = 0;
      _isInitializing = false;
      _isPaused = false;
      
      debugPrint('[CameraService] ========== CAMERA INITIALIZATION SUCCESS ==========');
      return true;

    } catch (e) {
      _lastError = 'Failed to initialize camera controller: $e';
      debugPrint('[CameraService] ERROR: $_lastError');
      
      // Clean up on error
      if (_controller != null) {
        try {
          await _controller!.dispose();
        } catch (disposeError) {
          debugPrint('[CameraService] Warning: Error disposing controller after failed initialization: $disposeError');
        }
        _controller = null;
      }
      
      _isInitializing = false;
      return false;
    }
  }

  /// ✅ CAMERA UNAVAILABLE FIX: Enhanced initialization with automatic retry logic
  Future<bool> initializeCameraWithRetry({CameraDescription? camera}) async {
    _initializationAttempts = 0;
    
    while (_initializationAttempts < _maxInitializationAttempts) {
      _initializationAttempts++;
      
      debugPrint('[CameraService] Initialization attempt $_initializationAttempts/$_maxInitializationAttempts');
      
      final success = await initializeCamera(camera: camera);
      
      if (success) {
        debugPrint('[CameraService] ✅ Camera initialization successful on attempt $_initializationAttempts');
        return true;
      }
      
      // If not the last attempt, wait before retrying
      if (_initializationAttempts < _maxInitializationAttempts) {
        debugPrint('[CameraService] Retrying camera initialization in ${_retryDelay.inMilliseconds}ms...');
        await Future.delayed(_retryDelay);
      }
    }
    
    debugPrint('[CameraService] ❌ Camera initialization failed after $_maxInitializationAttempts attempts');
    debugPrint('[CameraService] Final error: $_lastError');
    return false;
  }

  /// Switch between front and back cameras
  Future<bool> switchCamera() async {
    try {
      debugPrint('[CameraService] Switching camera...');

      if (!_isInitialized || _cameras == null || _cameras!.length < 2) {
        _lastError = 'Camera switching not available';
        debugPrint('[CameraService] ERROR: $_lastError');
        return false;
      }

      if (_isSimulatorMode) {
        debugPrint('[CameraService] Simulator mode - simulating camera switch');
        return true;
      }

      // Find the opposite camera
      final currentDirection = _controller?.description.lensDirection;
      final targetDirection = currentDirection == CameraLensDirection.back
          ? CameraLensDirection.front
          : CameraLensDirection.back;

      final targetCamera = _cameras!.firstWhere(
        (camera) => camera.lensDirection == targetDirection,
        orElse: () => _cameras!.first,
      );

      debugPrint(
        '[CameraService] Switching from $currentDirection to ${targetCamera.lensDirection}',
      );

      return await initializeCamera(camera: targetCamera);
    } catch (e) {
      _lastError = 'Failed to switch camera: $e';
      debugPrint('[CameraService] ERROR: $_lastError');
      return false;
    }
  }

  /// Capture a photo and return the file path
  Future<String?> capturePhoto() async {
    try {
      debugPrint('[CameraService] Capturing photo...');
      _lastError = null;

      if (_isSimulatorMode) {
        return await _captureSimulatorPhoto();
      }

      if (_controller == null || !_controller!.value.isInitialized) {
        _lastError = 'Camera not initialized';
        debugPrint('[CameraService] ERROR: $_lastError');
        return null;
      }

      // Generate unique filename with timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filename = 'marketsnap_photo_$timestamp.jpg';

      // Get app documents directory for storing photos
      final Directory appDir = await getApplicationDocumentsDirectory();
      final String photoPath = path.join(appDir.path, 'photos', filename);

      // Create photos directory if it doesn't exist
      final Directory photosDir = Directory(path.dirname(photoPath));
      if (!await photosDir.exists()) {
        await photosDir.create(recursive: true);
        debugPrint(
          '[CameraService] Created photos directory: ${photosDir.path}',
        );
      }

      debugPrint('[CameraService] Taking photo to: $photoPath');

      // Capture the photo
      final XFile photo = await _controller!.takePicture();

      // Move the photo to our app directory
      final File photoFile = File(photo.path);
      final File savedPhoto = await photoFile.copy(photoPath);

      // Clean up temporary file
      try {
        await photoFile.delete();
      } catch (e) {
        debugPrint('[CameraService] Warning: Could not delete temp file: $e');
      }

      final fileSize = await savedPhoto.length();
      debugPrint('[CameraService] Photo captured successfully');
      debugPrint('[CameraService] Photo path: $photoPath');
      debugPrint(
        '[CameraService] Photo size: ${(fileSize / 1024).toStringAsFixed(1)} KB',
      );

      return photoPath;
    } catch (e) {
      _lastError = 'Failed to capture photo: $e';
      debugPrint('[CameraService] ERROR: $_lastError');
      return null;
    }
  }

  /// Capture a simulated photo for testing on simulators
  Future<String?> _captureSimulatorPhoto() async {
    try {
      debugPrint('[CameraService] Capturing simulator photo...');

      // Generate unique filename with timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filename = 'marketsnap_simulator_photo_$timestamp.jpg';

      // Get app documents directory for storing photos
      final Directory appDir = await getApplicationDocumentsDirectory();
      final String photoPath = path.join(appDir.path, 'photos', filename);

      // Create photos directory if it doesn't exist
      final Directory photosDir = Directory(path.dirname(photoPath));
      if (!await photosDir.exists()) {
        await photosDir.create(recursive: true);
        debugPrint(
          '[CameraService] Created photos directory: ${photosDir.path}',
        );
      }

      // Create a mock image (colored rectangle with text)
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final size = const Size(800, 600);

      // Draw background gradient
      final paint = Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF6366F1), // Indigo
            Color(0xFF8B5CF6), // Purple
            Color(0xFFEC4899), // Pink
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);

      // Draw text
      final textPainter = TextPainter(
        text: TextSpan(
          text:
              'MarketSnap\nSimulator Photo\n${DateTime.now().toString().split('.')[0]}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      );

      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          (size.width - textPainter.width) / 2,
          (size.height - textPainter.height) / 2,
        ),
      );

      // Convert to image
      final picture = recorder.endRecording();
      final image = await picture.toImage(
        size.width.toInt(),
        size.height.toInt(),
      );
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final uint8List = byteData!.buffer.asUint8List();

      // Save to file
      final file = File(photoPath);
      await file.writeAsBytes(uint8List);

      final fileSize = await file.length();
      debugPrint('[CameraService] Simulator photo created successfully');
      debugPrint('[CameraService] Photo path: $photoPath');
      debugPrint(
        '[CameraService] Photo size: ${(fileSize / 1024).toStringAsFixed(1)} KB',
      );

      return photoPath;
    } catch (e) {
      _lastError = 'Failed to create simulator photo: $e';
      debugPrint('[CameraService] ERROR: $_lastError');
      return null;
    }
  }

  /// Start video recording with 5-second maximum duration and countdown
  Future<bool> startVideoRecording() async {
    try {
      debugPrint('[CameraService] Starting video recording...');
      _lastError = null;
      _lastVideoPath = null; // ✅ FIX: Clear previous path on new recording

      if (_isRecordingVideo) {
        _lastError = 'Already recording video';
        debugPrint('[CameraService] ERROR: $_lastError');
        return false;
      }

      if (_isSimulatorMode) {
        return await _startSimulatorVideoRecording();
      }

      if (_controller == null || !_controller!.value.isInitialized) {
        _lastError = 'Camera not initialized';
        debugPrint('[CameraService] ERROR: $_lastError');
        return false;
      }

      // Check if already recording
      if (_controller!.value.isRecordingVideo) {
        _lastError = 'Camera is already recording';
        debugPrint('[CameraService] ERROR: $_lastError');
        return false;
      }

      debugPrint('[CameraService] Starting camera video recording...');

      // Log the resolution preset and platform for debugging
      debugPrint('[CameraService] Video Recording Debug:');
      debugPrint('  Platform: [32m${Platform.operatingSystem}[0m');
      debugPrint('  Is Android: ${Platform.isAndroid}');
      debugPrint('  Is Emulator: ${_isAndroidEmulator()}');
      debugPrint(
        '  ResolutionPreset: ${_isAndroidEmulator() ? 'LOW' : 'HIGH'}',
      );
      debugPrint(
        '  Controller Preview Size: [36m${_controller?.value.previewSize}[0m',
      );

      // Start recording with optimized settings for emulators
      if (_isAndroidEmulator()) {
        debugPrint(
          '[CameraService] Using emulator-optimized video recording settings. Video will be at lowest possible quality to avoid buffer overflow.',
        );
        debugPrint(
          '[CameraService] If buffer overflow persists, video recording may be disabled on emulator.',
        );
      }

      // Start recording
      await _controller!.startVideoRecording();

      // Initialize countdown controller
      _countdownController = StreamController<int>.broadcast();

      // Set recording state
      _isRecordingVideo = true;
      _recordingDuration = 0;

      // Start countdown timer (counts up from 0 to 5 seconds)
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (
        timer,
      ) async {
        _recordingDuration++;
        debugPrint(
          '[CameraService] Recording duration: $_recordingDuration seconds',
        );

        // Auto-stop at 5 seconds BEFORE emitting countdown update
        if (_recordingDuration >= _maxRecordingDuration) {
          debugPrint(
            '[CameraService] Maximum recording duration reached, stopping...',
          );
          await stopVideoRecording();

          // ✅ FIX: Emit final countdown update AFTER stopping video
          // This ensures _lastVideoPath is set before UI tries to access it
          final remainingTime = _maxRecordingDuration - _recordingDuration;
          _countdownController?.add(remainingTime);
        } else {
          // Emit countdown update (remaining time) for non-final updates
          final remainingTime = _maxRecordingDuration - _recordingDuration;
          _countdownController?.add(remainingTime);
        }
      });

      debugPrint('[CameraService] Video recording started successfully');
      return true;
    } catch (e) {
      _lastError = 'Failed to start video recording: $e';
      debugPrint('[CameraService] ERROR: $_lastError');
      await _cleanupVideoRecording();
      return false;
    }
  }

  /// Start simulated video recording for testing on simulators
  Future<bool> _startSimulatorVideoRecording() async {
    try {
      debugPrint('[CameraService] Starting simulator video recording...');

      // Initialize countdown controller
      _countdownController = StreamController<int>.broadcast();

      // Set recording state
      _isRecordingVideo = true;
      _recordingDuration = 0;

      // Start countdown timer (counts up from 0 to 5 seconds)
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (
        timer,
      ) async {
        _recordingDuration++;
        debugPrint(
          '[CameraService] Simulator recording duration: $_recordingDuration seconds',
        );

        // Auto-stop at 5 seconds BEFORE emitting countdown update
        if (_recordingDuration >= _maxRecordingDuration) {
          debugPrint(
            '[CameraService] Simulator maximum recording duration reached, stopping...',
          );
          await stopVideoRecording();

          // ✅ FIX: Emit final countdown update AFTER stopping video
          // This ensures _lastVideoPath is set before UI tries to access it
          final remainingTime = _maxRecordingDuration - _recordingDuration;
          _countdownController?.add(remainingTime);
        } else {
          // Emit countdown update (remaining time) for non-final updates
          final remainingTime = _maxRecordingDuration - _recordingDuration;
          _countdownController?.add(remainingTime);
        }
      });

      debugPrint(
        '[CameraService] Simulator video recording started successfully',
      );
      return true;
    } catch (e) {
      _lastError = 'Failed to start simulator video recording: $e';
      debugPrint('[CameraService] ERROR: $_lastError');
      await _cleanupVideoRecording();
      return false;
    }
  }

  /// Stop video recording and return the file path
  Future<String?> stopVideoRecording() async {
    try {
      debugPrint('[CameraService] Stopping video recording...');
      _lastError = null;

      if (!_isRecordingVideo) {
        _lastError = 'Not currently recording video';
        debugPrint('[CameraService] ERROR: $_lastError');
        return null;
      }

      if (_isSimulatorMode) {
        return await _stopSimulatorVideoRecording();
      }

      if (_controller == null || !_controller!.value.isInitialized) {
        _lastError = 'Camera not initialized';
        debugPrint('[CameraService] ERROR: $_lastError');
        await _cleanupVideoRecording();
        return null;
      }

      if (!_controller!.value.isRecordingVideo) {
        _lastError = 'Camera is not recording';
        debugPrint('[CameraService] ERROR: $_lastError');
        await _cleanupVideoRecording();
        return null;
      }

      debugPrint('[CameraService] Stopping camera video recording...');

      // Stop the recording and get the file
      final XFile videoFile = await _controller!.stopVideoRecording();

      // Generate unique filename with timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filename = 'marketsnap_video_$timestamp.mp4';

      // Get app documents directory for storing videos
      final Directory appDir = await getApplicationDocumentsDirectory();
      final String videoPath = path.join(appDir.path, 'videos', filename);

      // Create videos directory if it doesn't exist
      final Directory videosDir = Directory(path.dirname(videoPath));
      if (!await videosDir.exists()) {
        await videosDir.create(recursive: true);
        debugPrint(
          '[CameraService] Created videos directory: ${videosDir.path}',
        );
      }

      // Move the video to our app directory
      final File tempVideoFile = File(videoFile.path);
      final File savedVideo = await tempVideoFile.copy(videoPath);

      // Clean up temporary file
      try {
        await tempVideoFile.delete();
      } catch (e) {
        debugPrint(
          '[CameraService] Warning: Could not delete temp video file: $e',
        );
      }

      // Emulator-specific: If buffer overflow persists, consider disabling video recording on emulator
      if (_isAndroidEmulator()) {
        final fileSize = await savedVideo.length();
        debugPrint(
          '[CameraService] Emulator video file size: ${(fileSize / 1024).toStringAsFixed(1)} KB',
        );
        if (fileSize > 2 * 1024 * 1024) {
          // 2MB threshold for emulator
          debugPrint(
            '[CameraService] WARNING: Emulator video file is too large, buffer overflow may occur.',
          );
          // Optionally, delete the file and return null to disable video on emulator
          // await savedVideo.delete();
          // _lastError = 'Emulator video recording disabled due to buffer overflow risk.';
          // await _cleanupVideoRecording();
          // return null;
        }
      }

      final fileSize = await savedVideo.length();
      debugPrint('[CameraService] Video recording stopped successfully');
      debugPrint('[CameraService] Video path: $videoPath');
      debugPrint(
        '[CameraService] Video size: ${(fileSize / 1024).toStringAsFixed(1)} KB',
      );

      _lastVideoPath =
          savedVideo.path; // ✅ FIX: Store the path before returning

      // Clean up video recording state
      await _cleanupVideoRecording();

      return videoPath;
    } catch (e) {
      _lastError = 'Failed to stop video recording: $e';
      debugPrint('[CameraService] ERROR: $_lastError');
      await _cleanupVideoRecording();
      return null;
    }
  }

  /// Stop simulated video recording for testing on simulators
  Future<String?> _stopSimulatorVideoRecording() async {
    try {
      debugPrint('[CameraService] Stopping simulator video recording...');

      // Generate unique filename with timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filename = 'marketsnap_simulator_video_$timestamp.mp4';

      // Get app documents directory for storing videos
      final Directory appDir = await getApplicationDocumentsDirectory();
      final String videoPath = path.join(appDir.path, 'videos', filename);

      // Create videos directory if it doesn't exist
      final Directory videosDir = Directory(path.dirname(videoPath));
      if (!await videosDir.exists()) {
        await videosDir.create(recursive: true);
        debugPrint(
          '[CameraService] Created videos directory: ${videosDir.path}',
        );
      }

      // Create a mock video file (just a text file)
      final String videoContent =
          'This is a mock video file generated by the simulator.\n'
          'Timestamp: ${DateTime.now()}\n'
          'Path: $videoPath';

      final file = File(videoPath);
      await file.writeAsString(videoContent);

      final fileSize = await file.length();
      debugPrint('[CameraService] Simulator video created successfully');
      debugPrint('[CameraService] Video path: $videoPath');
      debugPrint(
        '[CameraService] Video size: ${(fileSize / 1024).toStringAsFixed(1)} KB',
      );

      _lastVideoPath = videoPath; // ✅ FIX: Store the path before returning

      // Clean up video recording state
      await _cleanupVideoRecording();

      return videoPath;
    } catch (e) {
      _lastError = 'Failed to create simulator video: $e';
      debugPrint('[CameraService] ERROR: $_lastError');
      await _cleanupVideoRecording();
      return null;
    }
  }

  /// Cancel video recording without saving the file
  Future<void> cancelVideoRecording() async {
    try {
      debugPrint('[CameraService] Cancelling video recording...');
      _lastError = null;
      _lastVideoPath = null; // ✅ FIX: Clear path on cancellation

      if (!_isRecordingVideo) {
        // Already cleaned up or never started, do nothing
        return;
      }

      if (!_isSimulatorMode &&
          _controller != null &&
          _controller!.value.isInitialized &&
          _controller!.value.isRecordingVideo) {
        // Stop recording but don't save the file
        final XFile videoFile = await _controller!.stopVideoRecording();

        // Delete the temporary file
        try {
          await File(videoFile.path).delete();
          debugPrint('[CameraService] Temporary video file deleted');
        } catch (e) {
          debugPrint(
            '[CameraService] Warning: Could not delete temp video file: $e',
          );
        }
      }

      await _cleanupVideoRecording();
      debugPrint('[CameraService] Video recording cancelled successfully');
    } catch (e) {
      debugPrint('[CameraService] Error cancelling video recording: $e');
      await _cleanupVideoRecording();
    }
  }

  /// Clean up video recording state and resources
  Future<void> _cleanupVideoRecording() async {
    debugPrint('[CameraService] Cleaning up video recording state...');

    // Cancel timer
    _recordingTimer?.cancel();
    _recordingTimer = null;

    // Close countdown stream controller
    await _countdownController?.close();
    _countdownController = null;

    // Reset recording state
    _isRecordingVideo = false;
    _recordingDuration = 0;

    debugPrint('[CameraService] Video recording cleanup completed');
  }

  /// Get camera flash modes available for current camera
  List<FlashMode> getAvailableFlashModes() {
    if (_controller == null || !_controller!.value.isInitialized) {
      return [];
    }

    // Return common flash modes - the camera plugin handles availability
    return [FlashMode.off, FlashMode.auto, FlashMode.always];
  }

  /// Set camera flash mode
  Future<bool> setFlashMode(FlashMode flashMode) async {
    try {
      debugPrint('[CameraService] Setting flash mode to: $flashMode');

      if (_controller == null || !_controller!.value.isInitialized) {
        _lastError = 'Camera not initialized';
        return false;
      }

      await _controller!.setFlashMode(flashMode);
      debugPrint('[CameraService] Flash mode set successfully');
      return true;
    } catch (e) {
      _lastError = 'Failed to set flash mode: $e';
      debugPrint('[CameraService] ERROR: $_lastError');
      return false;
    }
  }

  /// Get current flash mode
  FlashMode getCurrentFlashMode() {
    return _controller?.value.flashMode ?? FlashMode.off;
  }

  /// Set camera zoom level (0.0 to 1.0)
  Future<bool> setZoomLevel(double zoom) async {
    try {
      if (_controller == null || !_controller!.value.isInitialized) {
        return false;
      }

      // Clamp zoom between min and max
      final double minZoom = await _controller!.getMinZoomLevel();
      final double maxZoom = await _controller!.getMaxZoomLevel();
      final double clampedZoom = zoom.clamp(minZoom, maxZoom);

      await _controller!.setZoomLevel(clampedZoom);

      // ✅ ZOOM LEVEL FIX: Track the current zoom level manually
      _currentZoomLevel = clampedZoom;
      _minAvailableZoom = minZoom;
      _maxAvailableZoom = maxZoom;

      debugPrint(
        '[CameraService] Zoom set to: $clampedZoom (min: $minZoom, max: $maxZoom)',
      );
      return true;
    } catch (e) {
      debugPrint('[CameraService] Failed to set zoom: $e');
      return false;
    }
  }

  /// Get current zoom level
  Future<double> getCurrentZoomLevel() async {
    try {
      if (_controller == null || !_controller!.value.isInitialized) {
        return 1.0;
      }
      // ✅ BUG FIX: Camera plugin doesn't have getZoomLevel(), return tracked value
      return _currentZoomLevel;
    } catch (e) {
      debugPrint('[CameraService] Failed to get zoom level: $e');
      return 1.0;
    }
  }

  /// ✅ BUFFER OVERFLOW FIX: Enhanced camera controller disposal with timeout and proper cleanup
  Future<void> disposeController() async {
    if (_controller != null && !_isDisposing) {
      _isDisposing = true;
      debugPrint(
        '[CameraService] Disposing camera controller with timeout protection...',
      );

      try {
        // Cancel any ongoing video recording before disposing
        if (_isRecordingVideo) {
          debugPrint(
            '[CameraService] Cancelling video recording before disposal...',
          );
          await cancelVideoRecording();
        }

        // ✅ BUFFER OVERFLOW FIX: Use timeout to prevent hanging disposal
        _disposalTimeoutTimer = Timer(_disposalTimeout, () {
          debugPrint(
            '[CameraService] WARNING: Camera disposal timed out after ${_disposalTimeout.inSeconds}s',
          );
          _controller = null;
          _isDisposing = false;
        });

        // Dispose the controller
        await _controller!.dispose();

        // Cancel timeout timer if disposal completed successfully
        _disposalTimeoutTimer?.cancel();
        _disposalTimeoutTimer = null;

        debugPrint('[CameraService] Camera controller disposed successfully');
      } catch (e) {
        debugPrint('[CameraService] Error disposing camera controller: $e');
        // Continue with cleanup even if disposal failed
      } finally {
        _controller = null;
        _isDisposing = false;
        _disposalTimeoutTimer?.cancel();
        _disposalTimeoutTimer = null;

        // ✅ BUFFER OVERFLOW FIX: Reset lifecycle state on disposal
        _isPaused = false;
        _isInBackground = false;

        // ✅ ZOOM LEVEL FIX: Reset zoom levels on disposal
        _minAvailableZoom = 1.0;
        _maxAvailableZoom = 1.0;
        _currentZoomLevel = 1.0;

        debugPrint('[CameraService] Camera controller cleanup completed');
      }
    }
  }

  /// ✅ BUFFER OVERFLOW FIX: Pause camera operations (for background/tab switch)
  Future<void> pauseCamera() async {
    if (_isPaused) {
      debugPrint('[CameraService] Camera already paused');
      return;
    }

    debugPrint('[CameraService] Pausing camera operations...');
    _isPaused = true;

    // ✅ CAMERA UNAVAILABLE FIX: Don't dispose controller, just pause to prevent "unavailable" state
    // The controller remains valid for quick resume
    try {
      if (_controller?.value.isInitialized == true) {
        // Just mark as paused, don't dispose the controller
        debugPrint('[CameraService] Camera paused (controller preserved for quick resume)');
      }
    } catch (e) {
      debugPrint('[CameraService] Warning during camera pause: $e');
    }
  }

  /// ✅ CAMERA UNAVAILABLE FIX: Enhanced resume camera with validation and retry logic
  Future<bool> resumeCamera() async {
    debugPrint('[CameraService] ========== CAMERA RESUME START ==========');
    debugPrint('[CameraService] Current state - isPaused: $_isPaused, isInBackground: $_isInBackground');
    debugPrint('[CameraService] Controller state - exists: ${_controller != null}, initialized: ${_controller?.value.isInitialized}');

    if (!_isPaused && !_isInBackground) {
      debugPrint('[CameraService] Camera not paused, no need to resume');
      return _controller?.value.isInitialized == true;
    }

    _isPaused = false;
    _isInBackground = false;

    // ✅ CAMERA UNAVAILABLE FIX: Check if controller is still valid
    if (_controller?.value.isInitialized == true) {
      debugPrint('[CameraService] ✅ Camera controller still valid, resume successful');
      return true;
    }

    // ✅ CAMERA UNAVAILABLE FIX: Controller lost or invalid, reinitialize with retry logic
    debugPrint('[CameraService] Controller invalid, reinitializing with retry logic...');
    
    final success = await initializeCameraWithRetry();
    
    if (success) {
      debugPrint('[CameraService] ✅ Camera resume successful after reinitialization');
    } else {
      debugPrint('[CameraService] ❌ Camera resume failed - controller unavailable');
    }
    
    debugPrint('[CameraService] ========== CAMERA RESUME END ==========');
    return success;
  }

  /// ✅ BUFFER OVERFLOW FIX: Handle app going to background
  Future<void> handleAppInBackground() async {
    debugPrint('[CameraService] App going to background, pausing camera...');
    _isInBackground = true;
    await pauseCamera();
  }

  /// ✅ CAMERA UNAVAILABLE FIX: Enhanced app foreground handling with better error recovery
  Future<bool> handleAppInForeground() async {
    debugPrint('[CameraService] App returning to foreground, resuming camera...');
    _isInBackground = false;
    return await resumeCamera();
  }

  /// Dispose the entire camera service
  Future<void> dispose() async {
    debugPrint('[CameraService] Disposing camera service...');

    // Clean up video recording resources
    await _cleanupVideoRecording();

    // Cancel any pending disposal timers
    _disposalTimeoutTimer?.cancel();
    _disposalTimeoutTimer = null;

    await disposeController();
    _cameras = null;
    _isInitialized = false;
    _lastError = null;
    _isPaused = false;
    _isInBackground = false;
    _isDisposing = false;
    _instance = null;
    debugPrint('[CameraService] Camera service disposed');
  }

  /// Check if device has flash capability
  bool get hasFlash {
    if (_controller == null || !_controller!.value.isInitialized) {
      return false;
    }

    // For now, assume all back cameras have flash, front cameras don't
    // This is a reasonable assumption for most mobile devices
    return _controller!.description.lensDirection == CameraLensDirection.back;
  }

  /// Get camera preview aspect ratio
  double get aspectRatio {
    if (_controller == null || !_controller!.value.isInitialized) {
      return 16 / 9; // Default aspect ratio
    }
    return _controller!.value.aspectRatio;
  }

  /// Check if camera is currently taking a picture
  bool get isTakingPicture {
    return _controller?.value.isTakingPicture ?? false;
  }

  /// Vibrate device for camera feedback (cross-platform)
  Future<void> provideCameraFeedback() async {
    try {
      // Provide haptic feedback on photo capture
      await HapticFeedback.mediumImpact();
      debugPrint('[CameraService] Camera feedback provided');
    } catch (e) {
      debugPrint('[CameraService] Could not provide haptic feedback: $e');
    }
  }
}
