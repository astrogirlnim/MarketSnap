
# MarketSnap Lite – Offline‑Friendly Snapchat for Local Vendors

## Project Overview
A lightweight, vendor‑centric Snapchat‑style app designed for farmers‑market sellers with unreliable connectivity. Vendors capture “fresh‑stock” snaps that sync when online; shoppers receive timely, disappearing updates.

## Core Feature Set

| # | Feature | User Benefit | Offline‑friendly Implementation |
|---|---------|--------------|---------------------------------|
| 1 | **Lightweight Auth & Vendor Profile** | Simple sign‑in; one‑screen profile | Firebase Auth + Firestore offline persistence |
| 2 | **Offline Snap Capture Queue** | Post photos/videos even when offline | Local queue (Hive/Drift); WorkManager retries uploads |
| 3 | **Ephemeral Vendor Stories** | 24‑hour story reel | Firestore collection with TTL; cached locally |
| 4 | **Low‑Bandwidth Filters** | On‑device color LUT filters | Pre‑packaged shaders, no network |
| 5 | **Follower Feed & Push Pings** | Shoppers see latest snaps, get push alerts | Cached feed + FCM |
| 6 | **Vendor Broadcast Chat** | Time‑boxed text updates | Text‑only fan‑out via Cloud Functions |
| 7 | **Opt‑in Location Tags** | Optional coarse location on snaps | Rounded lat/long stored only if enabled |

## Tech Stack

| Layer | Choice | Reason |
|-------|--------|--------|
| Frontend | **Flutter 3** | Cross‑platform, rich camera APIs |
| Local DB | **Hive / Drift** | Lightweight, offline, encryptable |
| Background Sync | `workmanager` | Reliable retry |
| Backend | **Firebase** (Auth, Firestore, Storage, Functions, FCM) | Offline cache, media upload, push |
| Analytics | Firebase Performance & Crashlytics | Measure <3 s sync, stability |

## Phase Plan

- **Phase 1 (Core, Days 1‑3):** Implement features 1‑5, basic UI polish.
- **Phase 2 (Polish, Days 4‑5):** Add features 6‑7, performance tuning.
- **Phase 3 (AI Extras, Days 6‑7):** Optional RAG-powered captions, recipe ideas, FAQ bot.

## Privacy Constraints

- Location sharing is strictly opt‑in; coarse (≈0.1°) coordinates only.
- No personal data exposed publicly; snaps auto‑expire (24 h) and chats (6 h).

---

*Created June 23 2025.*
