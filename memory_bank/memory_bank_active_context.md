# Active Context

*Last Updated: June 25, 2025*

---

## Current Focus

We have successfully completed **Phase 3.1.1: Authentication Flow**. The phone/email OTP authentication flow is now fully implemented, tested, and working correctly with Firebase Auth and emulator support.

### ✅ Phase 3.1.1 Complete - Recent Achievements:

-   **Authentication Service:** Comprehensive `AuthService` class implementing both phone and email authentication flows with Firebase Auth.
-   **Phone Authentication:** Complete phone number verification with SMS OTP flow, supporting international numbers and auto-verification.
-   **Email Authentication:** Magic link email authentication as an alternative to phone authentication.
-   **Authentication Screens:** Beautiful, modern UI screens for welcome, phone entry, OTP verification, and email authentication.
-   **Auth State Management:** Integrated `StreamBuilder` with Firebase Auth state changes for automatic routing between authenticated and non-authenticated states.
-   **Cross-platform Support:** Works on both iOS and Android with proper permissions and emulator integration.
-   **Firebase Emulator Integration:** Full support for local testing with Firebase Auth emulator.
-   **Error Handling:** Comprehensive error mapping and user-friendly error messages.
-   **Modern UI:** Material 3 design system with responsive layouts and accessibility considerations.

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

