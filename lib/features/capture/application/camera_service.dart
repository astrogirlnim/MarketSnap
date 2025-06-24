import 'dart:io';
import 'dart:ui' as ui;
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/material.dart';

/// Service responsible for camera operations including initialization,
/// photo capture, and camera management across iOS and Android platforms
/// Includes simulator support with mock camera functionality
class CameraService {
  static CameraService? _instance;
  static CameraService get instance => _instance ??= CameraService._();
  
  CameraService._();

  List<CameraDescription>? _cameras;
  CameraController? _controller;
  bool _isInitialized = false;
  bool _isSimulatorMode = false;
  String? _lastError;

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
  bool get isFrontCamera => _isSimulatorMode ? false : 
      _controller?.description.lensDirection == CameraLensDirection.front;

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
        debugPrint('[CameraService] No physical cameras available or simulator detected');
        debugPrint('[CameraService] Enabling simulator mode with mock camera');
        
        _isSimulatorMode = true;
        _cameras = _createMockCameras();
        
        debugPrint('[CameraService] Created ${_cameras!.length} mock cameras');
        for (int i = 0; i < _cameras!.length; i++) {
          final camera = _cameras![i];
          debugPrint('[CameraService] Mock Camera $i: ${camera.name} (${camera.lensDirection})');
        }
      } else {
        // Log available real cameras for debugging
        _isSimulatorMode = false;
        for (int i = 0; i < _cameras!.length; i++) {
          final camera = _cameras![i];
          debugPrint('[CameraService] Real Camera $i: ${camera.name} (${camera.lensDirection})');
        }
      }

      _isInitialized = true;
      debugPrint('[CameraService] Camera service initialized successfully (simulator mode: $_isSimulatorMode)');
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
  Future<bool> initializeCamera({CameraDescription? camera}) async {
    try {
      debugPrint('[CameraService] Initializing camera controller...');
      _lastError = null;

      if (!_isInitialized) {
        debugPrint('[CameraService] Service not initialized, initializing first...');
        if (!await initialize()) {
          return false;
        }
      }

      // In simulator mode, we don't create a real camera controller
      if (_isSimulatorMode) {
        debugPrint('[CameraService] Simulator mode - skipping real camera controller initialization');
        return true;
      }

      // Dispose existing controller if any
      await disposeController();

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

      // Create camera controller with optimal settings
      _controller = CameraController(
        selectedCamera,
        ResolutionPreset.high, // High quality for market photos
        enableAudio: false, // We'll handle video audio separately
        imageFormatGroup: ImageFormatGroup.jpeg, // JPEG for photos
      );

      debugPrint('[CameraService] Initializing camera controller...');
      await _controller!.initialize();

      debugPrint('[CameraService] Camera controller initialized successfully');
      debugPrint('[CameraService] Camera resolution: ${_controller!.value.previewSize}');
      
      return true;
    } catch (e) {
      _lastError = 'Failed to initialize camera controller: $e';
      debugPrint('[CameraService] ERROR: $_lastError');
      await disposeController();
      return false;
    }
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

      debugPrint('[CameraService] Switching from $currentDirection to ${targetCamera.lensDirection}');
      
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
        debugPrint('[CameraService] Created photos directory: ${photosDir.path}');
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
      debugPrint('[CameraService] Photo size: ${(fileSize / 1024).toStringAsFixed(1)} KB');

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
        debugPrint('[CameraService] Created photos directory: ${photosDir.path}');
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
          text: 'MarketSnap\nSimulator Photo\n${DateTime.now().toString().split('.')[0]}',
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
      final image = await picture.toImage(size.width.toInt(), size.height.toInt());
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final uint8List = byteData!.buffer.asUint8List();

      // Save to file
      final file = File(photoPath);
      await file.writeAsBytes(uint8List);

      final fileSize = await file.length();
      debugPrint('[CameraService] Simulator photo created successfully');
      debugPrint('[CameraService] Photo path: $photoPath');
      debugPrint('[CameraService] Photo size: ${(fileSize / 1024).toStringAsFixed(1)} KB');

      return photoPath;
    } catch (e) {
      _lastError = 'Failed to create simulator photo: $e';
      debugPrint('[CameraService] ERROR: $_lastError');
      return null;
    }
  }

  /// Get camera flash modes available for current camera
  List<FlashMode> getAvailableFlashModes() {
    if (_controller == null || !_controller!.value.isInitialized) {
      return [];
    }

    // Return common flash modes - the camera plugin handles availability
    return [
      FlashMode.off,
      FlashMode.auto,
      FlashMode.always,
    ];
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
      debugPrint('[CameraService] Zoom set to: $clampedZoom (min: $minZoom, max: $maxZoom)');
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
      return await _controller!.getMinZoomLevel();
    } catch (e) {
      debugPrint('[CameraService] Failed to get zoom level: $e');
      return 1.0;
    }
  }

  /// Dispose camera controller
  Future<void> disposeController() async {
    if (_controller != null) {
      debugPrint('[CameraService] Disposing camera controller...');
      try {
        await _controller!.dispose();
        debugPrint('[CameraService] Camera controller disposed successfully');
      } catch (e) {
        debugPrint('[CameraService] Error disposing camera controller: $e');
      }
      _controller = null;
    }
  }

  /// Dispose the entire camera service
  Future<void> dispose() async {
    debugPrint('[CameraService] Disposing camera service...');
    await disposeController();
    _cameras = null;
    _isInitialized = false;
    _lastError = null;
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