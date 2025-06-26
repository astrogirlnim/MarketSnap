import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

import '../models/pending_media.dart';
import '../models/user_settings.dart';
import '../models/vendor_profile.dart';
import 'secure_storage_service.dart';

/// Service responsible for initializing and managing the Hive local database.
class HiveService {
  final SecureStorageService _secureStorageService;

  // Making boxes public to be accessible from other services, but this could
  // be refactored to be private with public methods to interact with them
  // for better encapsulation.
  late final Box<PendingMediaItem> pendingMediaQueueBox;
  late final Box<UserSettings> userSettingsBox;
  late final Box<VendorProfile> vendorProfileBox;

  // Box names
  static const String pendingMediaQueueBoxName = 'pendingMediaQueue';
  static const String userSettingsBoxName = 'userSettings';
  static const String vendorProfileBoxName = 'vendorProfile';

  // Directory for quarantined media files
  static const String _pendingDirectoryName = 'pending_uploads';

  HiveService(this._secureStorageService);

  /// Initializes the Hive database.
  /// This must be called on app startup before using any Hive-related features.
  Future<void> init() async {
    await Hive.initFlutter();
    _registerAdapters();
    final cipher = await _getEncryptionCipher();
    await _openBoxes(cipher);
  }

  void _registerAdapters() {
    // Only register adapters if they haven't been registered already
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(UserSettingsAdapter());
    }

    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(VendorProfileAdapter());
    }

    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(MediaTypeAdapter());
    }

    if (!Hive.isAdapterRegistered(3)) {
      Hive.registerAdapter(PendingMediaItemAdapter());
    }
  }

  Future<HiveAesCipher> _getEncryptionCipher() async {
    final encryptionKey = await _secureStorageService.getHiveEncryptionKey();
    return HiveAesCipher(encryptionKey);
  }

  Future<void> _openBoxes(HiveAesCipher cipher) async {
    try {
      await _openBoxWithRecovery<PendingMediaItem>(
        pendingMediaQueueBoxName,
        cipher,
        (box) => pendingMediaQueueBox = box,
      );

      await _openBoxWithRecovery<UserSettings>(
        userSettingsBoxName,
        cipher,
        (box) => userSettingsBox = box,
      );

      await _openBoxWithRecovery<VendorProfile>(
        vendorProfileBoxName,
        cipher,
        (box) => vendorProfileBox = box,
      );

      // Ensure user settings has a default value if the box is new
      if (userSettingsBox.isEmpty) {
        await userSettingsBox.put('settings', UserSettings());
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Opens a Hive box with recovery mechanism for corrupted data
  Future<void> _openBoxWithRecovery<T>(
    String boxName,
    HiveAesCipher cipher,
    void Function(Box<T>) assignBox,
  ) async {
    try {
      final box = await Hive.openBox<T>(boxName, encryptionCipher: cipher);
      assignBox(box);
    } catch (e) {
      debugPrint('[HiveService] Error opening box "$boxName": $e');
      debugPrint(
        '[HiveService] Attempting to recover by deleting corrupted box "$boxName"',
      );

      try {
        // Close the corrupted box if it's partially open
        if (Hive.isBoxOpen(boxName)) {
          await Hive.box(boxName).close();
        }

        // Delete the corrupted box
        await Hive.deleteBoxFromDisk(boxName);
        debugPrint('[HiveService] Corrupted box "$boxName" deleted');

        // Try to open a fresh box
        final box = await Hive.openBox<T>(boxName, encryptionCipher: cipher);
        assignBox(box);
        debugPrint('[HiveService] Fresh box "$boxName" opened successfully');
      } catch (recoveryError) {
        debugPrint(
          '[HiveService] Failed to recover box "$boxName": $recoveryError',
        );
        rethrow;
      }
    }
  }

  /// Creates the directory for pending uploads if it doesn't exist.
  Future<String> _getPendingDirectoryPath() async {
    final tempDir = await getTemporaryDirectory();
    final pendingDir = Directory(
      path.join(tempDir.path, _pendingDirectoryName),
    );
    if (!await pendingDir.exists()) {
      await pendingDir.create(recursive: true);
      debugPrint(
        '[HiveService] Created pending uploads directory at: ${pendingDir.path}',
      );
    }
    return pendingDir.path;
  }

  /// Add a pending media item to the upload queue.
  /// This now MOVES the file to a dedicated 'pending' directory to prevent duplicates.
  Future<void> addPendingMedia(PendingMediaItem item) async {
    debugPrint('[HiveService] Adding pending media item to queue:');
    debugPrint('[HiveService] - ID: ${item.id}');
    debugPrint('[HiveService] - MediaType: ${item.mediaType}');
    debugPrint('[HiveService] - FilterType: "${item.filterType}"');
    debugPrint('[HiveService] - FilePath: ${item.filePath}');
    debugPrint('[HiveService] - Caption: ${item.caption}');
    
    try {
      final File originalFile = File(item.filePath);
      if (!await originalFile.exists()) {
        throw Exception('Source file does not exist: ${item.filePath}');
      }

      final pendingDir = await _getPendingDirectoryPath();
      final newPath = path.join(pendingDir, path.basename(item.filePath));

      // Move the file to the quarantined directory
      final File newFile = await originalFile.rename(newPath);

      // Create a new item with the updated path
      final quarantinedItem = PendingMediaItem(
        filePath: newFile.path,
        mediaType: item.mediaType,
        caption: item.caption,
        location: item.location,
        vendorId: item.vendorId,
        id: item.id,
        createdAt: item.createdAt,
      );

      // Use the ID from the new quarantined item as the key
      await pendingMediaQueueBox.put(quarantinedItem.id, quarantinedItem);

      // Verify the item was stored correctly
      final storedItem = pendingMediaQueueBox.get(quarantinedItem.id);
      debugPrint('[HiveService] Verification - stored item filterType: "${storedItem?.filterType}"');
      
      debugPrint('[HiveService] Added pending media item: ${quarantinedItem.id}');
    } catch (e) {
      rethrow;
    }
  }

  /// Retrieves a single pending media item by its key.
  PendingMediaItem? getPendingMedia(String key) {
    return pendingMediaQueueBox.get(key);
  }

  /// Retrieves all pending media items from the queue.
  List<PendingMediaItem> getAllPendingMedia() {
    return pendingMediaQueueBox.values.toList();
  }

  /// Removes a pending media item from the queue by its ID.
  Future<void> removePendingMedia(String id) async {
    await pendingMediaQueueBox.delete(id);
  }

  /// Get user settings
  UserSettings? getUserSettings() {
    return userSettingsBox.get('settings');
  }

  /// Update user settings
  Future<void> updateUserSettings(UserSettings settings) async {
    await userSettingsBox.put('settings', settings);
  }

  /// Get vendor profile for the given UID
  VendorProfile? getVendorProfile(String uid) {
    return vendorProfileBox.get(uid);
  }

  /// Save or update vendor profile
  Future<void> saveVendorProfile(VendorProfile profile) async {
    await vendorProfileBox.put(profile.uid, profile);
  }

  /// Get all vendor profiles that need syncing to Firestore
  List<VendorProfile> getProfilesNeedingSync() {
    return vendorProfileBox.values
        .where((profile) => profile.needsSync)
        .toList();
  }

  /// Mark vendor profile as synced
  Future<void> markProfileAsSynced(String uid) async {
    final profile = vendorProfileBox.get(uid);
    if (profile != null) {
      final updatedProfile = profile.copyWith(needsSync: false);
      await vendorProfileBox.put(uid, updatedProfile);
    }
  }

  /// Delete vendor profile
  Future<void> deleteVendorProfile(String uid) async {
    await vendorProfileBox.delete(uid);
  }

  /// Check if vendor profile exists and is complete
  bool hasCompleteVendorProfile(String uid) {
    final profile = getVendorProfile(uid);
    return profile?.isComplete ?? false;
  }

  /// Closes all open Hive boxes.
  Future<void> close() async {
    await Hive.close();
  }
}
