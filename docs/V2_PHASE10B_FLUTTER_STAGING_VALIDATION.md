# NewsOn Phase 10B — Flutter ↔ Staging Backend Integration Validation

**Date:** 2026-09-16  
**Mode:** Validation-first. Backend code not modified. Production V2 flags not enabled.  
**Staging target:** `http://127.0.0.1:8010` (Phase 10A local V2-capable process)

---

## A. Staging URL / configuration used

**Status: ✅ VERIFIED**

| Mechanism | Detail |
|-----------|--------|
| Staging base | `http://127.0.0.1:8010` (health 200; Redis disabled) |
| Flutter production path | Firebase RTDB `ipAddress` → `ApiService` (unchanged) |
| Safe staging override | `--dart-define=NEWSON_API_BASE_URL=http://127.0.0.1:8010` via `ApiService` / `main.dart` (does **not** write Firebase) |
| Production API | Not permanently retargeted |

---

## B. Search real API result

**Status: ✅ VERIFIED** (live staging + Flutter mapper)

| Case | Result |
|------|--------|
| Valid `q=chennai` | 200 populated; `V2FeedItemMapper` maps `articleId` → `newsId`, title, image, publisher name, category, language, link |
| 2-char `q=ai` | 200 |
| `<2` `q=a` | Staging 400; Flutter `SearchQueryValidator` → `too_short` (no request) |
| Pagination page=2 | Works |
| Empty nonsense query | 200 `items: []` (not treated as crash) |
| Text index | Missing → `sortMode: recency` (backend blocker, not Flutter) |

Fixtures: `test/fixtures/phase10b/search_*.json`

---

## C. For You real API result

**Status: ✅ VERIFIED** (anonymous) / **⚠️ DEVICE VALIDATION REQUIRED** (authenticated)

| Case | Result |
|------|--------|
| Anonymous | 200 `mode=anonymous_fallback`; items map; Cuts preserved when present |
| Empty ranked page | Client treats successful empty as empty (Phase 9) — not re-broken |
| Authenticated / personalized | No staging JWT available → **AUTHENTICATED DEVICE/API VALIDATION REQUIRED** |

---

## D. NewsOn Cuts result

**Status: ✅ VERIFIED** (partial data) / **⚠️ CONFIGURATION REQUIRED** (summary pipeline)

- Anonymous For You fixture includes real `v2Summary` on some items — mapper keeps `NewsArticle.v2Summary`.
- Search sample often had `v2Summary: null` — UI must fall back (description / aiSummary) without inventing text.
- Pending/failed/unavailable summary states + Redis workers: **not** fully exercisable (Redis unavailable; summary queue disabled).

---

## E. Article Detail result

**Status: ✅ VERIFIED** (mapping) / **⚠️ DEVICE VALIDATION REQUIRED** (full UI nav)

Mapped fields from staging items: id, title, image, publisher name, link/source, language, category, optional `v2Summary`.  
Full in-app Article Detail / related news on device: not run (no device / RC flags off).

---

## F. Publisher result

**Status: ⚠️ CONFIGURATION REQUIRED**

Staging search/for-you publisher objects often `{ "name": "…" }` **without** `id`.  
Flutter correctly maps name; `publisherId` frequently null → dedicated Publisher page by id incomplete until backend/enrichment provides ids.  
Name-based V1-style attribution still works.

---

## G. Audio result

**Status: ✅ VERIFIED** (unavailable / generation-disabled)  

- GET → `status: unavailable` → `ArticleAudio.canPlay == false`
- POST request with generation off → soft unavailable message (no TTS forced)
- Ready playback: **not claimed** (no ready object; generation disabled; Redis down)

---

## H. Analytics result

**Status: ✅ FIXED** + **✅ VERIFIED** (contract against staging)

**Defects reproduced on staging:**

1. Flutter sent `event` → staging requires `eventName` → 400  
2. Dimensions nested under `params` → staging requires top-level `newsId` / `publisherId` / `language` / `region`  
3. Posts went through Firestore `analytics/trackEvent` key → now `POST /api/analytics/track` via `postByPath`  
4. `ApiService` URL builder dropped non-default ports (`:8010`) → V2 `getByPath`/`postByPath` would miss staging

After fix: `session_start`, `search`, `language_change`, `region_change` accepted (201).  
`news_open` / `summary_view` / `full_article_click` succeed when top-level ObjectId `newsId` is sent.

Still soft-failing by design when `category_view` only has category **name** (backend requires `categoryId` ObjectId) — no fabricated ids.

---

## I. Remote Config result

**Status: ✅ VERIFIED** (defaults remain false)

No production RC keys permanently enabled. Staging validation used direct API + fixtures / dart-define, not a global V2 rollout.

---

## J. V1 regression result

**Status: ✅ VERIFIED** (code-path / defaults)

- V2 remains behind flags (defaults false).
- V1 services not replaced globally.
- Default unit suite still green after analytics/API origin fixes.

---

## K. Flutter defects discovered

| ID | Defect |
|----|--------|
| P10B-1 | Analytics body used `event` + nested `params` — rejected by Phase 1D `/api/analytics/track` |
| P10B-2 | Analytics depended on Firestore endpoint catalog instead of canonical `/api/analytics/track` |
| P10B-3 | `ApiService` stripped URL port when composing paths — breaks staging `host:8010` |

---

## L. Exact fixes applied

1. `AnalyticsService.buildTrackBody` → `eventName`, top-level dimensions, `metadata` for extras; emit via `postByPath('/api/analytics/track')`
2. Map `newsLanguage` → `language` for `language_change`
3. `ApiService` uses `Uri.origin` (preserves port) for all path URL builds
4. Optional `--dart-define=NEWSON_API_BASE_URL` staging override (no Firebase mutation)

---

## M. Exact files changed

- `lib/core/analytics/analytics_service.dart`
- `lib/data/services/api_service.dart`
- `lib/main.dart`
- `test/core/analytics/analytics_track_body_test.dart` (new)
- `test/data/services/api_base_origin_test.dart` (new)
- `test/features/phase10b_staging_fixture_test.dart` (new)
- `test/fixtures/phase10b/*.json` (new — captured live)
- `test/integration/network/phase10b_staging_validation_test.dart` (new, tagged; excluded from default suite)
- `docs/TESTING.md`
- `docs/V2_PHASE10B_FLUTTER_STAGING_VALIDATION.md` (this file)

---

## N. `fvm flutter test` result

**Status: ✅ VERIFIED** — default suite **All tests passed** (`+160` after new unit/fixture tests).  
Tagged live network file remains excluded by root `dart_test.yaml` (package:test merges CLI exclude with root exclude).

---

## O. `fvm flutter analyze` result

**Status: ✅ VERIFIED** — changed lib/test files: **No issues found**.

---

## P. Device-only validations still pending

- Full UI with RC `v2_search` / `v2_for_you` / Cuts enabled on a real device pointed at staging  
- Authenticated For You (JWT)  
- Article Detail navigation / related news UX  
- Audio ready playback lifecycle  
- Duplicate analytics under rebuilds (in-app)

---

## Q. Backend / configuration blockers still pending

- Redis unavailable → queues / summary / audio generation  
- Search text index missing → recency sort only  
- Publisher `id` often absent on feed items  
- No staging test JWT for personalized For You  
- Audio generation intentionally disabled  
- Production host still without `/api/v2` (Phase 10) — out of scope for 10B staging

**Not production ready.** Staging Flutter↔API contract is substantially improved; device RC rollout and backend enrichment remain.
