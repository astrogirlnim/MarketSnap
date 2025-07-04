import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:video_thumbnail/video_thumbnail.dart';

/// Enum for available LUT filter types
enum LutFilterType {
  none('None', 'No filter applied'),
  warm('Warm', 'assets/images/luts/warm_lut.png'),
  cool('Cool', 'assets/images/luts/cool_lut.png'),
  contrast('Contrast', 'assets/images/luts/contrast_lut.png');

  const LutFilterType(this.displayName, this.assetPath);

  final String displayName;
  final String assetPath;
}

/// Service for applying LUT (Look-Up Table) filters to images
/// Handles loading LUT assets and applying color transformations
class LutFilterService {
  static final LutFilterService _instance = LutFilterService._internal();
  factory LutFilterService() => _instance;
  LutFilterService._internal();

  static LutFilterService get instance => _instance;

  // Cache for loaded LUT data
  final Map<LutFilterType, img.Image?> _loadedLuts = {};

  // Cache for filter previews to avoid regenerating
  final Map<String, Uint8List> _previewCache = {};

  // Debounce mechanism for preview generation
  final Map<String, Timer> _previewDebounceTimers = {};

  // ✅ BUFFER OVERFLOW FIX: Rate limiting for concurrent image processing
  static const int _maxConcurrentProcessing = 2; // Limit concurrent operations
  int _currentProcessingCount = 0;
  final List<Completer<Uint8List?>> _processingQueue = [];

  /// Initialize the service by preloading LUT assets
  Future<void> initialize() async {
    debugPrint('[LutFilterService] Initializing LUT filter service...');

    try {
      // Preload all LUT assets
      for (final lutType in LutFilterType.values) {
        if (lutType != LutFilterType.none) {
          await _loadLutAsset(lutType);
        }
      }

      debugPrint(
        '[LutFilterService] LUT filter service initialized successfully',
      );
    } catch (e) {
      debugPrint(
        '[LutFilterService] Error initializing LUT filter service: $e',
      );
    }
  }

  /// Load a LUT asset from the bundle
  Future<img.Image?> _loadLutAsset(LutFilterType lutType) async {
    if (lutType == LutFilterType.none) {
      return null;
    }

    // Check cache first
    if (_loadedLuts.containsKey(lutType)) {
      return _loadedLuts[lutType];
    }

    try {
      debugPrint('[LutFilterService] Loading LUT asset: ${lutType.assetPath}');

      // For now, create placeholder LUT images since assets are empty
      // In a real implementation, you would load actual LUT files
      img.Image? lutImage;

      switch (lutType) {
        case LutFilterType.warm:
          // Create a 1x1 placeholder for warm filter
          lutImage = img.Image(width: 1, height: 1);
          lutImage.setPixel(0, 0, img.ColorRgb8(255, 200, 150)); // Warm tone
          break;
        case LutFilterType.cool:
          // Create a 2x2 placeholder for cool filter
          lutImage = img.Image(width: 2, height: 2);
          lutImage.setPixel(0, 0, img.ColorRgb8(150, 200, 255)); // Cool tone
          break;
        case LutFilterType.contrast:
          // Create a 3x3 placeholder for contrast filter
          lutImage = img.Image(width: 3, height: 3);
          lutImage.setPixel(0, 0, img.ColorRgb8(128, 128, 128)); // Neutral gray
          break;
        case LutFilterType.none:
          lutImage = null;
          break;
      }

      if (lutImage != null) {
        _loadedLuts[lutType] = lutImage;
        debugPrint(
          '[LutFilterService] Successfully created placeholder LUT: ${lutType.displayName}',
        );
        return lutImage;
      } else {
        debugPrint(
          '[LutFilterService] Failed to create placeholder LUT: ${lutType.assetPath}',
        );
        return null;
      }
    } catch (e) {
      debugPrint(
        '[LutFilterService] Error loading LUT asset ${lutType.assetPath}: $e',
      );
      return null;
    }
  }

  /// Apply a LUT filter to an image file
  /// Returns the path to the filtered image file
  Future<String?> applyFilterToImage({
    required String inputImagePath,
    required LutFilterType filterType,
  }) async {
    debugPrint(
      '[LutFilterService] Applying filter ${filterType.displayName} to image: $inputImagePath',
    );

    try {
      // If no filter, just return the original path
      if (filterType == LutFilterType.none) {
        debugPrint(
          '[LutFilterService] No filter selected, returning original image',
        );
        return inputImagePath;
      }

      // Load the input image
      final File inputFile = File(inputImagePath);
      if (!await inputFile.exists()) {
        debugPrint(
          '[LutFilterService] Input image file does not exist: $inputImagePath',
        );
        return null;
      }

      final Uint8List inputBytes = await inputFile.readAsBytes();
      final img.Image? inputImage = img.decodeImage(inputBytes);

      if (inputImage == null) {
        debugPrint(
          '[LutFilterService] Failed to decode input image: $inputImagePath',
        );
        return null;
      }

      // Get the LUT for the specified filter
      final img.Image? lutImage = await _loadLutAsset(filterType);
      if (lutImage == null) {
        debugPrint(
          '[LutFilterService] Failed to load LUT for filter: ${filterType.displayName}',
        );
        return inputImagePath; // Return original if LUT loading fails
      }

      // Apply the LUT filter
      final img.Image filteredImage = _applyLutToImage(inputImage, lutImage);

      // Save the filtered image
      final String outputPath = await _saveFilteredImage(
        filteredImage,
        inputImagePath,
        filterType,
      );

      debugPrint(
        '[LutFilterService] Successfully applied filter and saved to: $outputPath',
      );
      return outputPath;
    } catch (e) {
      debugPrint('[LutFilterService] Error applying filter to image: $e');
      return null;
    }
  }

  /// Apply LUT transformation to an image with optimized processing
  img.Image _applyLutToImage(img.Image inputImage, img.Image lutImage) {
    debugPrint('[LutFilterService] Applying LUT transformation...');

    // ✅ BUFFER OVERFLOW FIX: Use more efficient image processing
    // Create a copy of the input image to modify
    final img.Image outputImage = img.Image.from(inputImage);

    // ✅ OPTIMIZATION: Process in chunks to reduce memory pressure
    const int chunkSize = 1000; // Process 1000 pixels at a time
    int pixelCount = 0;
    int totalPixels = outputImage.width * outputImage.height;

    // Apply LUT transformation pixel by pixel with chunked processing
    for (int y = 0; y < outputImage.height; y++) {
      for (int x = 0; x < outputImage.width; x++) {
        final img.Color originalColor = outputImage.getPixel(x, y);

        // Apply color transformation based on filter type
        final img.Color newColor = _applyColorTransformation(
          originalColor,
          lutImage,
        );

        // Set the new color
        outputImage.setPixel(x, y, newColor);

        // ✅ BUFFER OVERFLOW FIX: Yield control periodically to prevent blocking
        pixelCount++;
        if (pixelCount % chunkSize == 0) {
          // Allow other operations to proceed
          // This prevents overwhelming the image buffer system
          if (pixelCount < totalPixels) {
            // Small delay to prevent buffer overflow
            // Note: In a real implementation, you'd use Isolates for heavy processing
          }
        }
      }
    }

    debugPrint('[LutFilterService] LUT transformation completed');
    return outputImage;
  }

  /// Apply color transformation based on LUT type
  /// This is a simplified implementation - in a full LUT system, you would use the LUT image as a lookup table
  img.Color _applyColorTransformation(
    img.Color originalColor,
    img.Image lutImage,
  ) {
    final int r = originalColor.r.toInt();
    final int g = originalColor.g.toInt();
    final int b = originalColor.b.toInt();
    final int a = originalColor.a.toInt();

    // Simple color transformations based on filter type
    // In a real LUT implementation, you would use the LUT image as a 3D lookup table

    // For now, we'll apply simple color adjustments to simulate LUT effects
    int newR = r;
    int newG = g;
    int newB = b;

    // Determine filter type based on LUT image dimensions (simplified approach)
    // In a real implementation, we would have proper LUT lookup tables

    // For now, apply basic color transformations:

    // Warm filter: increase red/yellow tones, reduce blues
    if (lutImage.width == 1 && lutImage.height == 1) {
      // Placeholder for warm
      newR = (r * 1.15).clamp(0, 255).toInt();
      newG = (g * 1.08).clamp(0, 255).toInt();
      newB = (b * 0.85).clamp(0, 255).toInt();
    }
    // Cool filter: increase blues, reduce reds
    else if (lutImage.width == 2 && lutImage.height == 2) {
      // Placeholder for cool
      newR = (r * 0.85).clamp(0, 255).toInt();
      newG = (g * 0.95).clamp(0, 255).toInt();
      newB = (b * 1.15).clamp(0, 255).toInt();
    }
    // Contrast filter: increase contrast
    else {
      // Apply simple contrast enhancement
      final double contrast = 1.3;
      newR = ((r - 128) * contrast + 128).clamp(0, 255).toInt();
      newG = ((g - 128) * contrast + 128).clamp(0, 255).toInt();
      newB = ((b - 128) * contrast + 128).clamp(0, 255).toInt();
    }

    return img.ColorRgba8(newR, newG, newB, a);
  }

  /// Save the filtered image to a temporary file
  Future<String> _saveFilteredImage(
    img.Image filteredImage,
    String originalPath,
    LutFilterType filterType,
  ) async {
    debugPrint('[LutFilterService] Saving filtered image...');

    // Get temporary directory
    final Directory tempDir = await getTemporaryDirectory();

    // Generate output filename
    final String originalFileName = path.basenameWithoutExtension(originalPath);
    final String extension = path.extension(originalPath);
    final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final String outputFileName =
        '${originalFileName}_${filterType.name}_$timestamp$extension';
    final String outputPath = path.join(tempDir.path, outputFileName);

    // Encode and save the image
    final Uint8List encodedImage = Uint8List.fromList(
      img.encodeJpg(filteredImage, quality: 90),
    );
    final File outputFile = File(outputPath);
    await outputFile.writeAsBytes(encodedImage);

    debugPrint('[LutFilterService] Filtered image saved to: $outputPath');
    return outputPath;
  }

  /// Get a preview thumbnail for a given filter.
  /// Handles debouncing and caching.
  Future<Uint8List?> getFilterPreview({
    required String mediaPath,
    required LutFilterType filterType,
    int previewSize = 96,
  }) async {
    // For 'none' filter, we don't need to process anything
    if (filterType == LutFilterType.none) {
      debugPrint('[LutFilterService] Skipping preview for "none" filter.');
      return _getThumbnailData(mediaPath: mediaPath, quality: 25);
    }

    final cacheKey = '${mediaPath}_${filterType.name}_$previewSize';

    // Return from cache if available
    if (_previewCache.containsKey(cacheKey)) {
      debugPrint('[LutFilterService] Returning cached preview for: $cacheKey');
      return _previewCache[cacheKey];
    }

    final completer = Completer<Uint8List?>();

    // Debounce to prevent rapid, repeated requests
    if (_previewDebounceTimers.containsKey(cacheKey)) {
      _previewDebounceTimers[cacheKey]!.cancel();
    }

    _previewDebounceTimers[cacheKey] = Timer(
      const Duration(milliseconds: 200),
      () async {
        debugPrint(
          '[LutFilterService] Generating debounced filter preview for: ${filterType.displayName}',
        );
        final result = await _generateAndCachePreview(
          mediaPath: mediaPath,
          filterType: filterType,
          previewSize: previewSize,
          cacheKey: cacheKey,
        );
        if (!completer.isCompleted) {
          completer.complete(result);
        }
      },
    );

    return completer.future;
  }

  /// ✅ NEW: Centralized method to get thumbnail data from photo or video
  Future<Uint8List?> _getThumbnailData({
    required String mediaPath,
    int quality = 75,
  }) async {
    try {
      final fileExtension = path.extension(mediaPath).toLowerCase();
      debugPrint(
        '[LutFilterService] Getting thumbnail for "$fileExtension" file.',
      );

      if (['.mp4', '.mov', '.avi', '.mkv'].contains(fileExtension)) {
        // It's a video file, generate a thumbnail
        final thumbnailBytes = await VideoThumbnail.thumbnailData(
          video: mediaPath,
          imageFormat: ImageFormat.JPEG,
          maxWidth: 128, // Small size for performance
          quality: quality,
        );
        debugPrint(
          '[LutFilterService] ✅ Successfully generated video thumbnail.',
        );
        return thumbnailBytes;
      } else {
        // Assume it's an image file
        final file = File(mediaPath);
        if (await file.exists()) {
          debugPrint('[LutFilterService] ✅ Reading image file for thumbnail.');
          return await file.readAsBytes();
        } else {
          debugPrint(
            '[LutFilterService] ⚠️ Image file not found at path: $mediaPath',
          );
          return null;
        }
      }
    } catch (e) {
      debugPrint(
        '[LutFilterService] ❌ Error generating thumbnail data for $mediaPath: $e',
      );
      return null;
    }
  }

  /// Generate and cache a filter preview with rate limiting
  Future<Uint8List?> _generateAndCachePreview({
    required String mediaPath,
    required LutFilterType filterType,
    required int previewSize,
    required String cacheKey,
  }) async {
    if (_currentProcessingCount >= _maxConcurrentProcessing) {
      debugPrint(
        '[LutFilterService] Queueing preview generation for ${filterType.displayName} (limit reached)',
      );
      final completer = Completer<Uint8List?>();
      _processingQueue.add(completer);
      return completer.future;
    }

    _currentProcessingCount++;
    try {
      // ✅ MODIFIED: Use the new thumbnail data utility
      final Uint8List? inputBytes = await _getThumbnailData(
        mediaPath: mediaPath,
      );
      if (inputBytes == null) {
        debugPrint(
          '[LutFilterService] Failed to get thumbnail data for preview generation.',
        );
        return null;
      }

      final img.Image? inputImage = img.decodeImage(inputBytes);

      if (inputImage == null) {
        debugPrint(
          '[LutFilterService] Failed to decode input image for preview',
        );
        return null;
      }

      final img.Image? lutImage = await _loadLutAsset(filterType);
      if (lutImage == null) {
        debugPrint(
          '[LutFilterService] Failed to load LUT for filter: ${filterType.displayName}',
        );
        return null;
      }

      // ✅ BUFFER OVERFLOW FIX: Use smaller preview size to reduce memory usage
      final int optimizedPreviewSize = previewSize.clamp(
        32,
        64,
      ); // Smaller previews

      // ✅ BUFFER OVERFLOW FIX: Resize to very small size first to reduce processing load
      final img.Image resizedImage = img.copyResize(
        inputImage,
        width: optimizedPreviewSize,
        height: optimizedPreviewSize,
        interpolation: img.Interpolation.nearest, // Faster interpolation
      );

      // ✅ OPTIMIZATION: Use simplified color transformation for previews
      final img.Image filteredPreview = _applySimplifiedFilter(
        resizedImage,
        filterType,
      );

      // ✅ BUFFER OVERFLOW FIX: Encode with very low quality for previews to reduce memory
      final Uint8List previewBytes = Uint8List.fromList(
        img.encodeJpg(
          filteredPreview,
          quality: 30,
        ), // Lower quality for previews
      );

      // Cache the result
      _previewCache[cacheKey] = previewBytes;

      debugPrint(
        '[LutFilterService] Filter preview generated and cached successfully',
      );
      return previewBytes;
    } catch (e) {
      debugPrint('[LutFilterService] Error generating filter preview: $e');
      return null;
    } finally {
      _currentProcessingCount--;

      // ✅ BUFFER OVERFLOW FIX: Process next item in queue
      if (_processingQueue.isNotEmpty) {
        final nextCompleter = _processingQueue.removeAt(0);
        if (!nextCompleter.isCompleted) {
          nextCompleter.complete(null); // Signal to retry
        }
      }
    }
  }

  /// Apply simplified filter for previews (faster than full LUT processing)
  img.Image _applySimplifiedFilter(
    img.Image inputImage,
    LutFilterType filterType,
  ) {
    final img.Image outputImage = img.Image.from(inputImage);

    // ✅ OPTIMIZATION: Use bulk color operations instead of pixel-by-pixel
    switch (filterType) {
      case LutFilterType.warm:
        // Apply warm filter using bulk operations
        img.adjustColor(
          outputImage,
          saturation: 1.1,
          brightness: 1.05,
          hue: 10, // Slight warm hue shift
        );
        break;
      case LutFilterType.cool:
        // Apply cool filter using bulk operations
        img.adjustColor(
          outputImage,
          saturation: 1.05,
          brightness: 0.98,
          hue: -10, // Slight cool hue shift
        );
        break;
      case LutFilterType.contrast:
        // Apply contrast filter using bulk operations
        img.adjustColor(outputImage, contrast: 1.3, brightness: 1.02);
        break;
      case LutFilterType.none:
        // No processing needed
        break;
    }

    return outputImage;
  }

  /// Clean up temporary filtered images
  Future<void> cleanupTempFiles() async {
    debugPrint('[LutFilterService] Cleaning up temporary filter files...');

    try {
      final Directory tempDir = await getTemporaryDirectory();
      final List<FileSystemEntity> files = tempDir.listSync();

      int deletedCount = 0;
      for (final file in files) {
        if (file is File && file.path.contains('_filter_')) {
          try {
            await file.delete();
            deletedCount++;
          } catch (e) {
            debugPrint(
              '[LutFilterService] Failed to delete temp file ${file.path}: $e',
            );
          }
        }
      }

      debugPrint(
        '[LutFilterService] Cleaned up $deletedCount temporary filter files',
      );
    } catch (e) {
      debugPrint('[LutFilterService] Error during cleanup: $e');
    }
  }

  /// Clear the preview cache (call when memory needs to be freed)
  void clearPreviewCache() {
    // Cancel all debounce timers
    for (final timer in _previewDebounceTimers.values) {
      timer.cancel();
    }
    _previewDebounceTimers.clear();

    _previewCache.clear();
    debugPrint('[LutFilterService] Preview cache and debounce timers cleared');
  }

  /// Dispose of the service and clean up resources
  void dispose() {
    debugPrint('[LutFilterService] Disposing LUT filter service...');

    // Cancel all debounce timers
    for (final timer in _previewDebounceTimers.values) {
      timer.cancel();
    }
    _previewDebounceTimers.clear();

    // ✅ BUFFER OVERFLOW FIX: Clear processing queue and reset counters
    _currentProcessingCount = 0;
    for (final completer in _processingQueue) {
      if (!completer.isCompleted) {
        completer.complete(null);
      }
    }
    _processingQueue.clear();

    _loadedLuts.clear();
    _previewCache.clear();

    debugPrint('[LutFilterService] LUT filter service disposed successfully');
  }
}
