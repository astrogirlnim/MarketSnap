# MVP Development Checklist – MarketSnap Lite
*Generated June 24, 2025*

---

## Template Overview
This checklist breaks the MVP into four engineering phases. Complete every sub‑item in strict order; each sub‑item is an **independent, testable task** for your AI pair‑programmer.

### Phases Overview
- [X] **Phase 1:** Foundation  
- [ ] **Phase 2:** Data Layer  
- [ ] **Phase 3:** Interface Layer  
- [ ] **Phase 4:** Implementation Layer  

Legend:  
`[ ]` Not Started `[~]` In Progress `[X]` Completed `[!]` Blocked  

---

## Phase 1 – Foundation  
**Criteria:** Essential build & tooling tasks with zero external dependencies.

- [X] **1. Flutter Project Bootstrap**
  - [X] Initialise Flutter 3 project with null‑safety enabled.
  - [X] Add core packages: `firebase_core`, `firebase_auth`, `cloud_firestore`, `firebase_storage`, `firebase_messaging`, `workmanager`, `hive`, `path_provider`, `image_picker`, `camera`, `video_player`, `video_compress`.
  - [X] Configure Android & iOS Firebase SDKs with staging project IDs.

- [X] **2. Local Data Stores**
  - [X] Create Hive boxes for `pendingMediaQueue` and `userSettings`.
  - [X] Implement encryption key generation & storage in secure storage.
  - [X] Write baseline unit test: enqueue/dequeue survives hot restart.

- [X] **3. WorkManager Jobs**
  - [X] Register background sync job (`SyncPendingMediaTask`).
  - [X] Configure exponential back‑off policy.
  - [X] Add unit test: task executes when connectivity changes.

- [ ] **4. Static Asset Pipeline**
  - [ ] Add warm/cool/contrast LUT PNGs to asset bundle.
  - [ ] Verify build size stays < 50 MB release APK/IPA.
  - [ ] CI step: fail build if assets exceed limit.


---

## Phase 2 – Data Layer  
**Criteria:** Schemas, rules & serverless endpoints. *Depends on Phase 1.*

- [ ] **1. Firestore Schema & Security**
  - [ ] Define collections: `vendors`, `snaps`, `broadcasts`, `followers` with indexes.
  - [ ] Write Firebase rules restricting each document to `request.auth.uid` vendor.
  - [ ] Add emulator test verifying unauthenticated write is rejected.

- [ ] **2. Storage Buckets**
  - [ ] Create `/vendors/{uid}/snaps/` bucket path policy (max 1 MB object).
  - [ ] Configure TTL lifecycle rule (30 days hard delete).

- [ ] **3. Cloud Functions (Core)**
  - [ ] `sendFollowerPush` – on `snaps` create → FCM multicast.
  - [ ] `fanOutBroadcast` – on `broadcasts` create → FCM.
  - [ ] Unit tests with Firebase Functions Test SDK.

- [ ] **4. Cloud Functions (AI Phase 2 Prep)**
  - [ ] Scaffold `generateCaption`, `getRecipeSnippet`, `vectorSearchFAQ` with dummy return.
  - [ ] Environment var for OpenAI key; leave disabled flag until Phase 4.


---

## Phase 3 – Interface Layer  
**Criteria:** All user‑facing widgets & navigation. *Depends on Phases 1 & 2.*

- [ ] **1. Auth & Profile Screens**
  - [ ] Phone/email OTP flow using `firebase_auth`.
  - [ ] Profile form: stall name, market city, avatar upload.
  - [ ] Validate offline caching of profile in Hive.

- [ ] **2. Capture & Review UI**
  - [ ] Camera preview with photo shutter.
  - [ ] 5‑sec video record button with live countdown.
  - [ ] Review screen → apply LUT filter → "Post" button.

- [ ] **3. Story Reel & Feed**
  - [ ] Horizontal story carousel per vendor with 24 h TTL badge.
  - [ ] Vertical feed showing latest three snaps per followed vendor.
  - [ ] Thumbnail placeholder until media downloads completes.

- [ ] **4. Settings & Help**
  - [ ] Toggles: coarse location, auto‑compress video, save‑to‑device default.
  - [ ] External link to support email.
  - [ ] Display free‑storage indicator (≥ 100 MB check).


---

## Phase 4 – Implementation Layer  
**Criteria:** Business logic & AI value. *Depends on all prior phases.*

- [ ] **1. Offline Media Queue Logic**
  - [ ] Serialize photo/video + metadata into Hive queue.
  - [ ] WorkManager uploads when network available; writes `snaps` doc + Storage file.
  - [ ] Delete queue item on 200 response; retry on failure.

- [ ] **2. Push Notification Flow**
  - [ ] Request FCM permissions; save token in `followers` sub‑coll.
  - [ ] On message click, deep‑link to snap/story.
  - [ ] Fallback in‑app banner if system push disabled.

- [ ] **3. Broadcast Text & Location Tagging**
  - [ ] UI modal to send ≤ 100 char broadcast; write to Firestore.
  - [ ] Implement coarse location rounding (0.1°) before upload.
  - [ ] Filter feed by distance if location data present.

- [ ] **4. Save‑to‑Device**
  - [ ] Persist posted media to OS gallery via `image_gallery_saver`.
  - [ ] Check free space ≥ 100 MB else show toast error.
  - [ ] Unit test: saved file survives app uninstall.

- [ ] **5. AI Caption Helper (Phase 2)**
  - [ ] Call `generateCaption` CF; display spinner max 2 s.
  - [ ] Allow vendor edit before final post.
  - [ ] Cache caption keyed by media hash.

- [ ] **6. Recipe & FAQ Snippets (Phase 2)**
  - [ ] Vectorize vendor FAQ chunks → `faqVectors` via CF batch job.
  - [ ] On snap view, call `getRecipeSnippet` for produce keyword.
  - [ ] Render collapsible FAQ card below story.


---

### Implementation Rules
- **Feature Independence:** each sub‑task is self‑contained, rollback‑safe, and unit‑tested.  
- **Parallelism:** Phase 1 first; Phases 2 & 3 can overlap; Phase 4 starts after Phase 1 complete.  
- **Status Markers:** `[ ]` Not Started  /  `[~]` In Progress  /  `[X]` Completed  /  `[!]` Blocked.

---

Copy this markdown into your tracker and tick items as you go. Happy building!