# MVP Development Checklist – MarketSnap Lite
*Generated June 24, 2025*

---

## Template Overview
This checklist breaks the MVP into four engineering phases. Complete every sub‑item in strict order; each sub‑item is an **independent, testable task** for your AI pair‑programmer.

### Phases Overview
- [X] **Phase 1:** Foundation  
- [X] **Phase 2:** Data Layer  
- [ ] **Phase 3:** Interface Layer  
- [ ] **Phase 4:** Implementation Layer  

Legend:  
`[ ]` Not Started `[~]` In Progress `[X]` Completed `[!]` Blocked  

---

## Phase 1 – Foundation  
**Criteria:** Essential build & tooling tasks with zero external dependencies.

- [X] **1. Flutter Project Bootstrap**
  - [X] Initialise Flutter 3 project with null‑safety enabled.
  - [X] Add core packages: `firebase_core`, `firebase_auth`, `cloud_firestore`, `firebase_storage`, `firebase_messaging`, `workmanager`, `hive`, `path_provider`, `image_picker`, `camera`, `video_player`, `video_compress`.
  - [X] Configure Android & iOS Firebase SDKs with staging project IDs.
  - [X] **Enable Google Auth as optional sign-in method in Firebase Auth and app UI.** ✅ Google sign-in is now available in the authentication dialog for dev and production.

- [X] **2. Local Data Stores**
  - [X] Create Hive boxes for `pendingMediaQueue` and `userSettings`.
  - [X] Implement encryption key generation & storage in secure storage.
  - [X] Write baseline unit test: enqueue/dequeue survives hot restart.

- [X] **3. WorkManager Jobs**
  - [X] Register background sync job (`SyncPendingMediaTask`).
  - [X] Configure exponential back‑off policy.
  - [X] Add unit test: task executes when connectivity changes. (Manual verification required on iOS; see README)

- [X] **4. Static Asset Pipeline**
  - [X] Add warm/cool/contrast LUT PNGs to asset bundle.
  - [X] Verify build size stays < 50 MB release APK/IPA.
  - [X] CI step: fail build if assets exceed limit.


---

## Phase 2 – Data Layer  
**Criteria:** Schemas, rules & serverless endpoints. *Depends on Phase 1.*

- [X] **1. Firestore Schema & Security**
  - [X] Define collections: `vendors`, `snaps`, `broadcasts`, `followers` with indexes.
  - [X] Write Firebase rules restricting each document to `request.auth.uid` vendor.
  - [X] Add emulator test verifying unauthenticated write is rejected.

- [X] **2. Storage Buckets**
  - [X] Create `/vendors/{uid}/snaps/` bucket path policy (max 1 MB object).
  - [X] Configure TTL lifecycle rule (30 days hard delete).

- [X] **3. Cloud Functions (Core)**
  - [X] `sendFollowerPush` – on `snaps` create → FCM multicast.
  - [X] `fanOutBroadcast` – on `broadcasts` create → FCM.
  - [X] Unit tests with Firebase Functions Test SDK.

- [X] **4. Cloud Functions (AI Phase 2 Prep)**
  - [X] Scaffold `generateCaption`, `getRecipeSnippet`, `vectorSearchFAQ` with dummy return.
  - [X] Environment var for OpenAI key; leave disabled flag until Phase 4.

- [X] **5. Messages & Notifications**
  - [X] Define `messages` collection with 24 h TTL composite index.
  - [X] Firestore security rules: only `fromUid` and `toUid` may read/write.
  - [X] Cloud Function `sendMessageNotification` – on new `messages` doc → FCM to recipient.


---

## Phase 3 – Interface Layer  
**Criteria:** All user‑facing widgets & navigation. *Depends on Phases 1 & 2.*

- [X] **1. Auth & Profile Screens**
  - [X] Phone/email OTP flow using `firebase_auth`. ✅ **COMPLETED** - Full cross-platform authentication implemented with Firebase emulator support.
  - [X] Profile form: stall name, market city, avatar upload. ✅ **COMPLETED** - Full vendor profile form with MarketSnap design system, avatar upload via camera/gallery, offline-first storage, and Firebase sync.
  - [X] Validate offline caching of profile in Hive. ✅ **COMPLETED** - Comprehensive test suite validates profile persistence, sync status tracking, completeness validation, and cross-restart data integrity.

- [X] **2. Capture & Review UI**
  - [X] Camera preview with photo shutter. ✅ **COMPLETED** - Full camera preview with photo capture, cross-platform support, flash controls, camera switching, and modern UI.
  - [X] 5‑sec video record button with live countdown. ✅ **COMPLETED** - Full video recording with 5-second auto-stop, live countdown display, cross-platform support, and simulator mode compatibility.
  - [X] Review screen → apply LUT filter → "Post" button. ✅ **COMPLETED** - Full media review screen with LUT filter application (warm, cool, contrast), caption input, and post functionality. Integrates with Hive queue for background upload.

- [X] **3. Story Reel & Feed**
  - [X] Horizontal story carousel per vendor with 24 h TTL badge.
  - [X] Vertical feed showing latest three snaps per followed vendor.
  - [X] Thumbnail placeholder until media downloads completes.

- [X] **4. Settings & Help**
  - [X] Toggles: coarse location, auto‑compress video, save‑to‑device default.
  - [X] External link to support email.
  - [X] Display free‑storage indicator (≥ 100 MB check).

- [X] **5. Messaging UI**
  - [X] Conversation list showing recent chats (24 h TTL badge).
  - [X] Chat screen with send/receive bubbles and read indicator.
  - [X] Deep-link from push notification to open chat thread.


---

## Phase 4 – Implementation Layer  
**Criteria:** Business logic & AI value. *Depends on all prior phases.*

- [~] **1. Offline Media Queue Logic** ⚠️ **CORE COMPLETE, AUTH PERSISTENCE BLOCKED**
  - [X] Serialize photo/video + metadata into Hive queue. ✅ **DONE** - PendingMediaItem model with all fields
  - [X] WorkManager uploads when network available; writes `snaps` doc + Storage file. ✅ **DONE** - Background sync with Firebase
  - [X] Delete queue item on 200 response; retry on failure. ✅ **DONE** - Comprehensive error handling
  - [X] **ENHANCEMENT**: Smart posting flow with connectivity monitoring ✅ **ADDED** - 10s timeout online, instant queue offline
  - [!] **BLOCKED**: Offline authentication persistence - Firebase Auth interface compatibility issue

- [ ] **2. Push Notification Flow**
  - [ ] Request FCM permissions; save token in `followers` sub‑coll.
  - [ ] On message click, deep‑link to snap/story.
  - [ ] Fallback in‑app banner if system push disabled.

- [ ] **3. Broadcast Text & Location Tagging**
  - [ ] UI modal to send ≤ 100 char broadcast; write to Firestore.
  - [ ] Implement coarse location rounding (0.1°) before upload.
  - [ ] Filter feed by distance if location data present.

- [ ] **4. Save‑to‑Device**
  - [ ] Persist posted media to OS gallery via `image_gallery_saver`.
  - [ ] Check free space ≥ 100 MB else show toast error.
  - [ ] Unit test: saved file survives app uninstall.

- [ ] **5. AI Caption Helper (Phase 2)**
  - [ ] Call `generateCaption` CF; display spinner max 2 s.
  - [ ] Allow vendor edit before final post.
  - [ ] Cache caption keyed by media hash.

- [ ] **6. Recipe & FAQ Snippets (Phase 2)**
  - [ ] Vectorize vendor FAQ chunks → `faqVectors` via CF batch job.
  - [ ] On snap view, call `getRecipeSnippet` for produce keyword.
  - [ ] Render collapsible FAQ card below story.

- [ ] **7. Ephemeral Messaging Logic**
  - [ ] Message send service → write to `messages` + trigger push.
  - [ ] TTL cleanup via Firestore TTL index or scheduled CF.
  - [ ] Unit test: conversation auto-deletes after 24 h.


---

### Implementation Rules
- **Feature Independence:** each sub‑task is self‑contained, rollback‑safe, and unit‑tested.  
- **Parallelism:** Phase 1 first; Phases 2 & 3 can overlap; Phase 4 starts after Phase 1 complete.  
- **Status Markers:** `[ ]` Not Started  /   `[~]` In Progress  /   `[X]` Completed  /   `[!]` Blocked.

---

Copy this markdown into your tracker and tick items as you go. Happy building!

> **Note:**
> - Android: Background sync is fully functional and can be verified in-app.
> - iOS: Background sync is functional, but due to iOS platform limitations, execution must be verified via console logs. See the README for details.