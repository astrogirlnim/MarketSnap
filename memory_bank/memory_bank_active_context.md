# Active Context

*Last Updated: June 24, 2025*

---

## Current Focus

Our current focus is the implementation of **Phase 2: Data Layer**. We have just completed the foundational step of this phase:

-   **Backend Setup & Security:** We have successfully initialized and configured the Firebase project, including Firestore, Functions, and Storage. Security rules have been implemented and verified using the local Firebase Emulator Suite.

## Recent Changes

-   **Firebase Project Initialized:** The local project is now fully integrated with the `marketsnap-app` Firebase project.
-   **Security Rules Implemented:** `firestore.rules` and `storage.rules` have been created to protect our data, restricting writes to authenticated owners and enforcing file size limits.
-   **Cloud Functions Initialized:** A TypeScript-based Cloud Functions project has been set up, compiled, and confirmed to load correctly in the emulator.
-   **Emulator Environment Established:** A complete local backend environment is now running, allowing for offline development and testing of all backend features.

## Next Steps

1.  **Complete Phase 2 (Data Layer):**
    -   Implement the 30-day TTL lifecycle policy on the Cloud Storage bucket for automatic media deletion.
    -   Develop and test the initial set of Cloud Functions (`sendFollowerPush`, `fanOutBroadcast`).
2.  **Begin Phase 3 (Interface Layer):**
    -   Start building the UI for user authentication and profile management.

# Active Context (Now)

- **Background sync (WorkManager) is now fully functional on both Android and iOS.**
  - Android: Execution is tracked and can be verified in-app.
  - iOS: Execution must be verified via console logs due to platform limitations (SharedPreferences not available in background isolate).
- All test UI and debug buttons have been removed; the implementation is now production-ready.
- Documentation and checklist updated to reflect the final state and manual verification approach for iOS.

**Current Sprint:** Phase 1 – Foundation (Week of June 24 2025)

### In Progress
- Flutter project bootstrap.
- Firebase project creation & SDK integration.
- Hive box scaffolding.

### Next Up
1. Register `SyncPendingMediaTask` WorkManager job.
2. Add unit tests for queue persistence.
3. Import LUT assets & set CI size gate.

### Recently Completed
- PRD v1.1 approved.
- MVP checklist generated and reformatted to nested checkboxes.

### Blockers
_None identified._

