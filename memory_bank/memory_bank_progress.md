# Progress Log

*Last Updated: June 24, 2025*

---

## What Works

-   **Phase 1 - Foundation:**
    -   Flutter project created and all core dependencies are installed.
    -   Firebase SDKs are configured for both Android and iOS.
    -   Local data stores (Hive) and background job framework (WorkManager) are in place.

-   **Phase 2 - Data Layer (In Progress):**
    -   **Firestore Schema & Security:** The database schema (`vendors`, `snaps`, `broadcasts`, `followers`) is defined. Security rules and indexes have been implemented and tested with the local emulator. Unauthenticated writes are successfully blocked.
    -   **Storage Security:** Cloud Storage security rules are in place, restricting uploads to authenticated users and enforcing a 1MB file size limit.
    -   **Cloud Functions Setup:** The Cloud Functions project has been initialized with TypeScript and ESLint. The default code has been cleaned, and the project compiles successfully.
    -   **Local Emulator Environment:** The full Firebase Emulator Suite (Auth, Firestore, Functions, Storage) is configured and runs correctly, providing a complete local backend for development and testing.

## What's Left to Build

-   **Phase 2 - Data Layer:**
    -   Implement the 30-day TTL lifecycle rule for Cloud Storage objects.
    -   Develop the core Cloud Functions (`sendFollowerPush`, `fanOutBroadcast`).

-   **Phase 3 - Interface Layer:**
    -   All UI screens and user flows, including Auth, Profile, Media Capture, and Feeds.

-   **Phase 4 - Implementation Layer:**
    -   All business logic connecting the UI to the backend, including the offline media queue and AI helper features.

## Known Issues & Blockers

-   **Node.js Version:** The `functions` project was initialized for Node.js v22 but the host environment is v20. This has been corrected in `package.json`, but serves as a reminder to ensure environment consistency.
-   **iOS Background Sync:** As noted in the `README.md`, testing background sync on iOS requires manual verification via console logs due to platform limitations.

## Completed
- **Phase 1: Foundation**
  - [X] 1.1: Flutter Project Bootstrap
  - [X] 1.2: Local Data Stores (Hive)
  - [X] 1.3: WorkManager Jobs for Background Sync
  - [X] 1.4: Static Asset Pipeline
- Project Brief, Product Context, System & Tech docs drafted.
- Detailed PRD v1.1 delivered.
- MVP checklist (list format) saved.

## In Progress
- None

## To Do
- **Phase 2: Data Layer**
  - [ ] 2.1: Firestore Schema & Security
  - [ ] 2.2: Storage Buckets
  - [ ] 2.3: Cloud Functions (Core)
  - [ ] 2.4: Cloud Functions (AI Phase 2 Prep)
- **Phase 3: Interface Layer**
- **Phase 4: Implementation Layer**

## Known Issues / Risks
- Video compression performance on older devices not yet profiled.
- Vector DB cost evaluation pending provider selection.

