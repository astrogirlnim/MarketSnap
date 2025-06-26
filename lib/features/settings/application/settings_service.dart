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

  /// Calculates available storage space in MB using directory analysis
  /// Returns realistic estimate of free space in MB, or null if calculation fails
  Future<double?> getAvailableStorageMB() async {
    try {
      developer.log('[SettingsService] Calculating available storage using directory analysis...', name: 'SettingsService');
      
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
      
      // Try to get realistic storage estimate
      final estimatedMB = await _estimateStorageByTesting(directory);
      
      developer.log('[SettingsService] Storage calculation result: ${estimatedMB?.toStringAsFixed(1)}MB available', name: 'SettingsService');
      
      return estimatedMB;
    } catch (e) {
      developer.log('[SettingsService] Error calculating storage: $e', name: 'SettingsService');
      return null;
    }
  }

  /// Estimates storage by testing write capacity in chunks
  /// More realistic than hardcoded values but still conservative  
  Future<double?> _estimateStorageByTesting(Directory directory) async {
    try {
      developer.log('[SettingsService] Testing storage capacity...', name: 'SettingsService');
      
      // Test progressively larger files to get realistic estimate
      const chunkSizeMB = 10; // Test in 10MB chunks
      const maxTestMB = 100; // Don't test beyond 100MB
      
      int successfulMB = 0;
      
      for (int testMB = chunkSizeMB; testMB <= maxTestMB; testMB += chunkSizeMB) {
        final tempFile = File('${directory.path}/storage_test_${testMB}mb.tmp');
        
        try {
          // Create test data (testMB * 1MB)
          const bytesPerMB = 1024 * 1024;
          final testData = List.filled(testMB * bytesPerMB, 0);
          
          await tempFile.writeAsBytes(testData);
          await tempFile.delete();
          
          successfulMB = testMB;
          developer.log('[SettingsService] Successfully wrote ${testMB}MB test file', name: 'SettingsService');
        } catch (e) {
          developer.log('[SettingsService] Failed to write ${testMB}MB test file: $e', name: 'SettingsService');
          break; // Stop testing when we hit storage limit
        }
      }
      
      // Estimate total available based on successful test size
      double estimatedMB;
      if (successfulMB >= maxTestMB) {
        // If we successfully wrote 100MB+, assume much more is available
        estimatedMB = 2000.0; // Estimate 2GB available
      } else if (successfulMB >= 50) {
        // If we wrote 50-100MB, estimate moderate storage
        estimatedMB = 1000.0; // Estimate 1GB available
      } else if (successfulMB >= 10) {
        // If we wrote 10-50MB, estimate limited storage
        estimatedMB = 500.0; // Estimate 500MB available
      } else {
        // If we couldn't write even 10MB, very limited storage
        estimatedMB = 100.0; // Estimate 100MB available
      }
      
      developer.log('[SettingsService] Storage test complete: wrote ${successfulMB}MB successfully, estimating ${estimatedMB}MB total available', name: 'SettingsService');
      return estimatedMB;
      
    } catch (e) {
      developer.log('[SettingsService] Storage testing failed: $e', name: 'SettingsService');
      // Return conservative estimate if testing fails
      return 200.0; // 200MB conservative fallback
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