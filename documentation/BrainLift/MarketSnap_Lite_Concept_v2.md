# MarketSnap Lite – Revised Concept  
*Updated June 24, 2025*

## 1. Mission

Deliver **one‑tap, offline‑first “fresh‑stock” snaps** that help farmers‑market vendors boost foot traffic and sell perishable goods quickly, even with patchy rural connectivity.

---

## 2. Core User Persona

| Attribute | Detail |
|-----------|--------|
| **Primary User** | Farmers‑market vendor (produce, baked goods, coffee roaster, etc.) |
| **Job to be Done** | Tell nearby shoppers *“I have fresh items right now—come buy!”* with < 1‑min effort |
| **Pain Points** | Poor cellular data at outdoor markets; limited time to craft social posts; inventory spoils fast |
| **Tech Comfort** | Mostly Android; modest data plans; uses basic camera apps, WhatsApp, FB Marketplace |

---

## 3. Customer Insights (Knowledge Tree highlights)

- **Patchy signal** → must work fully offline with background sync (5–15 min tolerance).  
- **Time pressure** → capture & post in ≤ 10 s; AI caption later can save further time.  
- **Awareness > Payments** → vendors just want eyeballs today; analytics/payments can wait.  
- **Privacy** → vendors opt‑in coarse (≈ 0.1°) location; shoppers keep theirs private.  
- **Ephemeral urgency** → 24 h story + 6 h broadcast chat drives FOMO and keeps storage light.

---

## 4. Design Principles (Spiky POVs)

1. **Offline‑First Beats 5G Fancy** – reliability is the killer feature.  
2. **Ephemeral by Default** – disappearing content simplifies compliance & vendor workload.  
3. **No Vanity Dashboards in MVP** – skip analytics until vendors demand it.  
4. **AI = Sidekick, Not Data Hog** – optional, on‑device or compressed calls; captions first.

---

## 5. MVP Feature Set (Phase 1 – Days 1‑3)

| # | Feature | What Users Experience | Offline Strategy |
|---|---------|----------------------|------------------|
| 1 | **Quick Auth & Profile** | Phone/e‑mail login; set stall name once | Firebase Auth + Firestore local cache |
| 2 | **Snap Capture Queue** | Photo/video (≤ 5 s) + text/price sticker; shows “Pending” badge when offline | Hive/Drift queue + WorkManager retries |
| 3 | **24‑h Vendor Story** | Followers see a story reel; clears next day | Firestore TTL + local cache |
| 4 | **Low‑Bandwidth Filters** | 3 built‑in LUT filters; no downloads | Shaders shipped with app |
| 5 | **Follower Feed & Push Ping** | Shoppers get latest 3 snaps + FCM alert on sync | Cached feed diff‑updates |
| 6 | **Broadcast Text Blast** | Vendor sends 140‑char update expiring in 6 h | Text‑only fan‑out via Cloud Function |
| 7 | **Opt‑in Coarse Location Tag** | Toggle adds “📍 Springfield Farmers Market” label | Rounded lat/long saved if enabled |

> **Stretch (only if time allows Days 2‑3)**: basic view count badge (no full analytics).

---

## 6. Deferred Features (Phase 2 – Days 4‑7)

| Feature | Rationale |
|---------|-----------|
| **AI Caption Generator** | High value wording help; low data usage (single OpenAI call) |
| **Recipe / Educational Snippets** | Engagement boost; can cache common recipes on‑device |
| **FAQ Profile Cards** | Meets shopper info needs without real‑time bot |
| **Light Analytics** | Simple views & click‑through counts if vendors ask |

---

## 7. Non‑Goals (Out of Scope for MVP)

- In‑app payments/tipping  
- Inventory auto‑countdown  
- AR lenses, face filters  
- Real‑time shopper chat bot  
- Advanced growth analytics dashboards

---

## 8. Technical Stack

| Layer | Tech | Notes |
|-------|------|-------|
| Mobile | **Flutter 3 (Dart)** | One codebase, good offline packages |
| Local DB | **Hive or Drift** | Encryptable, lightweight |
| Background Tasks | `workmanager` | Retry uploads when on unmetered or >3G |
| Backend | **Firebase** – Auth, Firestore, Storage, Functions, FCM | Offline persistence, push |
| Image Proc | `camera`, `image_picker`, LUT shaders | All on‑device |
| AI (Phase 2) | OpenAI GPT‑4o via Cloud Function proxy | Compress prompt & response |

---

## 9. Privacy & Trust

- **Default minimal data** – no shopper tracking.  
- **Location opt‑in** – coarse only; can be revoked per snap.  
- **Auto‑delete** – snaps 24 h, broadcasts 6 h; no archive stored.  
- **Encryption at Rest** – local Hive box + Firestore security rules.

---

## 10. Success Metrics

| Metric | Target |
|--------|--------|
| Offline capture latency | ≤ 1 s to save to queue |
| Sync time once online | ≤ 3 s for first snap |
| Push delivery | ≥ 95 % within 10 s after sync |
| Vendor weekly active rate | 50 % of onboarded vendors post ≥ 1 snap/week |
| Shopper engagement | Avg. 1.5 story views per shopper session |

---

## 11. High‑Level Timeline

| Day | Milestone |
|-----|-----------|
| 1 | Flutter project setup, Auth, offline DB |
| 2 | Snap capture queue, basic sync, Story playback |
| 3 | Filters, location tag, polish → **MVP ready** |
| 4‑5 | Broadcast chat, FCM, performance tuning |
| 6‑7 | AI caption prototype, internal test, cut/ship |

---

*End of document*
