# MarketSnap Lite – Refined Concept (v3)

*Updated: June 24, 2025*

## 1 · Purpose ✦ “Come‑Buy‑Now” Snapshots & Clips
Farmers‑market vendors lose sales to **poor reach, patchy signal, and limited time** at the stall.  
MarketSnap Lite gives them a **one‑tap, offline‑first “fresh‑stock” snap or 5‑second clip** that syncs the moment a connection returns, pushing shoppers to act before produce spoils.

## 2 · Product Tenets
1. **Offline‑First > 5G Glamour** – Reliability beats fancy AR in rural tents.  
2. **Ephemeral = Urgent** – 24 h auto‑delete keeps feeds clean and motivates buyers.  
3. **Bandwidth‑Kind** – Photos ≤ 200 kB; **5‑sec videos ≤ 1 MB (auto‑compressed)**.  
4. **Privacy Minimalism** – Vendor‑toggled coarse location; no shopper GPS.  
5. **AI as Sidekick** – AI captions & recipe tidbits appear only when core flow is rock‑solid.

## 3 · Feature Roadmap (Build Order)

| Build Day | Feature | User Value | Notes & Dependencies |
|:--|:--|:--|:--|
| **D1** | **Phone / Email Auth + Vendor Profile** | Quick sign‑in & basic stall info | Firebase Auth; Firestore (offline cache) |
| **D1–2** | **Offline Snap & 5‑Sec Video Queue** | Post photos **or 5‑sec clips** even offline | Flutter `camera` / `image_picker`; `video_player`; `flutter_video_compress`; Hive/Drift queue; WorkManager retry |
| **D2** | **Sync + Push Ping** | Shoppers notified the moment media uploads | Cloud Storage upload; FCM; background task checks |
| **D2–3** | **Ephemeral Story Reel** | 24‑h carousel per vendor (photos + clips) | Firestore collection with TTL index |
| **D3** | **Low‑Bandwidth Filters** | Warm / Cool / Contrast LUTs for photos & clips | On‑device shaders; no network hits |
| **D3–4** | **Follower Feed** | Latest thumbnail tiles (<3 per vendor) | Cached query → diff update |
| **D4** | **Vendor Broadcast Text** | “5 baskets left, $3 ea!” 6‑h expiry | Cloud Functions fan‑out text only |
| **D4–5** | **Coarse Location Tag** | Shoppers sort vendors by market | Opt‑in toggle; rounded lat/long (~0.1°) |
| **D5 (Polish)** | **Settings & Help** | Toggle location, video‑auto‑compress, support link | Simple Settings page |
| **D6–7 (Phase 2)** | **AI Caption Helper** | One‑tap catchy wording (<2 s) | GPT‑4 + prompt; runs after upload |
|  | **AI Recipe & FAQ Snippets** | Extra engagement | Vector DB over vendor FAQs & recipe corpus |

> **Guardrails**  
> • Videos capped at 5 seconds and ≤ 1 MB after compression (G2P2 requirement).  
> • No payments, inventory countdowns, or analytics dashboards in MVP.  
> • Log sync latency & crash metrics via Firebase Perf & Crashlytics.

## 4 · Tech Stack Snapshot
- **Frontend:** Flutter 3 (Dart)  
- **Local Queue:** Hive or Drift (encrypted)  
- **Background Sync:** `workmanager`  
- **Backend:** Firebase Auth · Firestore · Storage · Cloud Functions · FCM  
- **Monitoring:** Firebase Performance (<3 s median sync) · Crashlytics  

## 5 · Next Steps
1. Validate ordered roadmap with 2 pilot vendors (5‑min call).  
2. Break each feature into tasks → GitHub Issues.  
3. Draft detailed PRD based on this document.  
