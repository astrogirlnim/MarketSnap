import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

import '../models/pending_media.dart';
import '../models/user_settings.dart';
import 'secure_storage_service.dart';

/// Service responsible for initializing and managing the Hive local database.
class HiveService {
  final SecureStorageService _secureStorageService;

  // Making boxes public to be accessible from other services, but this could
  // be refactored to be private with public methods to interact with them
  // for better encapsulation.
  late final Box<PendingMediaItem> pendingMediaQueueBox;
  late final Box<UserSettings> userSettingsBox;

  // Box names
  static const String pendingMediaQueueBoxName = 'pendingMediaQueue';
  static const String userSettingsBoxName = 'userSettings';

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

    // 4. Open encrypted boxes
    pendingMediaQueueBox = await Hive.openBox<PendingMediaItem>(
      pendingMediaQueueBoxName,
      encryptionCipher: cipher,
    );
    debugPrint('[HiveService] "$pendingMediaQueueBoxName" box opened.');

    userSettingsBox = await Hive.openBox<UserSettings>(
      userSettingsBoxName,
      encryptionCipher: cipher,
    );
    debugPrint('[HiveService] "$userSettingsBoxName" box opened.');

    // Ensure user settings has a default value if the box is new
    if (userSettingsBox.isEmpty) {
      debugPrint(
        '[HiveService] UserSettings box is empty. Seeding with default settings.',
      );
      await userSettingsBox.put('settings', UserSettings());
    }

    debugPrint('[HiveService] Hive initialization complete.');
  }

  void _registerAdapters() {
    debugPrint('[HiveService] Registering Hive type adapters...');
    Hive.registerAdapter(UserSettingsAdapter());
    Hive.registerAdapter(PendingMediaItemAdapter());
    Hive.registerAdapter(MediaTypeAdapter());
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

  /// Closes all open Hive boxes.
  Future<void> close() async {
    debugPrint('[HiveService] Closing all Hive boxes.');
    await Hive.close();
  }
}
