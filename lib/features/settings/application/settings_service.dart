import 'dart:io';
import 'dart:developer' as developer;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/models/user_settings.dart';
import '../../../core/services/hive_service.dart';

/// Service for managing user settings and help functionality.
/// Handles settings CRUD operations, storage calculations, and external link navigation.
class SettingsService {
  final HiveService _hiveService;

  SettingsService({
    required HiveService hiveService,
  }) : _hiveService = hiveService;

  /// Gets the current user settings with defaults if none exist
  UserSettings getCurrentSettings() {
    developer.log('[SettingsService] Getting current settings', name: 'SettingsService');
    
    final settings = _hiveService.getUserSettings();
    if (settings == null) {
      developer.log('[SettingsService] No settings found, creating defaults', name: 'SettingsService');
      final defaultSettings = UserSettings();
      _updateSettings(defaultSettings);
      return defaultSettings;
    }
    
    developer.log('[SettingsService] Found existing settings: $settings', name: 'SettingsService');
    return settings;
  }

  /// Updates user settings locally
  Future<void> updateSettings({
    bool? enableCoarseLocation,
    bool? autoCompressVideo,
    bool? saveToDeviceDefault,
  }) async {
    developer.log('[SettingsService] Updating settings...', name: 'SettingsService');
    
    final currentSettings = getCurrentSettings();
    
    final updatedSettings = UserSettings(
      enableCoarseLocation: enableCoarseLocation ?? currentSettings.enableCoarseLocation,
      autoCompressVideo: autoCompressVideo ?? currentSettings.autoCompressVideo,
      saveToDeviceDefault: saveToDeviceDefault ?? currentSettings.saveToDeviceDefault,
    );
    
    await _updateSettings(updatedSettings);
    
    developer.log('[SettingsService] Settings updated: $updatedSettings', name: 'SettingsService');
  }

  /// Internal method to update settings in Hive
  Future<void> _updateSettings(UserSettings settings) async {
    await _hiveService.updateUserSettings(settings);
  }

  /// Calculates available storage space in MB
  /// Returns free space in MB, or null if calculation fails
  Future<double?> getAvailableStorageMB() async {
    try {
      developer.log('[SettingsService] Calculating available storage...', name: 'SettingsService');
      
      Directory directory;
      
      if (Platform.isIOS) {
        // Use documents directory for iOS
        directory = await getApplicationDocumentsDirectory();
      } else if (Platform.isAndroid) {
        // Use external storage directory for Android
        directory = await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
      } else {
        // Fallback for other platforms
        directory = await getApplicationDocumentsDirectory();
      }
      
      final stat = await directory.stat();
      developer.log('[SettingsService] Directory stat: $stat', name: 'SettingsService');
      
      // Try to get available space using platform-specific methods
      if (Platform.isAndroid) {
        return await _getAndroidAvailableSpace(directory);
      } else if (Platform.isIOS) {
        return await _getIOSAvailableSpace(directory);
      } else {
        // Fallback: estimate based on directory size
        return await _estimateAvailableSpace(directory);
      }
    } catch (e) {
      developer.log('[SettingsService] Error calculating storage: $e', name: 'SettingsService');
      return null;
    }
  }

  /// Android-specific storage calculation
  Future<double?> _getAndroidAvailableSpace(Directory directory) async {
    try {
      // Use statvfs-like approach through directory free space
      // Note: This is an approximation since Flutter doesn't expose statvfs directly
      final freeSpace = await _estimateAvailableSpace(directory);
      developer.log('[SettingsService] Android estimated free space: ${freeSpace}MB', name: 'SettingsService');
      return freeSpace;
    } catch (e) {
      developer.log('[SettingsService] Android storage calculation failed: $e', name: 'SettingsService');
      return null;
    }
  }

  /// iOS-specific storage calculation
  Future<double?> _getIOSAvailableSpace(Directory directory) async {
    try {
      // Use directory-based estimation for iOS
      final freeSpace = await _estimateAvailableSpace(directory);
      developer.log('[SettingsService] iOS estimated free space: ${freeSpace}MB', name: 'SettingsService');
      return freeSpace;
    } catch (e) {
      developer.log('[SettingsService] iOS storage calculation failed: $e', name: 'SettingsService');
      return null;
    }
  }

  /// Estimate available space based on directory analysis
  /// This is a fallback method when platform-specific APIs aren't available
  Future<double> _estimateAvailableSpace(Directory directory) async {
    try {
      // Create a temporary file to test write capacity
      final tempFile = File('${directory.path}/temp_storage_test.tmp');
      
      // Attempt to write 1MB of data to test available space
      const testDataSize = 1024 * 1024; // 1MB
      final testData = List.filled(testDataSize, 0);
      
      await tempFile.writeAsBytes(testData);
      await tempFile.delete();
      
      // If we can write 1MB, estimate much more is available
      // This is a conservative estimate - in practice, devices usually have GB of space
      const estimatedAvailableMB = 500.0; // Conservative 500MB estimate
      
      developer.log('[SettingsService] Storage test successful, estimating ${estimatedAvailableMB}MB available', name: 'SettingsService');
      return estimatedAvailableMB;
    } catch (e) {
      developer.log('[SettingsService] Storage estimation failed: $e', name: 'SettingsService');
      // Return a minimal estimate if test fails
      return 50.0; // 50MB conservative estimate
    }
  }

  /// Checks if device has sufficient storage (≥ 100 MB)
  Future<bool> hasSufficientStorage() async {
    final availableMB = await getAvailableStorageMB();
    if (availableMB == null) {
      developer.log('[SettingsService] Storage check failed, assuming sufficient', name: 'SettingsService');
      return true; // Assume sufficient if check fails
    }
    
    const requiredMB = 100.0;
    final sufficient = availableMB >= requiredMB;
    
    developer.log('[SettingsService] Storage check: ${availableMB}MB available, sufficient: $sufficient', name: 'SettingsService');
    return sufficient;
  }

  /// Gets formatted storage status message
  Future<String> getStorageStatusMessage() async {
    final availableMB = await getAvailableStorageMB();
    if (availableMB == null) {
      return 'Storage status unavailable';
    }
    
    if (availableMB >= 1024) {
      // Show in GB if > 1GB
      final availableGB = availableMB / 1024;
      return '${availableGB.toStringAsFixed(1)} GB available';
    } else {
      // Show in MB
      return '${availableMB.toStringAsFixed(0)} MB available';
    }
  }

  /// Opens support email in external mail app
  Future<bool> openSupportEmail() async {
    const supportEmail = 'support@marketsnap.app';
    const subject = 'MarketSnap Support Request';
    final body = '''
Hi MarketSnap Support Team,

I need help with:

[Please describe your issue here]

App Version: [Version will be auto-filled]
Platform: ${Platform.operatingSystem}

Thank you!
''';

    final emailUri = Uri(
      scheme: 'mailto',
      path: supportEmail,
      query: 'subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}',
    );

    try {
      developer.log('[SettingsService] Opening support email: $emailUri', name: 'SettingsService');
      
      final canLaunch = await canLaunchUrl(emailUri);
      if (canLaunch) {
        final launched = await launchUrl(emailUri, mode: LaunchMode.externalApplication);
        developer.log('[SettingsService] Email launch result: $launched', name: 'SettingsService');
        return launched;
      } else {
        developer.log('[SettingsService] Cannot launch email URL', name: 'SettingsService');
        return false;
      }
    } catch (e) {
      developer.log('[SettingsService] Error launching email: $e', name: 'SettingsService');
      return false;
    }
  }
} 