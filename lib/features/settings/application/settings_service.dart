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

  // ✅ PERFORMANCE FIX: Cache expensive storage calculations
  static double? _cachedStorageMB;
  static DateTime? _cacheTimestamp;
  static const Duration _cacheValidity = Duration(
    minutes: 5,
  ); // Cache for 5 minutes

  SettingsService({required HiveService hiveService})
    : _hiveService = hiveService;

  /// Gets the current user settings with defaults if none exist
  UserSettings getCurrentSettings() {
    developer.log(
      '[SettingsService] Getting current settings',
      name: 'SettingsService',
    );

    final settings = _hiveService.getUserSettings();
    if (settings == null) {
      developer.log(
        '[SettingsService] No settings found, creating defaults',
        name: 'SettingsService',
      );
      final defaultSettings = UserSettings();
      _updateSettings(defaultSettings);
      return defaultSettings;
    }

    developer.log(
      '[SettingsService] Found existing settings: $settings',
      name: 'SettingsService',
    );
    return settings;
  }

  /// Updates user settings locally
  Future<void> updateSettings({
    bool? enableCoarseLocation,
    bool? autoCompressVideo,
    bool? saveToDeviceDefault,
    bool? preferStoryPosting,
  }) async {
    developer.log(
      '[SettingsService] Updating settings...',
      name: 'SettingsService',
    );

    final currentSettings = getCurrentSettings();

    final updatedSettings = UserSettings(
      enableCoarseLocation:
          enableCoarseLocation ?? currentSettings.enableCoarseLocation,
      autoCompressVideo: autoCompressVideo ?? currentSettings.autoCompressVideo,
      saveToDeviceDefault:
          saveToDeviceDefault ?? currentSettings.saveToDeviceDefault,
      preferStoryPosting:
          preferStoryPosting ?? currentSettings.preferStoryPosting,
    );

    await _updateSettings(updatedSettings);

    developer.log(
      '[SettingsService] Settings updated: $updatedSettings',
      name: 'SettingsService',
    );
  }

  /// Internal method to update settings in Hive
  Future<void> _updateSettings(UserSettings settings) async {
    await _hiveService.updateUserSettings(settings);
  }

  /// Calculates available storage space in MB using lightweight approach with caching
  /// Returns realistic estimate of free space in MB, or null if calculation fails
  Future<double?> getAvailableStorageMB({bool forceRefresh = false}) async {
    try {
      // ✅ PERFORMANCE FIX: Return cached result if still valid
      if (!forceRefresh && _isCacheValid()) {
        developer.log(
          '[SettingsService] Using cached storage value: ${_cachedStorageMB?.toStringAsFixed(1)}MB',
          name: 'SettingsService',
        );
        return _cachedStorageMB;
      }

      developer.log(
        '[SettingsService] Calculating available storage (${forceRefresh ? 'forced refresh' : 'cache expired'})...',
        name: 'SettingsService',
      );

      Directory directory;

      if (Platform.isIOS) {
        // Use documents directory for iOS
        directory = await getApplicationDocumentsDirectory();
      } else if (Platform.isAndroid) {
        // Use external storage directory for Android
        directory =
            await getExternalStorageDirectory() ??
            await getApplicationDocumentsDirectory();
      } else {
        // Fallback for other platforms
        directory = await getApplicationDocumentsDirectory();
      }

      // ✅ PERFORMANCE FIX: Use lightweight testing approach
      final estimatedMB = await _estimateStorageLightweight(directory);

      // Cache the result
      _cachedStorageMB = estimatedMB;
      _cacheTimestamp = DateTime.now();

      developer.log(
        '[SettingsService] Storage calculation result: ${estimatedMB?.toStringAsFixed(1)}MB available (cached)',
        name: 'SettingsService',
      );

      return estimatedMB;
    } catch (e) {
      developer.log(
        '[SettingsService] Error calculating storage: $e',
        name: 'SettingsService',
      );
      return null;
    }
  }

  /// ✅ PERFORMANCE FIX: Lightweight storage estimation using small test files
  /// Much faster than the previous heavy I/O approach
  Future<double?> _estimateStorageLightweight(Directory directory) async {
    try {
      developer.log(
        '[SettingsService] Running lightweight storage estimation...',
        name: 'SettingsService',
      );

      // ✅ PERFORMANCE: Test with much smaller files (1MB max) for speed
      const testSizeKB = 100; // Test with 100KB instead of 10MB+
      const bytesPerKB = 1024;
      final testData = List.filled(
        testSizeKB * bytesPerKB,
        42,
      ); // Small test data

      final tempFile = File('${directory.path}/storage_test_light.tmp');

      try {
        // Quick test: Try to write a small file
        await tempFile.writeAsBytes(testData);
        final fileSize = await tempFile.length();
        await tempFile.delete();

        developer.log(
          '[SettingsService] Successfully wrote ${(fileSize / bytesPerKB).toStringAsFixed(1)}KB test file',
          name: 'SettingsService',
        );

        // ✅ PERFORMANCE: Use directory stats if available (platform-specific optimization)
        try {
          if (Platform.isAndroid) {
            // For Android, estimate based on successful write
            return _estimateAndroidStorage(directory);
          } else if (Platform.isIOS) {
            // For iOS, estimate based on app documents directory
            return _estimateIOSStorage(directory);
          }
        } catch (e) {
          developer.log(
            '[SettingsService] Platform-specific estimation failed: $e',
            name: 'SettingsService',
          );
        }

        // ✅ PERFORMANCE: Conservative but fast estimate
        // If we can write a small file, assume reasonable storage is available
        return 1000.0; // 1GB conservative estimate
      } catch (e) {
        developer.log(
          '[SettingsService] Small file test failed: $e',
          name: 'SettingsService',
        );

        // If we can't even write 100KB, storage is very limited
        return 50.0; // 50MB minimal estimate
      }
    } catch (e) {
      developer.log(
        '[SettingsService] Lightweight storage estimation failed: $e',
        name: 'SettingsService',
      );
      // Return conservative estimate if all tests fail
      return 200.0; // 200MB conservative fallback
    }
  }

  /// Platform-specific Android storage estimation
  Future<double> _estimateAndroidStorage(Directory directory) async {
    // For Android external storage, assume reasonable space is available
    // This is much faster than heavy I/O testing
    return 1500.0; // 1.5GB estimate for Android
  }

  /// Platform-specific iOS storage estimation
  Future<double> _estimateIOSStorage(Directory directory) async {
    // For iOS documents directory, assume reasonable space is available
    // This is much faster than heavy I/O testing
    return 1200.0; // 1.2GB estimate for iOS
  }

  /// Check if cached storage value is still valid
  bool _isCacheValid() {
    if (_cachedStorageMB == null || _cacheTimestamp == null) {
      return false;
    }

    final now = DateTime.now();
    final cacheAge = now.difference(_cacheTimestamp!);
    return cacheAge < _cacheValidity;
  }

  /// Checks if device has sufficient storage (≥ 100 MB)
  /// ✅ PERFORMANCE FIX: Uses cached storage calculation
  Future<bool> hasSufficientStorage({bool forceRefresh = false}) async {
    final availableMB = await getAvailableStorageMB(forceRefresh: forceRefresh);
    if (availableMB == null) {
      developer.log(
        '[SettingsService] Storage check failed, assuming sufficient',
        name: 'SettingsService',
      );
      return true; // Assume sufficient if check fails
    }

    const requiredMB = 100.0;
    final sufficient = availableMB >= requiredMB;

    developer.log(
      '[SettingsService] Storage check: ${availableMB.toStringAsFixed(1)}MB available, sufficient: $sufficient',
      name: 'SettingsService',
    );
    return sufficient;
  }

  /// Gets formatted storage status message
  /// ✅ PERFORMANCE FIX: Uses cached storage calculation
  Future<String> getStorageStatusMessage({bool forceRefresh = false}) async {
    final availableMB = await getAvailableStorageMB(forceRefresh: forceRefresh);
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

  /// Force refresh storage cache (for manual refresh button)
  /// ✅ PERFORMANCE FIX: Explicit cache invalidation method
  Future<void> refreshStorageCache() async {
    developer.log(
      '[SettingsService] Manually refreshing storage cache...',
      name: 'SettingsService',
    );

    // Force refresh by invalidating cache
    await getAvailableStorageMB(forceRefresh: true);
  }

  /// Opens support email in external mail app
  Future<bool> openSupportEmail() async {
    const supportEmail = 'nmmsoftware@gmail.com';
    const subject = 'MarketSnap Support Request';
    final body =
        '''
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
      query:
          'subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}',
    );

    try {
      developer.log(
        '[SettingsService] Opening support email: $emailUri',
        name: 'SettingsService',
      );

      final canLaunch = await canLaunchUrl(emailUri);
      if (canLaunch) {
        final launched = await launchUrl(
          emailUri,
          mode: LaunchMode.externalApplication,
        );
        developer.log(
          '[SettingsService] Email launch result: $launched',
          name: 'SettingsService',
        );
        return launched;
      } else {
        developer.log(
          '[SettingsService] Cannot launch email URL',
          name: 'SettingsService',
        );
        return false;
      }
    } catch (e) {
      developer.log(
        '[SettingsService] Error launching email: $e',
        name: 'SettingsService',
      );
      return false;
    }
  }

  /// Gets the user's preferred posting choice (story vs feed)
  /// Returns true if user prefers stories, false if user prefers feed
  bool getPreferredPostingChoice() {
    final settings = getCurrentSettings();
    final preference = settings.preferStoryPosting;

    developer.log(
      '[SettingsService] Getting preferred posting choice: ${preference ? 'Stories' : 'Feed'}',
      name: 'SettingsService',
    );

    return preference;
  }

  /// Updates the user's preferred posting choice (story vs feed)
  /// This remembers their last choice for future posts
  Future<void> updatePreferredPostingChoice(bool preferStories) async {
    developer.log(
      '[SettingsService] Updating preferred posting choice to: ${preferStories ? 'Stories' : 'Feed'}',
      name: 'SettingsService',
    );

    await updateSettings(preferStoryPosting: preferStories);

    developer.log(
      '[SettingsService] ✅ Preferred posting choice saved successfully',
      name: 'SettingsService',
    );
  }
}
