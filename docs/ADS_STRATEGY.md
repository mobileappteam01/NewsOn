# NewsOn — Google Ads strategy

## Ad types in use

| Type | Format | Purpose |
|------|--------|---------|
| **Anchored adaptive banner** | Bottom of main tabs | Always-visible, high fill rate, does not interrupt reading |
| **Medium rectangle (MREC)** | In-feed between stories | Strong eCPM while user scrolls |
| **Interstitial** | Full screen on natural exit | High revenue only after engagement |

## Placements

- **Home Today tab** — section banner between Breaking News and Today News (toggle via `home_section_banner_enabled`)
- **Today feed** — MREC every 5 articles (configurable)
- **Category feed** — same interval
- **For You** — MREC after each spotlight block (mosaic + grid)
- **Search results** — MREC every 5 results
- **Bookmarks** — bottom banner only (no home anchor on this tab)
- **Article detail** — interstitial when leaving after reading (frequency-capped)

## UX rules (built into code)

- No interstitials on tab switch or app open
- Interstitial: min **120s** between shows, min **2** articles read, max **4** per session
- All in-feed units use a **Sponsored** label
- Failed ads collapse to zero height (no empty boxes)

## Firebase tuning (`ads_config` in Realtime Database)

```json
{
  "enabled": true,
  "inline_interval": 5,
  "anchor_banner_enabled": true,
  "interstitial_enabled": true,
  "interstitial_min_seconds": 120,
  "interstitial_min_articles_read": 2,
  "interstitial_max_per_session": 4,
  "for_you_block_ads_enabled": true,
  "search_inline_enabled": true,
  "bookmarks_anchor_enabled": true,
  "home_section_banner_enabled": true
}
```

## Ad unit IDs (Firebase Realtime Database)

**Required — three different AdMob units per platform:**

| RTDB key | AdMob format to create |
|----------|------------------------|
| `android_banner_ad_id` | Banner (or Anchored adaptive) |
| `android_medium_ad_id` | Medium rectangle (300×250) |
| `android_interstitial_ad_id` | Interstitial |
| `ios_banner_ad_id` | Banner |
| `ios_medium_ad_id` | Medium rectangle |
| `ios_interstitial_ad_id` | Interstitial |

**Do not** use the same unit ID for all three. That causes:

- `Ad unit doesn't match format` on interstitials
- `No fill` on banners/MREC

### Development vs live ads

- **Live Firebase unit IDs are used in all builds** (debug, profile, release) when:
  - `ads_config.use_test_ads` is `false` (default), and
  - Banner, medium, and interstitial IDs are **three different** values in Realtime Database.
- Set `"use_test_ads": true` in `ads_config` only when you intentionally want Google test creatives.
- If all three RTDB keys share the same ID, the app falls back to test units (AdMob rejects mixed formats).

### Example `ads_config`

```json
{
  "enabled": true,
  "use_test_ads": false,
  "inline_interval": 5,
  "anchor_banner_enabled": true,
  "interstitial_enabled": true,
  "interstitial_min_seconds": 120,
  "interstitial_min_articles_read": 2,
  "interstitial_max_per_session": 4,
  "home_section_banner_enabled": true
}
```

## Revenue tips for the client

1. Enable **mediation** in AdMob (Meta, Unity, etc.)
2. Set eCPM floors per country after 2–4 weeks of data
3. Keep `inline_interval` at 5–6 for news apps; below 4 hurts retention
4. Monitor **CTR** and **session length** in AdMob + Firebase Analytics
