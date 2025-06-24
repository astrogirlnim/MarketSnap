# Tech Context – "With What"

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

