import 'dart:async';
import 'dart:io';
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
    debugPrint('[Background Isolate] Platform: ${Platform.operatingSystem}');
    
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      
      debugPrint('[Background Isolate] Executing background sync task for pending media...');
      debugPrint('[Background Isolate] Timestamp: $timestamp');
      debugPrint('[Background Isolate] Platform: ${Platform.operatingSystem}');
      
      // Store execution info differently based on platform
      if (Platform.isAndroid) {
        // Android: Use SharedPreferences (works in background isolate)
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt('last_background_execution', timestamp);
          await prefs.setString('last_background_task', task);
          await prefs.setString('last_background_platform', Platform.operatingSystem);
          debugPrint('[Background Isolate] Android: Stored execution record in SharedPreferences');
        } catch (e) {
          debugPrint('[Background Isolate] Android: Failed to store in SharedPreferences: $e');
        }
      } else {
        // iOS: SharedPreferences doesn't work in background isolate
        // We'll use a different approach - the main app will detect execution via logs
        debugPrint('[Background Isolate] iOS: Background task executed successfully (SharedPreferences not available in iOS background isolate)');
        debugPrint('[Background Isolate] iOS: Task execution timestamp: $timestamp');
        debugPrint('[Background Isolate] iOS: Task name: $task');
      }
      
      // Simulate the work that will be done in Phase 4
      // In the future, this will:
      // 1. Load pending media items from Hive (may need iOS-specific handling)
      // 2. Upload them to Firebase Storage
      // 3. Create Firestore documents
      // 4. Remove successfully uploaded items from the queue
      
      await Future.delayed(const Duration(seconds: 2)); // Simulate work
      
      debugPrint('[Background Isolate] Background sync task completed successfully.');
      
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
  static const String _oneOffTaskName = "${syncTaskName}_oneoff";
  
  // Track iOS executions in memory (since SharedPreferences doesn't work in background isolate)
  static DateTime? _lastIOSExecution;
  static String? _lastIOSTaskName;
  
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
        debugPrint('Android detected: Using standard WorkManager periodic task');
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
        final uniqueId = "${_oneOffTaskName}_${DateTime.now().millisecondsSinceEpoch}";
        debugPrint('iOS: Using unique task ID: $uniqueId');
        
        // Track when we schedule the task for iOS
        _lastIOSExecution = DateTime.now();
        _lastIOSTaskName = uniqueId;
        
        await Workmanager().registerOneOffTask(
          uniqueId,
          _uniqueTaskName, // Still use the same task name for the callback
          constraints: Constraints(
            networkType: NetworkType.connected,
          ),
          existingWorkPolicy: ExistingWorkPolicy.append,
        );
      } else {
        // Android can reuse the same task ID
        await Workmanager().registerOneOffTask(
          _oneOffTaskName,
          _uniqueTaskName,
          constraints: Constraints(
            networkType: NetworkType.connected,
          ),
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
  
  /// Check if the background task has executed recently
  /// This is useful for testing and debugging
  Future<Map<String, dynamic>> getLastExecutionInfo() async {
    try {
      if (Platform.isIOS) {
        // For iOS, we use in-memory tracking since SharedPreferences doesn't work in background isolate
        if (_lastIOSExecution != null) {
          return {
            'executed': true,
            'timestamp': _lastIOSExecution!.millisecondsSinceEpoch,
            'executionTime': _lastIOSExecution!.toString(),
            'taskName': _lastIOSTaskName ?? 'unknown',
            'platform': 'ios',
            'minutesAgo': DateTime.now().difference(_lastIOSExecution!).inMinutes,
            'note': 'iOS: Task was scheduled. Check logs for actual execution confirmation.',
          };
        } else {
          return {
            'executed': false,
            'platform': 'ios',
            'note': 'iOS: No tasks scheduled yet.',
          };
        }
      } else {
        // Android uses SharedPreferences as before
        final prefs = await SharedPreferences.getInstance();
        final timestamp = prefs.getInt('last_background_execution');
        final taskName = prefs.getString('last_background_task');
        final platform = prefs.getString('last_background_platform');
        
        if (timestamp != null) {
          final executionTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
          return {
            'executed': true,
            'timestamp': timestamp,
            'executionTime': executionTime.toString(),
            'taskName': taskName,
            'platform': platform ?? 'android',
            'minutesAgo': DateTime.now().difference(executionTime).inMinutes,
          };
        } else {
          return {
            'executed': false,
            'platform': 'android',
          };
        }
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
      
      // Clear iOS tracking
      if (Platform.isIOS) {
        _lastIOSExecution = null;
        _lastIOSTaskName = null;
      }
      
      debugPrint('All background sync tasks cancelled.');
    } catch (e) {
      debugPrint('Error cancelling background sync tasks: $e');
      rethrow;
    }
  }
  
  /// Restart the WorkManager service to pick up updated callback function
  /// This is useful when the callback function has been updated
  Future<void> restartWorkManager() async {
    debugPrint('Restarting WorkManager to pick up updated callback...');
    
    try {
      // Cancel all existing tasks first
      await cancelAllTasks();
      
      // Small delay to ensure cleanup
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Reinitialize WorkManager with the updated callback
      await initialize();
      
      // Reschedule the periodic task
      await scheduleSyncTask();
      
      debugPrint('WorkManager restarted successfully.');
    } catch (e) {
      debugPrint('Error restarting WorkManager: $e');
      rethrow;
    }
  }
  
  /// Get platform-specific information about background task limitations
  String getPlatformInfo() {
    if (Platform.isIOS) {
      return 'iOS: Background tasks are limited and may not execute immediately. '
             'SharedPreferences is not available in iOS background isolates. '
             'Enable Background App Refresh in Settings > General > Background App Refresh. '
             'Tasks are more likely to run when the app is backgrounded and the device is charging. '
             'Check console logs for "[Background Isolate]" messages to confirm execution.';
    } else if (Platform.isAndroid) {
      return 'Android: Background tasks use WorkManager and should execute reliably. '
             'May be affected by battery optimization settings. '
             'Execution is tracked via SharedPreferences.';
    } else {
      return 'Platform: ${Platform.operatingSystem} - Background task support varies.';
    }
  }
} 