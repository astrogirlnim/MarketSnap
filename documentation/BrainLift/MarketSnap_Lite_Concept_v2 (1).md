# MarketSnap Lite – Refined Concept (v2)

*Updated: June 24, 2025*

## 1 · Purpose ✦ “Come‑Buy‑Now” Snapshots
Farmers‑market vendors lose sales to **poor reach, patchy signal, and limited time** at the stall.  
MarketSnap Lite gives them a **one‑tap, offline‑first “fresh‑stock” snap** that syncs the moment a connection returns, pushing shoppers to act before produce spoils.

## 2 · Product Tenets
1. **Offline‑First > 5G Glamour** – Reliability beats fancy AR in rural tents.  
2. **Ephemeral = Urgent** – 24 h auto‑delete keeps feeds clean and motivates buyers.  
3. **Bandwidth‑Kind** – Tiny photo payloads ➜ ≤ 200 kB; 5‑sec clips optional.  
4. **Privacy Minimalism** – Vendor‑toggled coarse location; no shopper GPS.  
5. **AI as Sidekick** – AI captions & recipe tidbits slip in only when core flow is rock‑solid.

## 3 · Feature Roadmap (Build Order)

| Build Day | Feature | User Value | Notes & Dependencies |
|:--|:--|:--|:--|
| **D1** | **Phone / Email Auth + Vendor Profile** | Quick sign‑in & basic stall info | Firebase Auth; Firestore (offline cache) |
| **D1–2** | **Offline Snap Queue** | Post photos even offline | Flutter `camera` + `image_picker`; Hive/Drift queue; WorkManager retry |
| **D2** | **Sync + Push Ping** | Shoppers notified the moment snaps upload | Cloud Storage upload; FCM; background task checks |
| **D2–3** | **Ephemeral Story Reel** | 24‑h carousel per vendor | Firestore collection with TTL index |
| **D3** | **Low‑Bandwidth Filters** | Warm / Cool / Contrast LUTs | On‑device shaders; no network hits |
| **D3–4** | **Follower Feed** | Latest snap preview tiles (<3 per vendor) | Cached query → diff update |
| **D4** | **Vendor Broadcast Text** | “5 bags left, $3 ea!” 6‑h expiry | Cloud Functions fan‑out text only |
| **D4–5** | **Coarse Location Tag** | Shoppers sort vendors by market | Opt‑in toggle; rounded lat/long (~0.1°) |
| **D5 (Polish)** | **Settings & Help** | Toggle location, support link | Simple Settings page |
| **D6–7 (Phase 2)** | **AI Caption Helper** | One‑tap catchy wording (<2 s) | GPT‑4 + prompt; runs after upload |
|  | **AI Recipe & FAQ Snippets** | Extra engagement | Vector DB over vendor FAQs & recipe corpus |

> **Guardrails**  
> • No payments, inventory countdowns, or analytics dashboards in MVP.  
> • Videos off by default to save data; enable once QoE proven.  
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
