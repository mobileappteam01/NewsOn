# V2 Search + For You Flutter Integration (Staging Validation)

**Date:** 2026-09-17  
**Backend:** `http://127.0.0.1:8010` (`GET /api/v2/search`, `GET /api/v2/for-you`)  
**Notifications:** not modified

## 1. Root cause / issues found

V2 Search and For You were **already integrated** behind flags (default OFF). Gaps closed in this pass:

| Gap | Fix |
|-----|-----|
| Stale overlapping search/refresh could apply old results | Request **generation counters** ignore stale responses |
| Search `news_impression` only on Cut cards | Emit impressions for visible search results (deduped) |
| Controllers hard-coupled to Firebase-backed Providers in tests | Controllers take `newsLanguageCode` / `appliedRegion` callbacks |
| Thin controller coverage | Added focused controller tests (valid/short/empty/error/pagination/stale) |

API search remains **submit-only** (Phase 5): typing only debounces **local** recent suggestions (350ms), not live network search — avoids duplicate/keystroke API spam.

## 2. Exact files changed

- `lib/features/search/data/search_repository.dart` — optional `SearchFetcher`; `languageCode` + `SavedRegion` params
- `lib/features/search/presentation/news_search_controller.dart` — stale generation; callback locale/region
- `lib/features/search/presentation/v2_search_tab.dart` — `news_impression` + callback wiring
- `lib/features/for_you/presentation/for_you_controller.dart` — stale generation; callback locale/region
- `lib/features/for_you/presentation/v2_for_you_tab.dart` — callback wiring
- `test/features/search/news_search_controller_test.dart` (new)
- `test/features/for_you/for_you_controller_test.dart` (new)

## 3. V2 Search status — ✅ implemented (flagged)

- `GET /api/v2/search` via `SearchRepository` + `ApiService.getByPath`
- Min length 2, pagination, pull-to-refresh, load-more, empty/error/loading
- Auth JWT when logged in; anonymous otherwise
- Home switches `V2SearchTab` when `V2FeatureFlags.search` is true

## 4. V2 For You status — ✅ implemented (flagged)

- `GET /api/v2/for-you` via `V2ForYouApi` / `ForYouRepository`
- Modes: personalized / cold_start / anonymous_fallback; empty trusted; client cold-start only on API **failure**
- Home switches `V2ForYouTab` when `V2FeatureFlags.forYou` is true

## 5. Analytics wired

| Event | Where |
|-------|--------|
| `search` | V2SearchTab on successful submit |
| `news_impression` | Search results (new) + NewsOnCutCard |
| `news_open` | Search + For You open |
| `for_you_impression` | V2ForYouTab section + per-article |

Uses mobile `sessionId`. No tokens/FCM/PII in metadata.

## 6. Feature flags

- Remote Config: `v2_search_enabled`, `v2_for_you_enabled` (default **false**)
- Staging dart-defines: `NEWSON_V2_SEARCH_ENABLED`, `NEWSON_V2_FOR_YOU_ENABLED` (optional override)
- API base: `NEWSON_API_BASE_URL=http://127.0.0.1:8010`

## 7. `fvm flutter analyze`

Changed Search/For You libs: **No issues found.**

## 8. `fvm flutter test`

**Default suite: All tests passed (`+179`).**

## 9. Real device validation

**Device:** connected (`M2006C3LI`). **Staging:** health 200 on `:8010`.  

On-device UI Search/For You walkthrough: **not verified in this pass** until `flutter run` successfully installs (prior sessions failed with Gradle/Dart abort on ~98% disk). Do not claim UI validation complete.

## 10. Remaining blockers

1. Successful on-device install (`flutter run` with staging dart-defines) — disk/Gradle stability.
2. Authenticated For You personalization — needs logged-in staging user JWT.
3. Production RC must stay OFF; use dart-defines only for staging device runs.

### Staging run command (when device ready)

```bash
adb reverse tcp:8010 tcp:8010
fvm flutter run -d <deviceId> \
  --dart-define=NEWSON_API_BASE_URL=http://127.0.0.1:8010 \
  --dart-define=NEWSON_V2_SEARCH_ENABLED=true \
  --dart-define=NEWSON_V2_FOR_YOU_ENABLED=true
```
