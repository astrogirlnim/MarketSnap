import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

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

  HiveService(this._secureStorageService);

  /// Initializes the Hive database.
  /// This must be called on app startup before using any Hive-related features.
  Future<void> init() async {
    debugPrint('[HiveService] Initializing Hive...');

    // 1. Initialize Hive with the app's document directory
    final appDocumentDir = await getApplicationDocumentsDirectory();
    await Hive.initFlutter(appDocumentDir.path);
    debugPrint('[HiveService] Hive initialized at ${appDocumentDir.path}');

    // 2. Register all necessary TypeAdapters
    _registerAdapters();

    // 3. Get encryption key
    final encryptionKey = await _secureStorageService.getHiveEncryptionKey();
    final cipher = HiveAesCipher(encryptionKey);
    debugPrint('[HiveService] Encryption key retrieved, cipher created.');

    try {
      // 4. Open encrypted boxes with error handling for corrupted data
      await _openBoxWithRecovery<PendingMediaItem>(
        pendingMediaQueueBoxName,
        cipher,
        (box) => pendingMediaQueueBox = box,
      );
      debugPrint('[HiveService] "$pendingMediaQueueBoxName" box opened.');

      await _openBoxWithRecovery<UserSettings>(
        userSettingsBoxName,
        cipher,
        (box) => userSettingsBox = box,
      );
      debugPrint('[HiveService] "$userSettingsBoxName" box opened.');

      await _openBoxWithRecovery<VendorProfile>(
        vendorProfileBoxName,
        cipher,
        (box) => vendorProfileBox = box,
      );
      debugPrint('[HiveService] "$vendorProfileBoxName" box opened.');

      // Ensure user settings has a default value if the box is new
      if (userSettingsBox.isEmpty) {
        debugPrint(
          '[HiveService] UserSettings box is empty. Seeding with default settings.',
        );
        await userSettingsBox.put('settings', UserSettings());
      }

      debugPrint('[HiveService] Hive initialization complete.');
    } catch (e) {
      debugPrint('[HiveService] Error during Hive initialization: $e');
      // If we still get errors after recovery attempts, we have a more serious issue
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

  void _registerAdapters() {
    debugPrint('[HiveService] Registering Hive type adapters...');

    // Only register adapters if they haven't been registered already
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(UserSettingsAdapter());
      debugPrint('[HiveService] UserSettingsAdapter registered with typeId: 0');
    }

    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(VendorProfileAdapter());
      debugPrint(
        '[HiveService] VendorProfileAdapter registered with typeId: 1',
      );
    }

    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(MediaTypeAdapter());
      debugPrint('[HiveService] MediaTypeAdapter registered with typeId: 2');
    }

    if (!Hive.isAdapterRegistered(3)) {
      Hive.registerAdapter(PendingMediaItemAdapter());
      debugPrint(
        '[HiveService] PendingMediaItemAdapter registered with typeId: 3',
      );
    }

    debugPrint('[HiveService] All adapters registered.');
  }

  /// Add a pending media item to the upload queue
  Future<void> addPendingMedia(PendingMediaItem item) async {
    debugPrint('[HiveService] Adding pending media item to queue: ${item.id}');
    await pendingMediaQueueBox.put(item.id, item);
    debugPrint('[HiveService] Pending media item added successfully');
  }

  /// Get all pending media items
  List<PendingMediaItem> getAllPendingMedia() {
    debugPrint('[HiveService] Retrieving all pending media items');
    final items = pendingMediaQueueBox.values.toList();
    debugPrint('[HiveService] Found ${items.length} pending media items');
    return items;
  }

  /// Remove a pending media item by ID
  Future<void> removePendingMedia(String id) async {
    debugPrint('[HiveService] Removing pending media item: $id');
    await pendingMediaQueueBox.delete(id);
    debugPrint('[HiveService] Pending media item removed successfully');
  }

  /// Get user settings
  UserSettings? getUserSettings() {
    debugPrint('[HiveService] Retrieving user settings');
    return userSettingsBox.get('settings');
  }

  /// Update user settings
  Future<void> updateUserSettings(UserSettings settings) async {
    debugPrint('[HiveService] Updating user settings');
    await userSettingsBox.put('settings', settings);
    debugPrint('[HiveService] User settings updated successfully');
  }

  /// Get vendor profile for the given UID
  VendorProfile? getVendorProfile(String uid) {
    debugPrint('[HiveService] Retrieving vendor profile for UID: $uid');
    final profile = vendorProfileBox.get(uid);
    if (profile != null) {
      debugPrint('[HiveService] Found vendor profile: ${profile.stallName}');
    } else {
      debugPrint('[HiveService] No vendor profile found for UID: $uid');
    }
    return profile;
  }

  /// Save or update vendor profile
  Future<void> saveVendorProfile(VendorProfile profile) async {
    debugPrint('[HiveService] Saving vendor profile for UID: ${profile.uid}');
    debugPrint(
      '[HiveService] Profile details: ${profile.stallName} in ${profile.marketCity}',
    );
    await vendorProfileBox.put(profile.uid, profile);
    debugPrint('[HiveService] Vendor profile saved successfully');
  }

  /// Get all vendor profiles that need syncing to Firestore
  List<VendorProfile> getProfilesNeedingSync() {
    debugPrint('[HiveService] Getting vendor profiles that need sync');
    final profiles = vendorProfileBox.values
        .where((profile) => profile.needsSync)
        .toList();
    debugPrint('[HiveService] Found ${profiles.length} profiles needing sync');
    return profiles;
  }

  /// Mark vendor profile as synced
  Future<void> markProfileAsSynced(String uid) async {
    debugPrint('[HiveService] Marking vendor profile as synced: $uid');
    final profile = vendorProfileBox.get(uid);
    if (profile != null) {
      final updatedProfile = profile.copyWith(needsSync: false);
      await vendorProfileBox.put(uid, updatedProfile);
      debugPrint('[HiveService] Profile marked as synced successfully');
    } else {
      debugPrint('[HiveService] Profile not found for UID: $uid');
    }
  }

  /// Delete vendor profile
  Future<void> deleteVendorProfile(String uid) async {
    debugPrint('[HiveService] Deleting vendor profile for UID: $uid');
    await vendorProfileBox.delete(uid);
    debugPrint('[HiveService] Vendor profile deleted successfully');
  }

  /// Check if vendor profile exists and is complete
  bool hasCompleteVendorProfile(String uid) {
    final profile = getVendorProfile(uid);
    return profile?.isComplete ?? false;
  }

  /// Closes all open Hive boxes.
  Future<void> close() async {
    debugPrint('[HiveService] Closing all Hive boxes.');
    await Hive.close();
  }
}
