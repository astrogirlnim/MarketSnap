import 'dart:io';
import 'dart:typed_data';
import 'dart:developer' as developer;
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/pending_media.dart';
import 'hive_service.dart';
import '../../features/settings/application/settings_service.dart';

/// Service for saving media files to the device gallery
/// Implements Phase 4.4 Save-to-Device functionality with storage checks and permissions
class DeviceGallerySaveService {
  final HiveService _hiveService;
  final SettingsService _settingsService;

  DeviceGallerySaveService({
    required HiveService hiveService,
    required SettingsService settingsService,
  })  : _hiveService = hiveService,
        _settingsService = settingsService;

  /// Saves media to device gallery if enabled in settings and storage is sufficient
  /// Returns true if saved successfully, false if skipped or failed
  Future<bool> saveMediaToGalleryIfEnabled({
    required String filePath,
    required MediaType mediaType,
    String? caption,
  }) async {
    try {
      developer.log(
        '[DeviceGallerySaveService] 💾 Checking if should save media to gallery...',
        name: 'DeviceGallerySaveService',
      );

      // Step 1: Check if save-to-device is enabled in user settings
      final settings = _hiveService.getUserSettings();
      if (settings?.saveToDeviceDefault != true) {
        developer.log(
          '[DeviceGallerySaveService] ⏭️ Save-to-device disabled in settings, skipping gallery save',
          name: 'DeviceGallerySaveService',
        );
        return false;
      }

      developer.log(
        '[DeviceGallerySaveService] ✅ Save-to-device enabled in settings',
        name: 'DeviceGallerySaveService',
      );

      // Step 2: Check if device has sufficient storage (≥ 100 MB)
      final hasSufficientStorage = await _settingsService.hasSufficientStorage();
      if (!hasSufficientStorage) {
        developer.log(
          '[DeviceGallerySaveService] ⚠️ Insufficient storage (<100MB), skipping gallery save',
          name: 'DeviceGallerySaveService',
        );
        throw InsufficientStorageException(
          'Not enough storage space. At least 100MB required.',
        );
      }

      developer.log(
        '[DeviceGallerySaveService] ✅ Sufficient storage available',
        name: 'DeviceGallerySaveService',
      );

      // Step 3: Check if file exists
      final file = File(filePath);
      if (!await file.exists()) {
        developer.log(
          '[DeviceGallerySaveService] ❌ File not found: $filePath',
          name: 'DeviceGallerySaveService',
        );
        throw FileNotFoundException('Media file not found: $filePath');
      }

      developer.log(
        '[DeviceGallerySaveService] ✅ Media file exists: $filePath',
        name: 'DeviceGallerySaveService',
      );

      // Step 4: Request permissions
      final hasPermission = await _requestGalleryPermissions();
      if (!hasPermission) {
        developer.log(
          '[DeviceGallerySaveService] ❌ Gallery permissions denied',
          name: 'DeviceGallerySaveService',
        );
        throw GalleryPermissionException('Gallery permissions denied');
      }

      developer.log(
        '[DeviceGallerySaveService] ✅ Gallery permissions granted',
        name: 'DeviceGallerySaveService',
      );

      // Step 5: Save the media file to gallery
      final result = await _saveFileToGallery(
        filePath: filePath,
        mediaType: mediaType,
        caption: caption,
      );

      if (result) {
        developer.log(
          '[DeviceGallerySaveService] 🎉 Successfully saved media to gallery: $filePath',
          name: 'DeviceGallerySaveService',
        );
      } else {
        developer.log(
          '[DeviceGallerySaveService] ❌ Failed to save media to gallery: $filePath',
          name: 'DeviceGallerySaveService',
        );
      }

      return result;
    } catch (e) {
      developer.log(
        '[DeviceGallerySaveService] ❌ Error saving media to gallery: $e',
        name: 'DeviceGallerySaveService',
      );
      rethrow;
    }
  }

  /// Request necessary permissions for saving to gallery
  /// Returns true if permissions are granted
  Future<bool> _requestGalleryPermissions() async {
    try {
      developer.log(
        '[DeviceGallerySaveService] 🔐 Requesting gallery permissions...',
        name: 'DeviceGallerySaveService',
      );

      PermissionStatus status;

      if (Platform.isAndroid) {
        // Android: Request storage permissions
        // For Android 13+ (API 33+), we need different permissions
        if (Platform.version.contains('API 33') || 
            Platform.version.contains('API 34') ||
            Platform.version.contains('API 35')) {
          // Android 13+ uses granular media permissions
          status = await Permission.photos.request();
          developer.log(
            '[DeviceGallerySaveService] 📱 Android 13+ photos permission status: $status',
            name: 'DeviceGallerySaveService',
          );
        } else {
          // Android 12 and below uses storage permission
          status = await Permission.storage.request();
          developer.log(
            '[DeviceGallerySaveService] 📱 Android storage permission status: $status',
            name: 'DeviceGallerySaveService',
          );
        }
      } else if (Platform.isIOS) {
        // iOS: Request photo library add permissions
        status = await Permission.photosAddOnly.request();
        developer.log(
          '[DeviceGallerySaveService] 🍎 iOS photosAddOnly permission status: $status',
          name: 'DeviceGallerySaveService',
        );
      } else {
        developer.log(
          '[DeviceGallerySaveService] ⚠️ Unsupported platform: ${Platform.operatingSystem}',
          name: 'DeviceGallerySaveService',
        );
        return false;
      }

      final isGranted = status == PermissionStatus.granted;
      developer.log(
        '[DeviceGallerySaveService] 🔐 Permission granted: $isGranted',
        name: 'DeviceGallerySaveService',
      );

      return isGranted;
    } catch (e) {
      developer.log(
        '[DeviceGallerySaveService] ❌ Error requesting permissions: $e',
        name: 'DeviceGallerySaveService',
      );
      return false;
    }
  }

  /// Save the actual file to gallery using image_gallery_saver
  /// Returns true if successful
  Future<bool> _saveFileToGallery({
    required String filePath,
    required MediaType mediaType,
    String? caption,
  }) async {
    try {
      developer.log(
        '[DeviceGallerySaveService] 💾 Saving ${mediaType.name} to gallery: $filePath',
        name: 'DeviceGallerySaveService',
      );

      final file = File(filePath);
      final fileBytes = await file.readAsBytes();

      // Generate a meaningful name for the saved file
      final fileName = _generateFileName(mediaType, caption);

      dynamic result;

      if (mediaType == MediaType.photo) {
        // Save image to gallery
        result = await ImageGallerySaver.saveImage(
          Uint8List.fromList(fileBytes),
          quality: 85, // Good quality for photos
          name: fileName,
        );
      } else {
        // Save video to gallery
        result = await ImageGallerySaver.saveFile(
          filePath,
          name: fileName,
        );
      }

      developer.log(
        '[DeviceGallerySaveService] 📱 Gallery save result: $result',
        name: 'DeviceGallerySaveService',
      );

      // Check if the result indicates success
      if (result is Map && result.containsKey('isSuccess')) {
        final isSuccess = result['isSuccess'] as bool? ?? false;
        if (isSuccess) {
          developer.log(
            '[DeviceGallerySaveService] ✅ Media saved successfully with name: $fileName',
            name: 'DeviceGallerySaveService',
          );
          return true;
        } else {
          developer.log(
            '[DeviceGallerySaveService] ❌ Gallery save failed: ${result['errorMessage'] ?? 'Unknown error'}',
            name: 'DeviceGallerySaveService',
          );
          return false;
        }
      } else if (result != null) {
        // Some versions return the file path on success
        developer.log(
          '[DeviceGallerySaveService] ✅ Media saved successfully (path result)',
          name: 'DeviceGallerySaveService',
        );
        return true;
      } else {
        developer.log(
          '[DeviceGallerySaveService] ❌ Gallery save returned null result',
          name: 'DeviceGallerySaveService',
        );
        return false;
      }
    } catch (e) {
      developer.log(
        '[DeviceGallerySaveService] ❌ Error saving file to gallery: $e',
        name: 'DeviceGallerySaveService',
      );
      return false;
    }
  }

  /// Generate a meaningful filename for saved media
  String _generateFileName(MediaType mediaType, String? caption) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final prefix = mediaType == MediaType.photo ? 'MarketSnap_Photo' : 'MarketSnap_Video';
    final extension = mediaType == MediaType.photo ? 'jpg' : 'mp4';
    
    // Create a clean filename (replace special characters)
    String cleanCaption = '';
    if (caption != null && caption.isNotEmpty) {
      cleanCaption = caption
          .replaceAll(RegExp(r'[^\w\s-]'), '') // Remove special chars
          .replaceAll(RegExp(r'\s+'), '_') // Replace spaces with underscores
          .toLowerCase();
      if (cleanCaption.length > 20) {
        cleanCaption = cleanCaption.substring(0, 20);
      }
      cleanCaption = '_$cleanCaption';
    }
    
    return '${prefix}_$timestamp$cleanCaption.$extension';
  }

  /// Check if save-to-device is enabled in settings
  bool isSaveToDeviceEnabled() {
    final settings = _hiveService.getUserSettings();
    return settings?.saveToDeviceDefault ?? false;
  }

  /// Check if device has sufficient storage for saving media
  Future<bool> hasSufficientStorageForSave() async {
    return await _settingsService.hasSufficientStorage();
  }
}

/// Exception thrown when there is insufficient storage space
class InsufficientStorageException implements Exception {
  final String message;
  InsufficientStorageException(this.message);

  @override
  String toString() => 'InsufficientStorageException: $message';
}

/// Exception thrown when file is not found
class FileNotFoundException implements Exception {
  final String message;
  FileNotFoundException(this.message);

  @override
  String toString() => 'FileNotFoundException: $message';
}

/// Exception thrown when gallery permissions are denied
class GalleryPermissionException implements Exception {
  final String message;
  GalleryPermissionException(this.message);

  @override
  String toString() => 'GalleryPermissionException: $message';
} 