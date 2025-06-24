# Tech Context

*Last Updated: June 24, 2025*

---

## Core Technologies

-   **Mobile Framework:** Flutter 3
-   **Backend:** Firebase
-   **Language (Client):** Dart 3 (with null-safety)
-   **Language (Backend):** TypeScript (for Cloud Functions)

## Key Libraries & Packages

-   **Firebase Suite:**
    -   `firebase_core`: Core Firebase integration.
    -   `firebase_auth`: User authentication.
    -   `cloud_firestore`: Database.
    -   `firebase_storage`: File storage.
    -   `firebase_messaging`: Push notifications.
    -   `firebase_functions`: For calling backend functions.
-   **Local State & Storage:**
    -   `hive` / `hive_flutter`: Fast key-value database for offline caching.
    -   `flutter_secure_storage`: For storing encryption keys and sensitive data.
-   **Background Processing:**
    -   `workmanager`: To manage background sync tasks on Android & iOS.
-   **Media:**
    -   `image_picker`, `camera`: For capturing photos.
    -   `video_player`, `video_compress`: For capturing and compressing videos.

## Development & Tooling

-   **Version Control:** Git, hosted on GitHub.
-   **Package Manager (Client):** `pub` (via Flutter SDK).
-   **Package Manager (Backend):** `npm`.
-   **Local Backend:** **Firebase Emulator Suite** is a critical part of our workflow. We use it to run local instances of Auth, Firestore, Storage, and Functions.
    -   **Command:** `firebase emulators:start`
    -   **Emulator UI:** `http://localhost:4000`
-   **Node.js Version:** The Cloud Functions environment is configured to use **Node.js v20**.
-   **CI/CD:** GitHub Actions (defined in `.github/workflows/deploy.yml`).
    -   **Authentication:** The deployment pipeline authenticates to Firebase using a `FIREBASE_SERVICE_ACCOUNT_KEY` stored in GitHub Secrets.
    -   **Validation Jobs:** For pull request checks, the pipeline generates a *dummy* `firebase_options.dart` file to allow `flutter analyze` to pass without requiring real credentials, ensuring security and speed.

| Layer | Technology | Notes |
|-------|------------|-------|
| **Frontend** | Flutter 3 (Dart 3) | Null‑safety, Material 3.
| **State** | Riverpod 2 | Light‑weight, testable.
| **Local DB** | Hive + Drift | Encryption, typed boxes.
| **Background Tasks** | WorkManager | Android + iOS compatible.
| **Backend BaaS** | Firebase (Auth, Firestore, Storage, Functions, FCM) | Offline persistence built‑in.
| **AI** | OpenAI GPT‑4 (via Functions) | 2 s latency target.
| **Vector DB** | pgvector on Neon free tier | ≤ US$7 / mo.
| **CI/CD** | GitHub Actions → Flutter build, Firebase Hosting preview.
| **Monitoring** | Firebase Performance, Crashlytics | Alert if sync > 3 s.

