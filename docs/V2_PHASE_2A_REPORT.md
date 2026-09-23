# Phase 2A Complete

**Branch:** `feature/v2.0.0-phase-2a`  
**Status:** Product implementation milestone — **not** production-ready until Remote Config flags are enabled and backend fields/endpoints are validated.

---

### NewsOn Cuts
- Domain: `lib/features/news/domain/news_summary.dart`
- States: `available` | `pending` | `unavailable` | `failed`
- Fallback hierarchy: `v2Summary` → legacy `aiSummary` → description (never labeled as Cut)
- Card: `lib/features/news/presentation/widgets/newson_cut_card.dart`

### Home
- New modular feed: `lib/features/home/presentation/v2_home_feed_tab.dart`
- Enabled only when `v2_news_cuts_enabled` is true
- V1 `news_feed_tab_new.dart` **preserved** as default

### Article Detail
- `lib/features/news_detail/presentation/article_detail_screen.dart`
- Publisher, Cut, metadata, actions, related
- Entry: `NewsDetailScreen.open` → `V2Routes` when `v2_new_article_detail_enabled`

### Full Article
- `FullArticleScreen` opens publisher `canonicalUrl` via existing `url_launcher` (external browser)
- **No** new WebView package (blocked by local Dart 3.5.4 vs `google_mobile_ads` ≥3.6.0)
- CTA gated by `v2_full_article_enabled`

### Publisher Attribution
- Visible on Cut card + detail header (`sourceName` / icon / relative time)

### Related News
- `RelatedNewsService` tries Firestore `news/relatedNews`
- Deterministic same-publisher / same-category fallback (not AI personalization)
- Gated by `v2_related_news_enabled`

### Page-Turn Interaction
- `PageTurnPageRoute` + optional `PageView` when `v2_page_turn_enabled`
- Honors reduced-motion (`MediaQuery.disableAnimationsOf`)

### Analytics
- `AnalyticsService` + `AnalyticsSession` + `AnalyticsEvents`
- Emits: `session_start`, `app_open`, `news_impression`, `news_open`, `summary_view`, `full_article_click`, `bookmark`, `share`
- Soft-fails if `analytics/trackEvent` missing; **never blocks UI**
- Kept separate from `InteractionService`

### Session Management
- Stable `sessionId` for the app session; rotate only via `endSession` / `forceNew`

### Localization
- `LocalizationHelper.v2*` with English fallbacks + dynamic translation keys

### Performance
- SliverList lazy build, image `memCacheWidth`, KeepAlive V2 tab
- Did **not** expand V1 god screens

### Tests
- Added: `test/features/news/news_summary_test.dart`
- Added: `test/core/analytics/analytics_session_test.dart`
- **Could not execute** in this environment (Flutter/Dart SDK mismatch / `google_mobile_ads` resolver)

### Flutter Analyze
- **Blocked** — same known issue: Dart **3.5.4** vs `google_mobile_ads ^6.0.0` requiring **≥3.6.0**
- Dependencies/SDK **not** upgraded per project policy

### Builds
- `flutter build apk/ios` **not run** — same resolver failure

### Feature Flags (exact defaults)

| Remote Config key | Default |
|-------------------|---------|
| `v2_news_cuts_enabled` | `false` |
| `v2_new_article_detail_enabled` | `false` |
| `v2_full_article_enabled` | `false` |
| `v2_related_news_enabled` | `false` |
| `v2_page_turn_enabled` | `false` |
| `v2_news_cuts_label` | `NewsOn Cuts` |

### Files Added
- `lib/core/analytics/analytics_events.dart`
- `lib/core/analytics/analytics_session.dart`
- `lib/core/analytics/analytics_service.dart`
- `lib/core/config/v2_feature_flags.dart`
- `lib/app/routing/v2_routes.dart`
- `lib/features/news/domain/news_summary.dart`
- `lib/features/news/data/related_news_service.dart`
- `lib/features/news/presentation/widgets/newson_cut_card.dart`
- `lib/features/news_detail/presentation/article_detail_screen.dart`
- `lib/features/news_detail/presentation/full_article_screen.dart`
- `lib/features/news_detail/presentation/widgets/page_turn_transition.dart`
- `lib/features/home/presentation/v2_home_feed_tab.dart`
- `test/features/news/news_summary_test.dart`
- `test/core/analytics/analytics_session_test.dart`
- `docs/V2_PHASE_2A_API_CONTRACT.md`
- `docs/V2_PHASE_2A_REPORT.md`

### Files Changed
- `lib/data/models/news_article.dart` (`v2Summary`, `summaryStatus`)
- `lib/data/models/remote_config_model.dart` (V2 flags)
- `lib/data/services/remote_config_service.dart` (defaults + getters)
- `lib/core/utils/localization_helper.dart` (V2 strings)
- `lib/screens/home/home_screen.dart` (flag-gated V2 feed)
- `lib/screens/news_detail/news_detail_screen.dart` (flag-gated open)

### Backend Dependencies
See `docs/V2_PHASE_2A_API_CONTRACT.md`:
- Populate `v2_summary` / `summary_status` on articles
- Optional `news/relatedNews`
- Optional `analytics/trackEvent`
- Enable RC flags for staged rollout

### Known Limitations
- Flags default **OFF** — V1 UX unchanged until RC enablement
- Full article uses **external browser** (no in-app WebView this phase)
- Related quality depends on backend endpoint
- Analytics persistence needs endpoint registration
- Local CI/SDK cannot resolve packages / run analyze/test/build here
- Not claiming production readiness
