# System Patterns – "How"

## High‑Level Architecture

```
Flutter App ─ Hive Queue ─ WorkManager → Firebase Storage
                             ↓              ↓
                          Firestore ← Cloud Functions → FCM
                                             ↓
                                 (Phase 2) pgvector + GPT‑4
```

### Key Patterns

- **Offline‑First Queue:** Local Hive box holds media until WorkManager detects acceptable network.
- **Idempotent Uploads:** Each queue item carries UUID; Cloud Function ignores duplicates.
- **TTL‑Based Ephemerality:** `expiresAt` field + Firestore index + scheduled CF cleanup.
- **Fan‑Out Push:** On snap create, `sendFollowerPush` multicasts to FCM tokens stored in `followers` sub‑collection.
- **Feature Flags:** Phase 2 AI endpoints behind remote‑config switch.

## Design Decisions

- **Flutter 3** for single codebase; avoids React Native install size.
- **Hive + Drift** chosen for speed and encryption vs. SQLite.
- **pgvector micro instance** satisfies vector search under budget; fallback Annoy in‑memory.

