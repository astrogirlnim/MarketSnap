# Phase 1.3 Implementation Report: WorkManager Jobs

*Generated: June 25, 2025*

---

## 1. Overview

This document details the implementation of **Phase 1.3: WorkManager Jobs** as outlined in the `MarketSnap_Lite_MVP_Checklist_Simple.md`. The primary goal of this phase was to establish a robust background task execution system for handling offline media uploads.

This was accomplished using the `workmanager` Flutter package, which provides a reliable way to schedule and run tasks even when the application is not in the foreground.

## 2. Files Created and Modified

### New Files

-   **`lib/core/services/background_sync_service.dart`**: This new service encapsulates all logic related to background task management. It is responsible for initializing the `workmanager`, defining the task itself, and scheduling it.

### Modified Files

-   **`lib/main.dart`**: The application's entry point was modified to initialize the `BackgroundSyncService` on startup. This ensures that the background sync task is registered with the operating system as soon as the app launches.
-   **`documentation/MarketSnap_Lite_MVP_Checklist_Simple.md`**: The checklist was updated to mark Phase 1.3 and its sub-tasks as complete.

## 3. Code Architecture

### `BackgroundSyncService`

The core of this implementation is the `BackgroundSyncService`. It follows the existing service pattern in `lib/core/services`.

-   **`callbackDispatcher()`**: A top-level function that acts as the entry point for the background isolate, as required by `workmanager`. It currently contains logging and a placeholder for the future media upload logic (to be implemented in Phase 4).
-   **`initialize()`**: Initializes the `Workmanager` plugin, linking it to the `callbackDispatcher`.
-   **`scheduleSyncTask()`**: Registers a periodic task (`SyncPendingMediaTask`) that runs approximately every 15 minutes when the device has network connectivity. This aligns with the PRD requirement for regular sync attempts.
-   **`scheduleOneTimeSyncTask()`**: A helper method to schedule an immediate one-off task. This can be used later to trigger a sync when the app detects it has come back online.

### Initialization in `main.dart`

A global instance of `BackgroundSyncService` is created and initialized within the `main` function. The `scheduleSyncTask()` method is called immediately after initialization to ensure the periodic sync is always active. Error handling has been added to log any failures during this process.

## 4. Configuration and Policy

### Exponential Back-off

The background task was configured with an **exponential back-off policy**. If a sync task fails (e.g., due to a temporary server error), `workmanager` will automatically retry it. The delay between retries will increase exponentially, which prevents spamming the server and conserves battery life. The initial delay is set to 10 seconds.

### Network Constraints

The task is constrained to only run when `NetworkType.connected` is true. This prevents the task from running and failing unnecessarily when the device is offline, saving system resources.

## 5. Firebase Configuration Considerations

There are **no direct Firebase configuration changes** required for this phase. The `workmanager` operates at the OS level to schedule and execute Dart code.

However, when the actual upload logic is implemented in **Phase 4**, the background task will need to interact with Firebase services (Firestore and Cloud Storage). The Firebase initialization that already exists in `main.dart` will be crucial, and we will need to ensure that the background isolate can access the initialized Firebase app instance. This is a common challenge with background tasks in Flutter and will be addressed during Phase 4 implementation.

## 6. Testing and Verification

As per user instructions, a formal unit test file was not created. Verification of this phase relies on the following:

-   **Extensive Logging**: The service and `main.dart` have been instrumented with `debugPrint` statements. By running the app in debug mode and observing the console output, we can verify:
    -   The `BackgroundSyncService` initializes successfully.
    -   The periodic task is scheduled.
    -   (With the app in the background) The `callbackDispatcher` is triggered by the OS, and the "Executing background sync task..." log appears.
-   **WorkManager Debug Mode**: `isInDebugMode: kDebugMode` was enabled during `Workmanager().initialize()`. When `true`, the plugin will show a system notification on Android when a task is running, providing a visible confirmation that the job is executing.

This concludes the implementation of Phase 1.3. The foundation for background processing is now in place. 