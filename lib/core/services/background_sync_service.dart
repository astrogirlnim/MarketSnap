import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';

// Unique name for the background task
const syncTaskName = "syncPendingMediaTask";

/// This top-level function is called by the workmanager plugin to execute the task.
/// It must be a top-level function and not a class method.
@pragma('vm:entry-point')
void callbackDispatcher() {
  // The workmanager plugin executes this function in a separate isolate.
  Workmanager().executeTask((task, inputData) async {
    if (kDebugMode) {
      print("Native called background task: $task");
    }

    try {
      // In Phase 4, this is where we would trigger the actual upload logic.
      // For now, we just simulate work with a delay and log it.
      if (kDebugMode) {
        print("Executing background sync task for pending media...");
      }

      // Simulate network operation
      await Future.delayed(const Duration(seconds: 5));

      if (kDebugMode) {
        print("Background sync task completed successfully.");
      }

      // Return true to indicate that the task was successful.
      return Future.value(true);
    } catch (err) {
      if (kDebugMode) {
        print("An error occurred during background sync: $err");
      }
      // Return false to indicate a failure. The task will be retried based on the backoff policy.
      return Future.value(false);
    }
  });
}


/// Service to manage background synchronization tasks.
class BackgroundSyncService {
  /// Initializes the WorkManager and registers the background task.
  Future<void> initialize() async {
    if (kDebugMode) {
      print("Initializing BackgroundSyncService...");
    }
    await Workmanager().initialize(
      callbackDispatcher,
      // If enabled, it will post a notification whenever the task is running. Useful for debugging.
      isInDebugMode: kDebugMode,
    );
    if (kDebugMode) {
      print("WorkManager initialized.");
    }
  }

  /// Schedules the background sync task to run periodically.
  /// This registers a task that will run approximately every 15 minutes.
  /// WorkManager will respect battery-saving optimizations by the OS.
  Future<void> scheduleSyncTask() async {
    if (kDebugMode) {
      print("Scheduling periodic background sync task...");
    }
    await Workmanager().registerPeriodicTask(
      "1", // Unique ID for the periodic task
      syncTaskName,
      frequency: const Duration(minutes: 15), // As per PRD, sync should be attempted regularly
      constraints: Constraints(
        networkType: NetworkType.connected, // Only run when connected to a network
      ),
      // Exponential backoff policy for retries on failure.
      backoffPolicy: BackoffPolicy.exponential,
      backoffPolicyDelay: const Duration(seconds: 10),
    );
    if (kDebugMode) {
      print("Periodic background sync task scheduled.");
    }
  }

  /// Schedules a one-off sync task.
  /// This can be used to trigger an immediate sync attempt when the app comes online.
  Future<void> scheduleOneTimeSyncTask() async {
    if (kDebugMode) {
      print("Scheduling a one-time background sync task...");
    }
    await Workmanager().registerOneOffTask(
      "2", // Unique ID for the one-off task
      syncTaskName,
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
      backoffPolicy: BackoffPolicy.exponential,
      backoffPolicyDelay: const Duration(seconds: 10),
    );
    if (kDebugMode) {
      print("One-time background sync task scheduled.");
    }
  }
} 