import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:marketsnap/core/models/pending_media.dart';
import 'hive_service.dart'; // Import HiveService

// Unique name for the background task
const syncTaskName = "syncPendingMediaTask";

/// This top-level function is called by the workmanager plugin to execute the task.
/// It must be a top-level function and not a class method.
@pragma('vm:entry-point')
void callbackDispatcher() {
  // The workmanager plugin executes this function in a separate isolate
  // Initialize the workmanager within this isolate
  Workmanager().executeTask((task, inputData) async {
    debugPrint('[Background Isolate] Native called background task: $task');
    debugPrint('[Background Isolate] Input data: $inputData');
    debugPrint('[Background Isolate] Platform: ${Platform.operatingSystem}');

    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      debugPrint(
        '[Background Isolate] Executing background sync task for pending media...',
      );
      debugPrint('[Background Isolate] Timestamp: $timestamp');
      debugPrint('[Background Isolate] Platform: ${Platform.operatingSystem}');

      // Initialize Firebase in the background isolate
      await Firebase.initializeApp();
      debugPrint('[Background Isolate] Firebase initialized');

      // Initialize Hive in the background isolate
      await Hive.initFlutter();
      Hive.registerAdapter(MediaTypeAdapter());
      Hive.registerAdapter(PendingMediaItemAdapter());
      debugPrint('[Background Isolate] Hive initialized');

      // Process pending media uploads
      await _processQueue(isInBackground: true);

      // Store execution info differently based on platform
      if (Platform.isAndroid) {
        // Android: Use SharedPreferences (works in background isolate)
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt('last_background_execution', timestamp);
          await prefs.setString('last_background_task', task);
          await prefs.setString(
            'last_background_platform',
            Platform.operatingSystem,
          );
          debugPrint(
            '[Background Isolate] Android: Stored execution record in SharedPreferences',
          );
        } catch (e) {
          debugPrint(
            '[Background Isolate] Android: Failed to store in SharedPreferences: $e',
          );
        }
      } else {
        // iOS: SharedPreferences doesn't work in background isolate
        // We'll use a different approach - the main app will detect execution via logs
        debugPrint(
          '[Background Isolate] iOS: Background task executed successfully (SharedPreferences not available in iOS background isolate)',
        );
        debugPrint(
          '[Background Isolate] iOS: Task execution timestamp: $timestamp',
        );
        debugPrint('[Background Isolate] iOS: Task name: $task');
      }

      debugPrint(
        '[Background Isolate] Background sync task completed successfully.',
      );

      return Future.value(true); // Task completed successfully
    } catch (e, stackTrace) {
      debugPrint('[Background Isolate] Error in background sync task: $e');
      debugPrint('[Background Isolate] Stack trace: $stackTrace');
      return Future.value(false); // Task failed
    }
  });
}

/// This is the new, unified processing loop for handling the media queue.
/// It can be called from a background isolate or the main isolate.
///
/// [isInBackground] determines the logging prefix.
/// [hiveService] is an optional parameter. If provided (from the main isolate),
/// it will be passed to `_uploadPendingItem` to fetch user profiles from the local cache.
Future<void> _processQueue({
  required bool isInBackground,
  HiveService? hiveService,
}) async {
  final logPrefix = isInBackground ? '[Background Isolate]' : '[Main Isolate]';
  debugPrint('$logPrefix Processing pending media uploads...');

  try {
    // Check if user is authenticated
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('$logPrefix No authenticated user, skipping upload');
      return;
    }

    debugPrint('$logPrefix Authenticated user: ${user.uid}');

    // Open Hive box for pending media. It must be managed carefully.
    final Box<PendingMediaItem> pendingBox =
        await Hive.openBox<PendingMediaItem>('pendingMediaQueue');
    debugPrint(
      '$logPrefix Opened Hive box "pendingMediaQueue" with ${pendingBox.length} pending items',
    );

    if (pendingBox.isEmpty) {
      debugPrint('$logPrefix No pending media to upload');
      if (isInBackground) {
        await pendingBox.close();
      }
      return;
    }

    debugPrint('$logPrefix Found ${pendingBox.length} items to process.');

    final List<dynamic> successfulKeys = [];
    final List<dynamic> failedKeys = [];

    // Use .keys.toList() to avoid issues with concurrent modification
    for (var key in pendingBox.keys.toList()) {
      final pendingItem = pendingBox.get(key);
      if (pendingItem == null) {
        debugPrint('$logPrefix Skipping null item for key: $key');
        failedKeys.add(key); // Mark corrupted/null item for removal
        continue;
      }

      debugPrint('$logPrefix Processing pending item: ${pendingItem.id}');

      try {
        // Upload the media item, passing the hiveService if available
        await _uploadPendingItem(
          pendingItem,
          user,
          hiveService: hiveService,
          isInBackground: isInBackground,
        );
        successfulKeys.add(key);
        debugPrint('$logPrefix Successfully uploaded: ${pendingItem.id}');
      } catch (e) {
        debugPrint('$logPrefix Failed to upload ${pendingItem.id}: $e');
        if (e.toString().contains('Media file no longer exists')) {
          debugPrint(
            '$logPrefix Marking item ${pendingItem.id} for removal due to missing file.',
          );
          failedKeys.add(key);
        }
      }
    }

    // Remove successfully uploaded and permanently failed items from queue
    for (final key in successfulKeys) {
      await pendingBox.delete(key);
      debugPrint('$logPrefix Removed SUCCEEDED item from queue: $key');
    }
    for (final key in failedKeys) {
      await pendingBox.delete(key);
      debugPrint('$logPrefix Removed FAILED item from queue: $key');
    }

    if (isInBackground) {
      await pendingBox.close();
    }

    debugPrint(
      '$logPrefix Upload processing complete. Success: ${successfulKeys.length}, Failed: ${failedKeys.length}',
    );
  } catch (e, stackTrace) {
    debugPrint('$logPrefix Error processing pending uploads: $e');
    debugPrint('$logPrefix Stack trace: $stackTrace');
  }
}

/// Unified function to upload a single pending media item.
/// It can be called from the main or background isolate.
Future<void> _uploadPendingItem(
  PendingMediaItem pendingItem,
  User user, {
  HiveService? hiveService,
  required bool isInBackground,
}) async {
  final logPrefix = isInBackground ? '[Background Isolate]' : '[Main Isolate]';

  debugPrint('$logPrefix Processing pending item:');
  debugPrint('$logPrefix - ID: ${pendingItem.id}');
  debugPrint('$logPrefix - MediaType: ${pendingItem.mediaType}');
  debugPrint('$logPrefix - FilterType: "${pendingItem.filterType}"');
  debugPrint('$logPrefix - FilePath: ${pendingItem.filePath}');
  debugPrint('$logPrefix - Caption: ${pendingItem.caption}');

  debugPrint('$logPrefix Uploading media item: ${pendingItem.id}');

  final file = File(pendingItem.filePath);
  if (!await file.exists()) {
    throw Exception('Media file no longer exists: ${pendingItem.filePath}');
  }

  final storageRef = FirebaseStorage.instance
      .ref()
      .child('vendors')
      .child(user.uid)
      .child('snaps')
      .child('${pendingItem.id}.${_getFileExtension(pendingItem.filePath)}');

  debugPrint('$logPrefix Uploading to Storage: ${storageRef.fullPath}');
  debugPrint('$logPrefix File exists: ${await file.exists()}');
  debugPrint('$logPrefix File size: ${await file.length()} bytes');
  debugPrint('$logPrefix User UID: ${user.uid}');
  debugPrint('$logPrefix User email: ${user.email}');
  debugPrint(
    '$logPrefix User providers: ${user.providerData.map((p) => p.providerId).toList()}',
  );

  late final String downloadUrl;
  try {
    final uploadTask = storageRef.putFile(file);
    final snapshot = await uploadTask;
    downloadUrl = await snapshot.ref.getDownloadURL();
    debugPrint('$logPrefix Upload complete. Download URL: $downloadUrl');
  } catch (uploadError) {
    debugPrint('$logPrefix UPLOAD ERROR: $uploadError');
    debugPrint('$logPrefix Error type: ${uploadError.runtimeType}');
    if (uploadError.toString().contains('unauthenticated')) {
      debugPrint('$logPrefix Authentication token issue detected');
      debugPrint(
        '$logPrefix Current user: ${FirebaseAuth.instance.currentUser?.uid}',
      );
      debugPrint('$logPrefix ID token: ${await user.getIdToken(true)}');
    }
    rethrow;
  }

  // Get vendor profile for snap metadata
  String vendorName = 'Unknown Vendor';
  String vendorAvatarUrl = '';

  // If hiveService is available (main isolate), use it for a fast lookup.
  if (hiveService != null) {
    final profile = hiveService.getVendorProfile(user.uid);
    if (profile != null) {
      vendorName = profile.displayName;
      vendorAvatarUrl = profile.avatarURL ?? '';
      debugPrint('$logPrefix Fetched vendor profile from Hive: $vendorName');
    }
  } else {
    // In background, fetch from Firestore.
    final vendorDoc = await FirebaseFirestore.instance
        .collection('vendors')
        .doc(user.uid)
        .get();
    if (vendorDoc.exists) {
      final vendorData = vendorDoc.data()!;
      vendorName =
          vendorData['displayName'] ??
          vendorData['stallName'] ??
          'Unknown Vendor';
      vendorAvatarUrl = vendorData['avatarURL'] ?? '';
      debugPrint(
        '$logPrefix Fetched vendor profile from Firestore: $vendorName',
      );
    }
  }

  // Create Firestore document
  final now = DateTime.now();
  final expiresAt = now.add(const Duration(hours: 24));

  final snapData = {
    'vendorId': user.uid,
    'vendorName': vendorName,
    'vendorAvatarUrl': vendorAvatarUrl,
    'mediaUrl': downloadUrl,
    'mediaType': pendingItem.mediaType == MediaType.video ? 'video' : 'photo',
    'caption': pendingItem.caption ?? '',
    'filterType': pendingItem.filterType,
    'createdAt': Timestamp.fromDate(now),
    'expiresAt': Timestamp.fromDate(expiresAt),
    'location': pendingItem.location,
    'isStory': true,
    'storyVendorId': user.uid,
  };

  debugPrint(
    '$logPrefix Creating Firestore document with filterType: "${pendingItem.filterType}"',
  );
  debugPrint('$logPrefix Full snapData: $snapData');

  await FirebaseFirestore.instance.collection('snaps').add(snapData);
  debugPrint(
    '$logPrefix Firestore document created for snap: ${pendingItem.id}',
  );

  try {
    await file.delete();
    debugPrint(
      '$logPrefix Deleted uploaded media file: ${pendingItem.filePath}',
    );
  } catch (e) {
    debugPrint(
      '$logPrefix Error deleting media file ${pendingItem.filePath}: $e',
    );
  }
}

/// Get file extension from file path
String _getFileExtension(String filePath) {
  return filePath.split('.').last.toLowerCase();
}

/// Service responsible for managing background synchronization tasks
class BackgroundSyncService {
  static const String _uniqueTaskName = syncTaskName;
  static const String _oneOffTaskName = "${syncTaskName}_oneoff";

  // Track whether a sync is currently in progress
  bool _isSyncing = false;

  // Track iOS executions in memory (since SharedPreferences doesn't work in background isolate)
  static DateTime? _lastIOSExecution;

  // HiveService for accessing the queue in main isolate
  final HiveService? _hiveService;

  BackgroundSyncService({HiveService? hiveService})
    : _hiveService = hiveService;

  /// Initialize the WorkManager plugin
  Future<void> initialize() async {
    debugPrint('Initializing BackgroundSyncService...');
    debugPrint('Platform: ${Platform.operatingSystem}');

    try {
      await Workmanager().initialize(
        callbackDispatcher,
        isInDebugMode: kDebugMode, // Show notifications in debug mode
      );
      debugPrint('WorkManager initialized.');
    } catch (e) {
      debugPrint('Error initializing WorkManager: $e');
      rethrow;
    }
  }

  /// Schedule a periodic background sync task
  /// This task will run approximately every 15 minutes when the device has network connectivity
  /// Note: iOS has stricter background execution policies than Android
  Future<void> scheduleSyncTask() async {
    debugPrint('Scheduling periodic background sync task...');
    debugPrint('Platform: ${Platform.operatingSystem}');

    try {
      if (Platform.isIOS) {
        // iOS doesn't support true periodic background tasks
        // The workmanager plugin will simulate this using background app refresh
        debugPrint('iOS detected: Using background app refresh simulation');
        await Workmanager().registerPeriodicTask(
          _uniqueTaskName,
          _uniqueTaskName,
          frequency: const Duration(minutes: 15),
          constraints: Constraints(
            networkType: NetworkType.connected,
            requiresBatteryNotLow: false,
            requiresCharging: false,
            requiresDeviceIdle: false,
          ),
          existingWorkPolicy: ExistingWorkPolicy.replace,
        );
      } else {
        // Android supports more reliable periodic background tasks
        debugPrint(
          'Android detected: Using standard WorkManager periodic task',
        );
        await Workmanager().registerPeriodicTask(
          _uniqueTaskName,
          _uniqueTaskName,
          frequency: const Duration(minutes: 15),
          constraints: Constraints(
            networkType: NetworkType.connected,
            requiresBatteryNotLow: false,
            requiresCharging: false,
            requiresDeviceIdle: false,
          ),
          backoffPolicy: BackoffPolicy.exponential,
          backoffPolicyDelay: const Duration(seconds: 10),
          existingWorkPolicy: ExistingWorkPolicy.replace,
        );
      }
      debugPrint('Periodic background sync task scheduled.');
    } catch (e) {
      debugPrint('Error scheduling background sync task: $e');
      rethrow;
    }
  }

  /// Schedule a one-time background sync task (useful for immediate sync)
  /// This is more reliable on iOS than periodic tasks
  Future<void> scheduleOneTimeSyncTask() async {
    debugPrint('Scheduling one-time background sync task...');
    debugPrint('Platform: ${Platform.operatingSystem}');

    try {
      if (Platform.isIOS) {
        // On iOS, use a unique identifier each time to ensure execution
        final uniqueId =
            "${_oneOffTaskName}_${DateTime.now().millisecondsSinceEpoch}";
        debugPrint('iOS: Using unique task ID: $uniqueId');

        // Track when we schedule the task for iOS
        _lastIOSExecution = DateTime.now();

        await Workmanager().registerOneOffTask(
          uniqueId,
          _uniqueTaskName, // Still use the same task name for the callback
          constraints: Constraints(networkType: NetworkType.connected),
          existingWorkPolicy: ExistingWorkPolicy.append,
        );
      } else {
        // Android can reuse the same task ID
        await Workmanager().registerOneOffTask(
          _oneOffTaskName,
          _uniqueTaskName,
          constraints: Constraints(networkType: NetworkType.connected),
          backoffPolicy: BackoffPolicy.exponential,
          backoffPolicyDelay: const Duration(seconds: 5),
          existingWorkPolicy: ExistingWorkPolicy.append,
        );
      }
      debugPrint('One-time background sync task scheduled.');
    } catch (e) {
      debugPrint('Error scheduling one-time background sync task: $e');
      rethrow;
    }
  }

  /// Manually trigger an immediate sync (for development/testing)
  Future<void> triggerImmediateSync() async {
    const String logPrefix = '[Main Isolate]';
    if (_isSyncing) {
      debugPrint('$logPrefix Sync already in progress, skipping.');
      return;
    }

    _isSyncing = true;

    try {
      // Process uploads immediately in the main isolate
      await _processQueue(isInBackground: false, hiveService: _hiveService);
      debugPrint('Immediate sync completed successfully');
    } catch (e) {
      debugPrint('Immediate sync failed: $e');
      rethrow;
    } finally {
      _isSyncing = false;
    }
  }

  /// Get the last background execution time (for debugging)
  Future<DateTime?> getLastExecutionTime() async {
    if (Platform.isIOS) {
      return _lastIOSExecution;
    } else {
      try {
        final prefs = await SharedPreferences.getInstance();
        final timestamp = prefs.getInt('last_background_execution');
        return timestamp != null
            ? DateTime.fromMillisecondsSinceEpoch(timestamp)
            : null;
      } catch (e) {
        debugPrint('Error getting last execution time: $e');
        return null;
      }
    }
  }

  /// Cancel all background sync tasks
  Future<void> cancelAllTasks() async {
    debugPrint('Cancelling all background sync tasks...');
    try {
      await Workmanager().cancelAll();
      debugPrint('All background sync tasks cancelled.');
    } catch (e) {
      debugPrint('Error cancelling background sync tasks: $e');
      rethrow;
    }
  }
}
