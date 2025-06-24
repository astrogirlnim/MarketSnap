# MarketSnap Design System

> **Inspiration:** Snapchat’s playful minimalism + farmers‑market warmth.

## Brand Identity
MarketSnap captures the cheerful, community‑driven vibe of open‑air markets. Visuals feel **fresh, friendly, and ephemeral**—snaps disappear, produce sells out.

### Core Principles
- **Fresh & Friendly** – Soft produce colours, rounded corners, smile‑forward iconography.
- **Quick & Light** – Interfaces load fast on rural networks; minimal gradients; bold CTAs.
- **Ephemeral** – Story rings, fading backgrounds, subtle timers echo Snapchat UX.
- **Accessible Outdoors** – High contrast under sunlight; large touch targets for gloved hands.
- **Offline‑First** – Visual cues for “queued” vs “synced” match low‑connectivity reality.

---

## Color Palette
| Role | Light | Dark | Notes |
|------|-------|------|-------|
| **Primary CTA** | **Market Blue** `#007AFF` | `#4D9DFF` | Mirrors Snapchat blue send button but tuned brighter for sunlight.
| **Secondary CTA** | **Harvest Orange** `#FF9500` | `#FFAD33` | Echoes produce tones (carrots, pumpkins).
| **Accent / Success** | **Leaf Green** `#34C759` | `#66D98A` | Indicates upload success, in‑stock.
| **Warning** | **Sunset Amber** `#FFCC00` | `#FFD633` | Low stock, queued items.
| **Error** | **Apple Red** `#FF3B30` | `#FF665C` | Failed upload, validation error.
| **Background** | **Cornsilk** `#FFF6D9` | `#1E1E1E` | Sample login screen bg.
| **Surface** | **Eggshell** `#FFFCEA` | `#2A2A2A` | Card & input backgrounds.
| **Outline** | **Seed Brown** `#C8B185` | `#3F3F3F` | Borders for secondary buttons.
| **Text Primary** | **Soil Charcoal** `#3C3C3C` | `#F2F2F2` | AA 4.5:1 contrast.
| **Text Secondary** | **Soil Taupe** `#6E6E6E` | `#BDBDBD` | Labels, captions.

> **Contrast Check:** All text/background combos ≥ 4.5 : 1.

---

## Typography
| Style | Size | Weight | Usage |
|-------|------|--------|-------|
| **Display** | 32/38 | 800 | Hero headlines (e.g., “Share your fresh finds”) |
| **H1** | 28/34 | 700 | Section titles |
| **H2** | 24/30 | 600 | Card titles, dialog headers |
| **Body‑LG** | 18/26 | 500 | Descriptive copy |
| **Body** | 16/24 | 400 | Default text |
| **Caption** | 12/16 | 500 | Metadata, timestamps |
| **Label** | 11/14 | 600 | Input labels |

**Font stack:** Inter → Roboto → system sans‑serif (fast download, matches Snapchat’s system‑font approach).

---

## Spacing Scale (4 px grid)
`xs` 4 | `sm` 8 | `md` 16 | `lg` 24 | `xl` 32 | `2xl` 48

---

## Iconography
- **Line weight:** 2 px, rounded joins (Snapchat style).
- **Theme:** Produce (tomato, carrot), baskets, smiley faces.
- **Status:** ✔︎ queue success (green), ⟳ syncing (amber), ✕ failed (red).

---

## Motion Guidelines
- **Snap‑In (150 ms):** Fade‑up for modals & toasts.
- **Queue Pulse (1 s loop):** Amber border pulses on queued cards.
- **Story Ring Sweep (300 ms):** Circular wipe mimics Snapchat stories.

---

## Accessibility
- Minimum touch target **48 × 48 px**.
- Large CTAs positioned thumb‑reach friendly (Snapchat bottom zone).
- Offline/low‑connectivity state icons include text for colour‑blind users.

---

## Dark Mode
Apply `dark:` variants of colours above. Avoid pure black; use **#1E1E1E** to reduce glare. Surface backgrounds use subtle produce illustrations at 3 % opacity for brand texture.

