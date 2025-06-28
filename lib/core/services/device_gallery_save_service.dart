import 'dart:io';
import 'dart:developer' as developer;
import 'package:gal/gal.dart';

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
  }) : _hiveService = hiveService,
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
      final hasSufficientStorage = await _settingsService
          .hasSufficientStorage();
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

  /// Check and request gallery permissions using gal package
  Future<bool> _checkGalleryPermissions() async {
    developer.log(
      '[DeviceGallerySaveService] 🔐 Checking gallery permissions using gal package...',
      name: 'DeviceGallerySaveService',
    );

    try {
      // Use gal package's built-in permission checking
      final hasAccess = await Gal.hasAccess();

      developer.log(
        '[DeviceGallerySaveService] 📱 Current gallery access status: $hasAccess',
        name: 'DeviceGallerySaveService',
      );

      if (!hasAccess) {
        developer.log(
          '[DeviceGallerySaveService] 🔐 Gallery access denied, requesting permission...',
          name: 'DeviceGallerySaveService',
        );

        // Request access using gal package
        final granted = await Gal.requestAccess();

        developer.log(
          '[DeviceGallerySaveService] 📱 Permission request result: $granted',
          name: 'DeviceGallerySaveService',
        );

        return granted;
      } else {
        developer.log(
          '[DeviceGallerySaveService] ✅ Gallery access already granted',
          name: 'DeviceGallerySaveService',
        );
        return true;
      }
    } catch (e) {
      developer.log(
        '[DeviceGallerySaveService] ❌ Error checking gallery permissions: $e',
        name: 'DeviceGallerySaveService',
      );
      return false;
    }
  }

  /// Save the actual file to gallery using gal package
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
      if (!await file.exists()) {
        developer.log(
          '[DeviceGallerySaveService] ❌ File does not exist: $filePath',
          name: 'DeviceGallerySaveService',
        );
        return false;
      }

      // Log file details
      final fileSize = await file.length();
      developer.log(
        '[DeviceGallerySaveService] 📁 File exists - size: $fileSize bytes',
        name: 'DeviceGallerySaveService',
      );

      try {
        if (mediaType == MediaType.photo) {
          // Save image to gallery using gal package
          developer.log(
            '[DeviceGallerySaveService] 📷 Calling Gal.putImage() for: $filePath',
            name: 'DeviceGallerySaveService',
          );
          await Gal.putImage(filePath);
          developer.log(
            '[DeviceGallerySaveService] ✅ Gal.putImage() completed successfully',
            name: 'DeviceGallerySaveService',
          );
        } else {
          // Save video to gallery using gal package
          developer.log(
            '[DeviceGallerySaveService] 🎥 Calling Gal.putVideo() for: $filePath',
            name: 'DeviceGallerySaveService',
          );
          await Gal.putVideo(filePath);
          developer.log(
            '[DeviceGallerySaveService] ✅ Gal.putVideo() completed successfully',
            name: 'DeviceGallerySaveService',
          );
        }

        developer.log(
          '[DeviceGallerySaveService] ✅ Media saved successfully to gallery',
          name: 'DeviceGallerySaveService',
        );
        return true;
      } on GalException catch (galError) {
        developer.log(
          '[DeviceGallerySaveService] ❌ Gal package error: ${galError.type.message}',
          name: 'DeviceGallerySaveService',
        );

        // Handle specific gal errors
        switch (galError.type) {
          case GalExceptionType.accessDenied:
            developer.log(
              '[DeviceGallerySaveService] ❌ Access denied error from Gal package',
              name: 'DeviceGallerySaveService',
            );
            throw GalleryPermissionException('Gallery access denied');
          case GalExceptionType.notEnoughSpace:
            developer.log(
              '[DeviceGallerySaveService] ❌ Not enough space error from Gal package',
              name: 'DeviceGallerySaveService',
            );
            throw InsufficientStorageException('Not enough storage space');
          case GalExceptionType.notSupportedFormat:
            developer.log(
              '[DeviceGallerySaveService] ❌ Unsupported file format for gallery save',
              name: 'DeviceGallerySaveService',
            );
            return false;
          case GalExceptionType.unexpected:
            developer.log(
              '[DeviceGallerySaveService] ❌ Unexpected error during gallery save',
              name: 'DeviceGallerySaveService',
            );
            return false;
        }
      }
    } catch (e) {
      developer.log(
        '[DeviceGallerySaveService] ❌ Error saving file to gallery: $e',
        name: 'DeviceGallerySaveService',
      );
      return false;
    }
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
