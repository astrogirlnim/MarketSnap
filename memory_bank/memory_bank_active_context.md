# Active Context

*Last Updated: June 25, 2025*

---

## Current Focus

We have successfully completed **Phase 2.3: Cloud Functions (Core)**. The core backend logic for push notifications is now implemented, unit-tested, and a reliable local testing workflow has been established using the Firebase Emulator Suite.

### ✅ Phase 2.3 Complete - Recent Achievements:

-   **Cloud Functions Implemented:**
    -   `sendFollowerPush`: Triggers on new `snaps` documents to notify followers.
    -   `fanOutBroadcast`: Triggers on new `broadcasts` documents to notify followers.
-   **Unit Tests:** Both functions have comprehensive unit tests created with the Firebase Functions Test SDK, Mocha, and Chai, ensuring logical correctness.
-   **Local Emulator Workflow:** Established a clear, documented process for running and testing Cloud Functions locally. This includes generating the `firebase.json` from a template and manually triggering functions via the Firestore Emulator UI.
-   **Troubleshooting:** Successfully diagnosed and resolved emulator startup issues related to Firebase configuration.
-   **Documentation:** Updated the project `README.md` with detailed instructions for the local emulator and testing workflow. *(Correction: The `README.md` update failed due to a persistent tooling issue, but the steps are recorded in our chat history).*

## Recent Changes

-   **`firebase.json.template`:** Updated to include the necessary `functions` and `emulators` configurations for local development.
-   **`lib/main.dart`:** Modified to correctly initialize and connect to Firebase emulators during development builds.
-   **`functions/src/index.ts`:** Implemented the `sendFollowerPush` and `fanOutBroadcast` functions using Firebase Functions v2 syntax.
-   **`functions/src/test/index.test.ts`:** Created a robust testing suite that properly mocks the Firebase Admin SDK for isolated unit tests.

## Next Steps

1.  **Begin Phase 2.4 (Cloud Functions - AI Prep):**
    -   Scaffold `generateCaption`, `getRecipeSnippet`, and `vectorSearchFAQ` functions with placeholder/dummy return values.
    -   Configure a new environment variable for the OpenAI API key, but leave the feature flag disabled until Phase 4.
2.  **Move to Phase 3 (Interface Layer):**
    -   Once Phase 2 is fully complete, we will begin building the user-facing widgets and screens.

## Blockers

_All previous blockers resolved._

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

