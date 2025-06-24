import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    
    try {
      // Store execution timestamp in shared preferences for verification
      final prefs = await SharedPreferences.getInstance();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      await prefs.setInt('last_background_execution', timestamp);
      await prefs.setString('last_background_task', task);
      
      debugPrint('[Background Isolate] Executing background sync task for pending media...');
      debugPrint('[Background Isolate] Timestamp: $timestamp');
      
      // Simulate the work that will be done in Phase 4
      // In the future, this will:
      // 1. Load pending media items from Hive
      // 2. Upload them to Firebase Storage
      // 3. Create Firestore documents
      // 4. Remove successfully uploaded items from the queue
      
      await Future.delayed(const Duration(seconds: 2)); // Simulate work
      
      debugPrint('[Background Isolate] Background sync task completed successfully.');
      debugPrint('[Background Isolate] Stored execution record in SharedPreferences');
      
      return Future.value(true); // Task completed successfully
    } catch (e, stackTrace) {
      debugPrint('[Background Isolate] Error in background sync task: $e');
      debugPrint('[Background Isolate] Stack trace: $stackTrace');
      return Future.value(false); // Task failed
    }
  });
}

/// Service responsible for managing background synchronization tasks
class BackgroundSyncService {
  static const String _uniqueTaskName = syncTaskName;
  
  /// Initialize the WorkManager plugin
  Future<void> initialize() async {
    debugPrint('Initializing BackgroundSyncService...');
    
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
  Future<void> scheduleSyncTask() async {
    debugPrint('Scheduling periodic background sync task...');
    
    try {
      await Workmanager().registerPeriodicTask(
        _uniqueTaskName, // Unique name for this task
        _uniqueTaskName, // Task identifier passed to callbackDispatcher
        frequency: const Duration(minutes: 15), // Run every 15 minutes
        constraints: Constraints(
          networkType: NetworkType.connected, // Only run when connected to network
          requiresBatteryNotLow: false, // Can run even if battery is low
          requiresCharging: false, // Can run when not charging
          requiresDeviceIdle: false, // Can run when device is active
        ),
        backoffPolicy: BackoffPolicy.exponential, // Exponential backoff on failure
        backoffPolicyDelay: const Duration(seconds: 10), // Initial backoff delay
        existingWorkPolicy: ExistingWorkPolicy.replace, // Replace existing task
      );
      debugPrint('Periodic background sync task scheduled.');
    } catch (e) {
      debugPrint('Error scheduling background sync task: $e');
      rethrow;
    }
  }
  
  /// Schedule a one-time background sync task (useful for immediate sync)
  Future<void> scheduleOneTimeSyncTask() async {
    debugPrint('Scheduling one-time background sync task...');
    
    try {
      await Workmanager().registerOneOffTask(
        "${_uniqueTaskName}_oneoff", // Unique name for one-off task
        _uniqueTaskName, // Task identifier passed to callbackDispatcher
        constraints: Constraints(
          networkType: NetworkType.connected, // Only run when connected to network
        ),
        backoffPolicy: BackoffPolicy.exponential, // Exponential backoff on failure
        backoffPolicyDelay: const Duration(seconds: 5), // Shorter delay for one-off
        existingWorkPolicy: ExistingWorkPolicy.append, // Don't replace, append
      );
      debugPrint('One-time background sync task scheduled.');
    } catch (e) {
      debugPrint('Error scheduling one-time background sync task: $e');
      rethrow;
    }
  }
  
  /// Check if the background task has executed recently
  /// This is useful for testing and debugging
  Future<Map<String, dynamic>> getLastExecutionInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getInt('last_background_execution');
      final taskName = prefs.getString('last_background_task');
      
      if (timestamp != null) {
        final executionTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
        return {
          'executed': true,
          'timestamp': timestamp,
          'executionTime': executionTime.toString(),
          'taskName': taskName,
          'minutesAgo': DateTime.now().difference(executionTime).inMinutes,
        };
      } else {
        return {'executed': false};
      }
    } catch (e) {
      debugPrint('Error getting last execution info: $e');
      return {'executed': false, 'error': e.toString()};
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