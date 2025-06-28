import 'dart:io';
import 'dart:developer' as developer;
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';

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

      // Step 4: Check and request gallery permissions
      final hasPermission = await _checkGalleryPermissions();
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

  /// Check and request gallery permissions
  Future<bool> _checkGalleryPermissions() async {
    debugPrint('[DeviceGallerySaveService] 🔐 Checking gallery permissions...');
    debugPrint('[DeviceGallerySaveService] 📱 Platform: ${Platform.operatingSystem}');
    debugPrint('[DeviceGallerySaveService] 📱 Platform version: ${Platform.version}');
    
    Permission permission;
    if (Platform.isIOS) {
      // iOS: Use photos permission for adding to gallery
      permission = Permission.photos;
      debugPrint('[DeviceGallerySaveService] 🍎 iOS detected - using Permission.photos');
    } else {
      // Android: Use appropriate storage permission based on API level
      if (await _isAndroid13OrHigher()) {
        permission = Permission.photos; // Android 13+ granular permission
        debugPrint('[DeviceGallerySaveService] 🤖 Android 13+ detected - using Permission.photos');
      } else {
        permission = Permission.storage; // Legacy storage permission
        debugPrint('[DeviceGallerySaveService] 🤖 Android <13 detected - using Permission.storage');
      }
    }

    // Check current permission status
    debugPrint('[DeviceGallerySaveService] 🔍 Checking current permission status...');
    PermissionStatus status = await permission.status;
    debugPrint('[DeviceGallerySaveService] 📱 Current permission status: $status');
    debugPrint('[DeviceGallerySaveService] 📱 Is granted: ${status.isGranted}');
    debugPrint('[DeviceGallerySaveService] 📱 Is denied: ${status.isDenied}');
    debugPrint('[DeviceGallerySaveService] 📱 Is permanently denied: ${status.isPermanentlyDenied}');
    debugPrint('[DeviceGallerySaveService] 📱 Is restricted: ${status.isRestricted}');
    debugPrint('[DeviceGallerySaveService] 📱 Is limited: ${status.isLimited}');

    // If permission is denied, request it
    if (status.isDenied || status.isPermanentlyDenied) {
      debugPrint('[DeviceGallerySaveService] 🔐 Permission denied, requesting permission...');
      debugPrint('[DeviceGallerySaveService] 🔐 About to call permission.request()...');
      
      try {
        status = await permission.request();
        debugPrint('[DeviceGallerySaveService] 📱 Permission request completed');
        debugPrint('[DeviceGallerySaveService] 📱 New permission status: $status');
        debugPrint('[DeviceGallerySaveService] 📱 New status is granted: ${status.isGranted}');
      } catch (e) {
        debugPrint('[DeviceGallerySaveService] ❌ Error during permission request: $e');
        debugPrint('[DeviceGallerySaveService] ❌ Error type: ${e.runtimeType}');
        return false;
      }
    } else if (status.isGranted) {
      debugPrint('[DeviceGallerySaveService] ✅ Permission already granted');
    } else {
      debugPrint('[DeviceGallerySaveService] ⚠️ Permission status is neither denied nor granted: $status');
    }

    // Log platform-specific permission status
    if (Platform.isIOS) {
      debugPrint('[DeviceGallerySaveService] 🍎 Final iOS photos permission status: $status');
      debugPrint('[DeviceGallerySaveService] 🍎 iOS permission will appear in Settings: ${status.isGranted || status.isDenied || status.isPermanentlyDenied}');
    } else {
      debugPrint('[DeviceGallerySaveService] 🤖 Final Android storage permission status: $status');
    }

    final result = status.isGranted;
    debugPrint('[DeviceGallerySaveService] 🏁 Permission check result: $result');
    return result;
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

  /// Check if the device is running Android 13 or higher
  Future<bool> _isAndroid13OrHigher() async {
    if (Platform.isAndroid) {
      final version = Platform.version;
      return version.contains('API 33') || version.contains('API 34') || version.contains('API 35');
    }
    return false;
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