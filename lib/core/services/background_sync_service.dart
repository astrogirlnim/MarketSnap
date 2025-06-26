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
      await _processPendingUploads();

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

/// Process pending media uploads in the background isolate
Future<void> _processPendingUploads() async {
  debugPrint('[Background Isolate] Processing pending media uploads...');

  try {
    // Check if user is authenticated
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('[Background Isolate] No authenticated user, skipping upload');
      return;
    }

    debugPrint('[Background Isolate] Authenticated user: ${user.uid}');

    // Open Hive box for pending media
    final Box<PendingMediaItem> pendingBox = await Hive.openBox<PendingMediaItem>('pendingMediaQueue');
    debugPrint('[Background Isolate] Opened Hive box "pendingMediaQueue" with ${pendingBox.length} pending items');

    if (pendingBox.isEmpty) {
      debugPrint('[Background Isolate] No pending media to upload');
      await pendingBox.close();
      return;
    }

    debugPrint('[Background Isolate] Found ${pendingBox.length} items to process.');
    // Process each pending media item
    final List<String> keysToRemove = [];
    
    for (var key in pendingBox.keys) {
      final pendingItem = pendingBox.get(key);
      if (pendingItem == null) {
        debugPrint('[Background Isolate] Skipping null item for key: $key');
        continue;
      }

      debugPrint('[Background Isolate] Processing pending item: ${pendingItem.id}');

      try {
        // Upload the media item
        await _uploadPendingItem(pendingItem, user);
        
        // Mark for removal from queue
        keysToRemove.add(key);
        debugPrint('[Background Isolate] Successfully uploaded: ${pendingItem.id}');
        
      } catch (e) {
        debugPrint('[Background Isolate] Failed to upload ${pendingItem.id}: $e');
        // Keep item in queue for retry
      }
    }

    // Remove successfully uploaded items from queue
    for (final key in keysToRemove) {
      await pendingBox.delete(key);
      debugPrint('[Background Isolate] Removed uploaded item from queue: $key');
    }

    debugPrint('[Background Isolate] Upload processing complete. Uploaded ${keysToRemove.length} items');

  } catch (e, stackTrace) {
    debugPrint('[Background Isolate] Error processing pending uploads: $e');
    debugPrint('[Background Isolate] Stack trace: $stackTrace');
  }
}

/// Upload a single pending media item
Future<void> _uploadPendingItem(PendingMediaItem pendingItem, User user) async {
  debugPrint('[Background Isolate] Uploading media item: ${pendingItem.id}');

  // Check if file still exists
  final file = File(pendingItem.filePath);
  if (!await file.exists()) {
    throw Exception('Media file no longer exists: ${pendingItem.filePath}');
  }

  // Upload to Firebase Storage
  final storageRef = FirebaseStorage.instance
      .ref()
      .child('vendors')
      .child(user.uid)
      .child('snaps')
      .child('${pendingItem.id}.${_getFileExtension(pendingItem.filePath)}');

  debugPrint('[Background Isolate] Uploading to Storage: ${storageRef.fullPath}');
  
  final uploadTask = storageRef.putFile(file);
  final snapshot = await uploadTask;
  final downloadUrl = await snapshot.ref.getDownloadURL();

  debugPrint('[Background Isolate] Upload complete. Download URL: $downloadUrl');

  // Get vendor profile for snap metadata
  final vendorDoc = await FirebaseFirestore.instance
      .collection('vendors')
      .doc(user.uid)
      .get();

  String vendorName = 'Unknown Vendor';
  String vendorAvatarUrl = '';
  
  if (vendorDoc.exists) {
    final vendorData = vendorDoc.data()!;
    vendorName = vendorData['displayName'] ?? vendorData['stallName'] ?? 'Unknown Vendor';
    vendorAvatarUrl = vendorData['avatarUrl'] ?? '';
  }

  // Create Firestore document
  final now = DateTime.now();
  final expiresAt = now.add(const Duration(hours: 24)); // 24-hour expiry

  final snapData = {
    'vendorId': user.uid,
    'vendorName': vendorName,
    'vendorAvatarUrl': vendorAvatarUrl,
    'mediaUrl': downloadUrl,
    'mediaType': pendingItem.mediaType == MediaType.video ? 'video' : 'photo',
    'caption': pendingItem.caption ?? '',
    'createdAt': Timestamp.fromDate(now),
    'expiresAt': Timestamp.fromDate(expiresAt),
    'location': pendingItem.location,
  };

  await FirebaseFirestore.instance
      .collection('snaps')
      .add(snapData);

  debugPrint('[Background Isolate] Firestore document created for snap: ${pendingItem.id}');
}

/// Get file extension from file path
String _getFileExtension(String filePath) {
  return filePath.split('.').last.toLowerCase();
}

/// Service responsible for managing background synchronization tasks
class BackgroundSyncService {
  static const String _uniqueTaskName = syncTaskName;
  static const String _oneOffTaskName = "${syncTaskName}_oneoff";

  // Track iOS executions in memory (since SharedPreferences doesn't work in background isolate)
  static DateTime? _lastIOSExecution;

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
    debugPrint('Triggering immediate sync...');
    
    try {
      // Process uploads immediately in the main isolate
      await _processPendingUploadsInMainIsolate();
      debugPrint('Immediate sync completed successfully');
    } catch (e) {
      debugPrint('Immediate sync failed: $e');
      rethrow;
    }
  }

  /// Process pending uploads in the main isolate (for immediate sync)
  Future<void> _processPendingUploadsInMainIsolate() async {
    debugPrint('[Main Isolate] Processing pending media uploads...');

    try {
      // Check if user is authenticated
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('[Main Isolate] No authenticated user, skipping upload');
        return;
      }

      debugPrint('[Main Isolate] Authenticated user: ${user.uid}');

      // Open the correct Hive box
      final Box<PendingMediaItem> pendingBox = await Hive.openBox<PendingMediaItem>('pendingMediaQueue');
      final pendingItems = pendingBox.values.toList();
      
      debugPrint('[Main Isolate] Opened "pendingMediaQueue" box with ${pendingItems.length} pending items.');

      if (pendingItems.isEmpty) {
        debugPrint('[Main Isolate] No pending media to upload');
        await pendingBox.close();
        return;
      }

      // Process each pending media item
      final List<PendingMediaItem> itemsToRemove = [];
      
      for (final pendingItem in pendingItems) {
        debugPrint('[Main Isolate] Processing pending item: ${pendingItem.id}');

        try {
          // Upload the media item
          await _uploadPendingItemInMainIsolate(pendingItem, user);
          
          // Mark for removal from queue
          itemsToRemove.add(pendingItem);
          debugPrint('[Main Isolate] Successfully uploaded: ${pendingItem.id}');
          
        } catch (e) {
          debugPrint('[Main Isolate] Failed to upload ${pendingItem.id}: $e');
          // Keep item in queue for retry
        }
      }

      // Remove successfully uploaded items from queue
      for (final item in itemsToRemove) {
        await pendingBox.delete(item.id);
        debugPrint('[Main Isolate] Removed uploaded item from queue: ${item.id}');
      }
      
      debugPrint('[Main Isolate] Upload processing complete. Uploaded ${itemsToRemove.length} items');

    } catch (e, stackTrace) {
      debugPrint('[Main Isolate] Error in _processPendingUploadsInMainIsolate: $e');
      debugPrint('[Main Isolate] Stack trace: $stackTrace');
      // Re-throwing the error so the caller can handle it
      rethrow;
    }
  }

  /// Upload a single pending media item in the main isolate
  Future<void> _uploadPendingItemInMainIsolate(PendingMediaItem pendingItem, User user) async {
    debugPrint('[Main Isolate] Uploading media item: ${pendingItem.id}');

    // Check if file still exists
    final file = File(pendingItem.filePath);
    if (!await file.exists()) {
      throw Exception('Media file no longer exists: ${pendingItem.filePath}');
    }

    // Upload to Firebase Storage
    final storageRef = FirebaseStorage.instance
        .ref()
        .child('vendors')
        .child(user.uid)
        .child('snaps')
        .child('${pendingItem.id}.${_getFileExtension(pendingItem.filePath)}');

    debugPrint('[Main Isolate] Uploading to Storage: ${storageRef.fullPath}');
    
    final uploadTask = storageRef.putFile(file);
    final snapshot = await uploadTask;
    final downloadUrl = await snapshot.ref.getDownloadURL();

    debugPrint('[Main Isolate] Upload complete. Download URL: $downloadUrl');

    // Get vendor profile for snap metadata
    final vendorDoc = await FirebaseFirestore.instance
        .collection('vendors')
        .doc(user.uid)
        .get();

    String vendorName = 'Unknown Vendor';
    String vendorAvatarUrl = '';
    
    if (vendorDoc.exists) {
      final vendorData = vendorDoc.data()!;
      vendorName = vendorData['displayName'] ?? vendorData['stallName'] ?? 'Unknown Vendor';
      vendorAvatarUrl = vendorData['avatarUrl'] ?? '';
    }

    // Create Firestore document
    final now = DateTime.now();
    final expiresAt = now.add(const Duration(hours: 24)); // 24-hour expiry

    final snapData = {
      'vendorId': user.uid,
      'vendorName': vendorName,
      'vendorAvatarUrl': vendorAvatarUrl,
      'mediaUrl': downloadUrl,
      'mediaType': pendingItem.mediaType == MediaType.video ? 'video' : 'photo',
      'caption': pendingItem.caption ?? '',
      'createdAt': Timestamp.fromDate(now),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'location': pendingItem.location,
    };

    await FirebaseFirestore.instance
        .collection('snaps')
        .add(snapData);

    debugPrint('[Main Isolate] Firestore document created for snap: ${pendingItem.id}');
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
