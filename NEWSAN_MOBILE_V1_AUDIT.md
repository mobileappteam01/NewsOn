# Newsan Mobile App — V1 Production Audit

**Audit Type:** Read-Only  
**Target Release:** V2.0.0  
**Repository / Project:** `newson` (`/Users/hxtreme/Documents/GitHub/NewsOn`)  
**Audit Date:** 2026-09-16  
**App version (pubspec):** `1.0.2+7` (iOS active; Android alternate `0.0.3+8` commented)

---

## Audit Coverage

Inspected (read-only):

| Area | Paths |
|------|--------|
| Entry / bootstrap | `lib/main.dart`, `lib/core/bootstrap/app_bootstrap.dart`, `lib/firebase_options.dart` |
| Providers | `lib/providers/*` (all) |
| Data layer | `lib/data/services/*`, `lib/data/repositories/news_repository.dart`, `lib/data/models/*` |
| Screens | `lib/screens/**` |
| Core UI / utils | `lib/core/**`, `lib/widgets/**` |
| Localization | `lib/l10n/*`, `assets/languages/`, `DynamicLocalizationService` |
| Platform | `android/app/build.gradle.kts`, `AndroidManifest.xml`, `ios/Runner/Info.plist`, `web/` presence |
| Config | `pubspec.yaml`, `firebase_remote_config_template.json`, `docs/ADS_STRATEGY.md` (if present) |

## Audit Limitations

- Live Firebase/Firestore/RTDB contents and production API responses were **not** queried.
- Backend / Admin / Landing-page repositories were **not** audited; mobile-only conclusions.
- Exact Flutter SDK binary version on CI/dev machines not pinned in repo (only Dart constraint).
- AdMob / FCM production dashboards and Firebase Analytics console not accessible from source.
- NewsData.io credit usage not measurable from client code alone.
- Whether Firestore `apiEndPoints` paths match deployed backend was not verified live.

---

## 1. Project Overview

| Area | Current Implementation | Evidence | V2 Concern |
|------|------------------------|----------|------------|
| Flutter / Dart | Dart SDK `>=3.0.0 <4.0.0`; Flutter via SDK deps | `pubspec.yaml:24–28` | Local env may be Dart 3.5.4 while `google_mobile_ads ^6` wants ≥3.6.0 |
| App identity | Package `newson`; version `1.0.2+7` | `pubspec.yaml:1,20` | Android/iOS versioning comments diverge |
| Android | `com.app.newson`, minSdk 23, target/compile 36, **no flavors** | `android/app/build.gradle.kts` | No staging/prod flavor split |
| iOS | Bundle `com.newson.application`, display “Newson India”, iOS 15+ | `Info.plist`, `pbxproj` | Package ID ≠ Android applicationId |
| Web | `web/` scaffold exists; Firebase web throws | `web/`, `firebase_options.dart` | Not a production target |
| State | **Provider** `ChangeNotifier`; unused Bloc stub; no Riverpod/GetX in `lib/` | `main.dart` MultiProvider; `search/bloc/sample_bloc.dart` | Oversized notifiers; no DI container |
| Architecture | UI → Providers → Services / 1 Repository → API/Firebase/Hive | `lib/data/repositories/news_repository.dart` | God screens; services as singletons |
| DI | Manual Provider tree + factory/static singletons | `main.dart:250–290` | Hard to test; globals (`newsAPIKey`, etc.) |
| Routing | Imperative `Navigator` + `MaterialPageRoute` only | `main.dart:331–359`, `app_navigator.dart` | No typed routes / deep-link route table |
| Networking | Dio via `ApiService`; dual stack (backend primary, NewsData leftover) | `api_service.dart`, `backend_news_service.dart`, `news_api_service.dart` | Dead NewsData path; debug SSL bypass |
| Local DB / cache | Hive (`bookmarks`, `settings`, `completed_news`) + SharedPreferences (region, dynamic l10n) + `CachedNetworkImage` | `storage_service.dart`, `region_preference_service.dart` | Mixed stores; weak TTL |
| Firebase | Core, Remote Config, FCM (token), Firestore, RTDB, Storage | `main.dart`, services | No Analytics / Crashlytics / Firebase Auth |
| Auth | Google + Apple → **backend** JWT (`UserService`) | `auth_screen.dart`, `auth_api_service.dart` | Guest browse iOS-only |
| Push | FCM token registration only; **no message handlers** | `fcm_service.dart` | Cannot route notifications in-app |
| Analytics | **None** (no `firebase_analytics`) | grep: no matches | Blind product metrics for V2 |
| Remote Config | Heavy UI/copy/ads/feature gates | `remote_config_service.dart`, `remote_config_model.dart` | Coupled to large model |
| Ads | AdMob via `AdService` + RTDB unit IDs | `ad_service.dart`, feed/detail widgets | Interstitial/anchor dead code |
| Image caching | `NewsImageCacheService` + memCache sizing | `news_image_cache_service.dart`, `news_article_image.dart` | Some screens bypass helper |
| Localization | ARB (en/es/fr/hi/ta) + dynamic Firebase translations (ml/te/kn) | `l10n/`, `dynamic_localization_service.dart` | Dual systems; default now English |
| Error handling | Try/catch + SnackBars; offline hydrate | providers / feed | Inconsistent empty/error UX |
| Logging | `debugPrint` extensively | throughout | Risk of noisy / sensitive logs |
| Feature flags | Remote Config + RTDB `ads_config` | `AdPolicy`, RC model | No unified flag layer |
| Env / config | RTDB `ipAddress` + Firestore `apiEndPoints` + RC | `api_service.dart`, `main.dart` fetchAllDBData | Secrets in RTDB → client globals |

---

## 2. Folder / Architecture Audit

```
presentation (lib/screens, lib/widgets, lib/core/widgets)
        ↓
providers (ChangeNotifier)
        ↓
repositories (NewsRepository only) + services (~37)
        ↓
ApiService / BackendNewsService / Firebase / Hive
        ↓
models (NewsArticle, RemoteConfigModel, …)
```

### Major folders

| Folder | Responsibility |
|--------|----------------|
| `lib/screens/` | Feature screens (auth, home, detail, drawer settings, splash) |
| `lib/providers/` | App state |
| `lib/data/services/` | Networking, Firebase helpers, ads, FCM, cache |
| `lib/data/repositories/` | News aggregation + cache/prefetch |
| `lib/data/models/` | DTOs |
| `lib/core/` | Theme, constants, shared widgets, utils, navigation |
| `lib/l10n/` | Generated + ARB localizations |
| `lib/widgets/` | Cross-feature widgets (grids, sign-in) |

### Important issues

| File | Class/function | Problem | Impact | V2 direction | Priority |
|------|----------------|---------|--------|--------------|----------|
| `lib/screens/home/tabs/news_feed_tab_new.dart` (~2193 lines) | `_NewsFeedTabNewState` | God screen: UI + pagination + ads + region + language + refresh | Hard to change Home safely | Split widgets + controllers | **Critical** |
| `lib/screens/news_detail/news_detail_screen.dart` (~1374) | `NewsDetailScreen` | Monolithic detail + ads carousel + bookmark/share | Slow V2 reading UX work | Feature module + smaller widgets | **High** |
| `lib/core/utils/localization_helper.dart` (~1453) | `LocalizationHelper` | Giant string facade | Merge conflicts; hard i18n | Codegen / modular keys | **Medium** |
| `lib/providers/audio_player_provider.dart` (~1179) | `AudioPlayerProvider` | Oversized media state | Leak / race risk | Isolate audio feature | **High** |
| `lib/data/services/api_service.dart` (~1128) | `ApiService` | Endpoint map + HTTP + SSL + modules | Single point of failure | Thin client + endpoint registry | **High** |
| `lib/screens/categories/categories_tab.dart` | `CategoriesTab` | Not on Home IndexedStack | Dead / parallel UI | Deprecate or wire intentionally | **Medium** |
| `lib/screens/home/tabs/headlines.dart` | `HeadLinesView` | Legacy unused by Home | Confusion | Remove in V2 | **Low** |
| `lib/screens/search/bloc/sample_bloc.dart` | `SampleBloc` | Unused Bloc stub | Noise | Delete | **Low** |
| `lib/main.dart` | globals | Mutable API keys / providers | Testability / security | Injected config | **High** |
| Multiple news cards | `NewsGridView` vs `NewsCard` vs local builders | Duplicate card UIs | Inconsistent UX | One design-system card | **High** |

**Tight coupling:** Home feed ↔ `NewsProvider` ↔ `LanguageProvider` ↔ `RegionProvider` ↔ Ad widgets.  
**Business logic in UI:** category preference filtering, refresh generation tokens, ad placement in `news_feed_tab_new.dart`.  
**Hardcoded config:** language lists, deep-link host `api.newson.app`, OAuth client IDs, Firebase options.

---

## 3. Screen Inventory

| Screen | Route | File | Purpose | API | State | Storage | Analytics | Issues | V2 Recommendation |
|--------|-------|------|---------|-----|-------|---------|-----------|--------|-------------------|
| Splash | `home:` | `screens/splash/splash_screen.dart` | Cold-start router | — | UserService | Hive session | None | Dual splash paths | KEEP / simplify |
| AuthenticatedLogoSplash | pushReplacement | `authenticated_logo_splash.dart` | Solid bridge → Home | — | UserService | theme | None | No logo (by design) | KEEP |
| Auth | MaterialPageRoute | `auth/auth_screen.dart` | Google/Apple + iOS skip | auth signIn/signUp | — | token/user | None | Android no guest | IMPROVE |
| Onboarding | push | `onboarding/onboarding_screen.dart` | New-user carousel | — | — | — | None | — | IMPROVE |
| Welcome | push | `welcome/welcome_screen.dart` | → categories | — | — | — | None | — | IMPROVE |
| CategorySelection | push / replacement | `category_selection_screen.dart` | Prefs | profile update, categories | local Set | user.category | None | Was stale Home chips (fixed) | KEEP |
| Home | shell | `home/home_screen.dart` | IndexedStack + drawer + bottom nav | FCM, profile, breaking | many providers | — | None | Heavy init | REBUILD shell |
| News feed tab | index 0 | `news_feed_tab_new.dart` | Today / categories | news APIs | NewsProvider | caches | None | God file | REBUILD |
| For You tab | index 1 | `for_you_tab.dart` | Personalized | forYou | ForYouProvider | — | None | Login gate | IMPROVE |
| Bookmarks tab | index 2 | `bookmarks/bookmarks_tab.dart` | Saved | bookmark list | BookmarkProvider | Hive | None | Duplicate drawer bookmark | CONSOLIDATE |
| Search tab | index 3 | `search/search_tab.dart` | Search | breakingNews+search | NewsProvider | — | None | Large file | IMPROVE |
| News detail | push | `news_detail_screen.dart` | Article reader | get by id (deep link) | Bookmark/Audio | — | Interaction API only | No WebView full article | REBUILD reader |
| Breaking view-all | push | `breaking_news_view_all_screen.dart` | List | breaking | NewsProvider | — | None | — | KEEP |
| Today view-all | push | `today_news_view_all_screen.dart` | List | today | NewsProvider | — | None | — | KEEP |
| Audio player | push | `core/screens/audio_player/...` | Full player | ElevenLabs / URL | AudioPlayerProvider | audio cache | None | Complex | IMPROVE |
| Drawer Account | push | `account_settings.dart` | Profile | profile | UserService | user data | None | Large | IMPROVE |
| Drawer Notifications | push | `notification.dart` | Inbox stub | — | static | — | None | Not FCM | REBUILD / NEW |
| Drawer Bookmarks | push | `drawer_widgets/bookmark.dart` | Alt bookmarks | — | BookmarkProvider | — | None | Duplicate | DEPRECATE |
| App settings hub | push | `application_settings.dart` | Settings menu | — | — | — | None | — | KEEP |
| Appearance / Text / Reading / Music | push | drawer_widgets/* | Prefs | — | Theme/Storage | Hive | None | — | KEEP |
| Terms / Privacy | push | drawer_widgets/* | Legal | content API | — | — | None | — | KEEP |
| Contact Us | push | `contact_us.dart` | mailto / URL | RC fields | RC | — | None | — | KEEP |
| CategoriesTab | **unwired** | `categories/categories_tab.dart` | Alt categories | categories/news | — | — | None | Orphan | DEPRECATE or wire |
| HeadLinesView | **unwired** | `home/tabs/headlines.dart` | Legacy | — | — | — | None | Orphan | REMOVE |
| Deep-link loading | push | `deep_link_service.dart` | Opening article | getNewsById | — | — | None | — | KEEP |

**Modals:** `LanguageSelectorDialog`, region bottom sheet, share sheet, app update dialog.

---

## 4. User Journey Audit

### A. First launch
User → `SplashScreen` (logged out) → Get Started → `AuthScreen` → OAuth (new) → Onboarding → Welcome → CategorySelection → `HomeScreen`  
**API:** signUp, select/update categories, then news fetches.  
**Friction:** long onboarding before first news.

### B. Returning user
User → Splash → `AuthenticatedLogoSplash` (solid) → Home  
**State:** Hive token/user; language/region prefs restored.

### C. Anonymous (iOS guest)
Auth Skip → `enableGuestBrowse` → Home. Android: no guest. For You / Bookmarks login-gated.

### D. Authenticated
Home init: ApiService, breaking news, bookmarks, FCM token, profile, app update (`home_screen.dart` init).

### E. Language change
News language dialog → `LanguageProvider.setNewsLanguage` → `NewsProvider` listener refreshes all sections. App language updates Dynamic + Language providers (UI strings).

### F. Region change
Globe → bottom sheet → `RegionProvider.apply` → `NewsProvider.setSavedRegion` → feed reload.

### G. Breaking news
Carousel on Home (if RC `breakingNewsEnabled`) → tap → `NewsDetailScreen` / view-all.

### H. Normal article
Card → `NewsDetailScreen.open` with article (+ optional list for swipe). Content from model fields (native text).

### I. Refresh
Pull-to-refresh / FAB → `_refreshVisibleFeed` (clear → shimmer → forceNetwork page 1).

### J. Pagination
Scroll near end → `_loadMoreTodayNews` / `_loadMoreCategoryNews`.

### K. Search
Search tab debounce → NewsProvider search → grid + inline ads.

### L. Share
Share sheet / `NewsShareService` → HTTPS `api.newson.app/news/{id}` + `InteractionService.trackShare`.

### M. Bookmark
Toggle via `BookmarkProvider`; login required for tab.

### N. Notification open
**Gap:** no FCM open handlers → cannot complete journey in mobile code.

### O. Resume
Deep link stream; audio background service; no dedicated analytics session.

### P–S. Failure modes
Offline: cache hydrate + ConnectivityHelper short-circuit. Empty: empty widgets / shimmer. API fail: debugPrint + partial UI. Image fail: branded logo fallback (`newsOnImageFallback` theme-aware).

**Friction summary:** onboarding length; dual language concepts (app vs news); notification inbox fake; guest asymmetry Android/iOS; god Home file slows iteration.

---

## 5. Home Screen Deep Audit

**Shell:** `home_screen.dart` — drawer, IndexedStack (4 tabs), bottom nav, audio mini player.

**Feed (`news_feed_tab_new.dart`):**

| Element | Implementation |
|---------|----------------|
| App bar / header | Logo (scroll-to-top), date picker, region, news language |
| Breaking | Carousel if RC enabled; local card builder |
| Ads | `FeedSectionBannerAd` + `InlineFeedAd` |
| Today / category list | `NewsGridView` + pagination |
| Pull-to-refresh / FAB | Shared `_refreshVisibleFeed` |
| Shimmer | `NewsFeedShimmer` / today shimmer |
| Prefetch | Repository + `NewsImageCacheService` |
| Category chips | API catalog filtered by user preference IDs |
| Lifecycle | `AutomaticKeepAliveClientMixin`; language/region listeners |

### CURRENT HOME FLOW

```
Home init → ApiService + NewsProvider fetches
NewsFeedTabNew init → region → categories → breaking → today
User scroll → load more / inline ads
User refresh → clear + forceNetwork
User category chip → category API (All = today)
```

### V2 OPPORTUNITY MAP

| Capability present | Limitation for V2 |
|--------------------|-------------------|
| Region + language filters | No publisher filter |
| Category prefs chips | “All” still unfiltered catalog news |
| Ad slots reserved | Placement UX still feed-interruptive |
| Offline hydrate | Stale TTL unclear |
| KeepAlive IndexedStack | Stale state after prefs (mitigated for categories) |
| Monolithic file | Blocks newspaper transition / redesign |

---

## 6. News Card Audit

| Component | File | Notes |
|-----------|------|-------|
| `NewsGridView` | `lib/widgets/news_grid_views.dart` | Primary list/card/thumbnail/detailed modes |
| `NewsCard` | `lib/core/widgets/news_card.dart` | Drawer bookmarks |
| `BreakingNewsCard` | `lib/core/widgets/breaking_news_card.dart` | Shared; Home uses private builder instead |
| `_buildBreakingNewsCard` | `news_feed_tab_new.dart` | Duplicate breaking UI |
| `ForYouSpotlightCard` | `for_you_spotlight_card.dart` | For You |
| Mosaic tiles | `for_you_featured_mosaic.dart` | For You layout |
| Categories list item | `categories_tab.dart` | Orphan tab |

**Issues:** multiple card implementations; mixed GoogleFonts (Inter/Roboto/Playfair); inconsistent image ratios; Home rebuilds large trees on provider notify.

---

## 7. News Detail Audit

| Topic | Finding | Evidence |
|-------|---------|----------|
| Data pass | Article object (+ list/index for PageView) | `NewsDetailScreen.open` |
| Extra API | Deep link resolves via get-by-id; normal open uses passed model | `deep_link_service.dart` |
| Content | `content` → `description` fallback; **native Text**, not WebView | `_getArticleContent` |
| `aiSummary` | Parsed on model; **not rendered** | `news_article.dart` |
| Share / bookmark | Yes + InteractionService | detail screen |
| Related news | **Absent** | — |
| Deep link | Yes | `DeepLinkService` |
| Full article URL | Fields `link` / `sourceUrl` exist; no in-app WebView / launch path found | model only |
| Ads | Full-page carousel ads | `DetailCarouselAdHelper` |

**V2 AI summary hook:** render `NewsArticle.aiSummary` (or new API field) above body; “View full article” → WebView/`url_launcher` on `sourceUrl`/`link`.

---

## 8. API / Network Audit

| Method | Endpoint/Config | File | Service | Auth | Usage |
|--------|-----------------|------|---------|------|-------|
| GET/POST/PUT/DELETE | Firestore `apiEndPoints` + RTDB `ipAddress` | `api_service.dart` | ApiService | Bearer optional | All backend |
| News list/breaking/today/category/id | module `news` keys | `backend_news_service.dart` | BackendNewsService | as needed | Feeds/detail |
| Search | reuses breaking + `search=` | same | same | | Search tab |
| For You | `news`/`forYou` | `for_you_service.dart` | | Bearer | For You |
| Categories | `chooseCategory`/`getCategories` | `category_api_service.dart` | | | Category UI |
| Profile | `profile`/* | `profile_service.dart` | | Bearer | Account/FCM |
| Auth | `auth`/signIn|signUp | `auth_api_service.dart` | | | Login |
| Bookmarks | `news` bookmark keys + hardcoded removeAll path | `bookmark_api_service.dart` | | Bearer | Bookmarks |
| Interactions | `news`/`postInteraction` | `interaction_service.dart` | | Bearer | open/read/bookmark/share/category_click |
| Regions | `region`/* | `region_api_service.dart` | | | Region sheet |
| Content | `app`/terms | `content_api_service.dart` | | | Legal |
| App update | `app`/appupdate | `app_update_service.dart` | | | Dialog |
| ElevenLabs | `https://api.elevenlabs.io/v1` | `elevenlabs_service.dart` | API key header | Audio |
| NewsData.io | RC defaults `/api/1` | `news_api_service.dart` | **Unused by repository** | Dead path |

**Client:** Dio; timeout from config; debug bad-certificate allow; connectivity via `ConnectivityHelper`.  
**No formal interceptor analytics layer.**

---

## 9. NewsData.io Integration Audit

| Item | Mobile reality |
|------|----------------|
| Client class | `NewsApiService` |
| Wired to feeds? | **No** — `NewsRepository` uses `BackendNewsService` |
| Config | RC/RTDB defaults still include `https://newsdata.io/api/1` |
| Key | RTDB `newsDataAPIKey` → global `newsAPIKey` in `main.dart` |
| Credit usage | Not observable in active feed path |

**Conclusion:** NewsData.io is **legacy configuration**, not the live V1 feed pipeline.

---

## 10. Firebase Audit

| Service | Used? | Files | Purpose | V2 Gap |
|---------|-------|-------|---------|--------|
| Core | Yes | `main.dart`, `firebase_options.dart` | Init | — |
| Auth | **No** | — | — | Optional unify |
| Firestore | Yes | `api_service`, `completed_news_service` | Endpoints map; completed news | Rules unknown |
| RTDB | Yes | ads, keys, ipAddress, music | Runtime config | Secrets on client |
| Storage | Yes | dynamic l10n | Translation files | — |
| FCM | Partial | `fcm_service.dart` | Token only | Handlers + topics |
| Remote Config | Yes | remote_config_* | UI/ads/copy | Feature-flag hygiene |
| Analytics | **No** | — | — | **Required for V2** |
| Crashlytics | **No** | — | — | Stability |
| App Check | **No** | — | — | Abuse protection |
| Dynamic Links | No (app_links instead) | `deep_link_service.dart` | HTTPS + custom scheme | iOS AASA |

---

## 11. Analytics Audit

### Existing Firebase Analytics events

**None.** `firebase_analytics` not in dependencies; no `logEvent` in `lib/`.

### Backend interaction “events” (not Analytics)

| Action | File | Trigger |
|--------|------|---------|
| `open` | `interaction_service.dart` | Article open |
| `read` | same | Read duration |
| `bookmark` | same | Bookmark |
| `share` | same | Share |
| `category_click` | same | Category |

### Missing for V2 (recommended)

`app_open`, `session_start`, `news_view`, `article_open`, `category_view`, `publisher_view`, `search`, `share`, `bookmark`, `notification_open`, `language_change`, `region_change`, `ad_impression`, `audio_click`, `summary_view`, `full_article_click`, `for_you_impression`.

---

## 12. Local Storage / Cache Audit

| Storage | File | Data | TTL | V2 Concern |
|---------|------|------|-----|------------|
| Hive `settings` | `storage_service.dart` | theme, language, news_language, token, user, caches | Mostly none | Growth; mixed concerns |
| Hive `bookmarks` | same | articles | — | Sync conflicts |
| Hive `completed_news` | `completed_news_provider.dart` | IDs | — | Not in AppConstants |
| SharedPreferences | region + dynamic l10n | region + translations | soft | Dual preference systems |
| Image disk cache | `NewsImageCacheService` | images | flutter_cache_manager defaults | OK |
| Audio disk | `news_audio_cache_service.dart` | mp3 | — | Disk growth |
| In-memory ads | `ad_cache_manager.dart` | banners | session | — |

---

## 13. State Management Audit

**Primary:** Provider `ChangeNotifier`.

| Provider | Role | Risk |
|----------|------|------|
| NewsProvider | Feeds, pagination, region | Large; many notifyListeners |
| LanguageProvider | App vs news language | Split concept OK; dual with Dynamic |
| DynamicLanguageProvider | Firebase UI strings | Init race with MaterialApp locale |
| RegionProvider | Geo filter | — |
| BookmarkProvider | Bookmarks | — |
| ForYouProvider | Personalized | Login gate |
| AudioPlayerProvider | Playback | Very large |
| RemoteConfigProvider | RC | Broad rebuilds |
| ThemeProvider | Theme | — |
| TtsProvider / CompletedNewsProvider | TTS / listened | — |

**Issues:** UI-side API orchestration; IndexedStack keep-alive staleness; no Riverpod selectors by default (some Selector usage may exist but feed is Consumer-heavy).

---

## 14. Localization Audit

| Item | Detail |
|------|--------|
| ARB locales | en, es, fr, hi, ta |
| Dynamic extras | ml, te, kn (+ RC list) |
| Default (missing pref) | **English (`en`)** after recent change |
| App vs news language | Separate settings |
| Hardcoded strings | Some SnackBars still English literals |
| RTL | Not a focus (no ar locale) |
| AI summaries multi-lang | Would need summary language = news language; UI strings already dynamic |

---

## 15. Region / Personalization Audit

| Topic | Behavior |
|-------|----------|
| Detection | Manual selection (not GPS auto) via Region APIs |
| Storage | SharedPreferences country/state/district |
| Feed | Passed into BackendNewsService fetches |
| For You | Separate backend `forYou` endpoint; login required |
| Categories | Profile `category` IDs filter Home chips |

**Limits:** no publisher affinity UI; For You quality depends on backend; location_service used for profile cities, not feed region.

---

## 16. Ads / AdMob Audit

| Screen | Ad Type | Placement | Frequency | UX | V2 |
|--------|---------|----------|-----------|-----|----|
| Home feed | Inline medium | List | `inlineInterval` | Reserved height on fail | Tune density |
| Home | Section banner | After breaking | flag | — | KEEP |
| Search | Inline | Results | `searchInlineEnabled` | — | KEEP |
| Detail | Full-page carousel | Between articles | interval | Interruptive | Revisit for “newspaper” UX |
| — | Interstitial | Code present | **forced off** | Dead | DEPRECATE or redesign |
| — | Anchor banner | Widget unused | flag | Dead | Wire or remove |

Init: `AdService` after first frame in `main.dart`. Unit IDs from RTDB.

---

## 17. Image / Media Performance

- `NewsArticleImage`: decode cap 1280, logo fallback.
- Prefetch concurrency 3; startup warm limited counts.
- Detail hero uses `CachedNetworkImage` directly (bypass helper).
- Failed images → theme-aware NewsOn logo (`shared_functions.dart`).

---

## 18. Performance Audit

### Critical
- `news_feed_tab_new.dart` 2k+ lines / wide rebuilds
- Audio provider size / media session complexity
- Detail PageView + ads carousel memory

### Medium
- Duplicate image load paths
- NewsProvider full-list refreshes on language change
- KeepAlive tabs retaining lists

### Opportunities
- Selector/Consumer narrowing
- Sliver composition
- Single card widget
- Dispose audits on listeners/controllers

---

## 19. Offline / Network Resilience

| Scenario | Behavior |
|----------|----------|
| No internet | Cache-first hydrate; connectivity checks |
| Slow / timeout | Dio timeouts; user sees shimmer/error snackbars inconsistently |
| Empty | Empty states vary by tab |
| Image fail | Logo fallback |
| Partial | Lists may show cached subset |

**V2:** unified error/empty components; explicit offline banner; cache TTL policy.

---

## 20. Security Audit (source review)

| Finding | Evidence | Risk |
|---------|----------|------|
| Firebase API keys in repo | `firebase_options.dart` | Expected for client; restrict with App Check |
| OAuth serverClientId in code | `google_auth_service.dart` | Client exposure |
| RTDB secrets → globals | `main.dart` newsData/elevenLabs keys | Prefer backend proxy for ElevenLabs |
| Debug SSL trust-all | `api_service.dart` | Ensure release-only |
| JWT in Hive | `UserService` | Device compromise risk |
| Storage download tokens in URLs | some assets/RC | Rotate if leaked |
| No Crashlytics | — | Blind crashes |
| HTTPS preferred | api.newson.app, etc. | Firestore could still register http |

---

## 21. Accessibility Audit

- **Semantics:** 0 usages found under `lib/`.
- Text size setting exists (detail-oriented), not global TextScaler.
- Tap targets / contrast not systematically enforced.
- Dynamic fonts mixed; dark mode present via ThemeProvider.

**V2:** Semantics on cards/nav; system text scale; contrast tokens; reduce motion option.

---

## 22. UI / UX Consistency Audit

| Aspect | Current |
|--------|---------|
| Colors | Remote Config primary `#C70000` + theme | 
| Typography | FontManager OpenSans + ad-hoc GoogleFonts families |
| Spacing / radius | AppConstants padding/radius; many local values |
| Dark mode | Yes |
| Loading | Shimmer variants |
| Empty / error | Inconsistent |

**V2 design system:** color/type/spacing tokens; one card; one button set; ban one-off fonts in features.

---

## 23. Deep Link / Sharing Audit

| Mechanism | Status |
|-----------|--------|
| Custom scheme `newson://` | Yes |
| Android App Links `https://api.newson.app/news/{id}` | Yes (`autoVerify`) |
| iOS Universal Links | **No associated domains found in-repo** |
| Share payload | Title + CTA + HTTPS link (`NewsShareService`) |
| Web fallback | Host-dependent; not audited |

---

## 24. Notification Audit

| Topic | Status |
|-------|--------|
| Token registration | Yes → profile `fcmTokenUser` |
| Topics | Not found |
| Foreground/background handlers | **Not found** |
| Click → article | **Not implemented** |
| In-app inbox | Placeholder static list |
| Audio media notification | Separate (playback) |

**V2 gaps:** breaking alerts, digest, language/region topics, open tracking, real inbox.

---

## 25. Feature Inventory

| Feature | Exists | Production Ready | Files | V2 Status |
|---------|--------|------------------|-------|-----------|
| Splash / session routing | Yes | Yes | splash/* | KEEP |
| Auth Google/Apple | Yes | Yes | auth/* | IMPROVE |
| iOS guest | Yes | Partial | UserService | IMPROVE |
| Home feed | Yes | Yes | news_feed_tab_new | REBUILD |
| Breaking news | Yes | Yes (RC gate) | feed + view-all | IMPROVE |
| Categories prefs | Yes | Yes | category_selection | KEEP |
| News detail | Yes | Yes | news_detail | REBUILD |
| Search | Yes | Yes | search_tab | IMPROVE |
| Bookmarks | Yes | Yes | bookmark* | IMPROVE |
| For You | Yes | Depends on backend | for_you* | IMPROVE |
| Region filter | Yes | Yes | region_* | KEEP |
| Dual language | Yes | Yes | language_* | KEEP |
| Ads | Yes | Yes (subset) | ad_* | IMPROVE |
| Audio / ElevenLabs | Yes | Yes | audio_* | IMPROVE |
| Deep links | Yes | Android strong / iOS weak | deep_link_* | IMPROVE |
| FCM open routing | No | No | fcm_service | NEW |
| Firebase Analytics | No | No | — | NEW |
| AI summary UI | Model only | No | news_article | NEW |
| Full article WebView | No | No | — | NEW |
| Publisher pages | No | No | — | NEW |
| Related news | No | No | — | NEW |
| Subscriptions | No | No | — | R&D REQUIRED |
| CategoriesTab | Orphan | No | categories_tab | DEPRECATE |

---

## 26. V2.0.0 Gap Analysis

| V2 Requirement | Current Support | Gap | Files | Backend | Admin | Risk | Recommendation |
|----------------|-----------------|-----|-------|---------|-------|------|----------------|
| AI ~60-word summaries | `aiSummary` field unused | UI + possibly generate API | news_article, detail | Yes | Yes | Medium | Show field; fallback generate |
| View Full Article | URL fields only | WebView / external browser | detail | Optional | — | Low | url_launcher first |
| Newspaper page transition | Swipe detail exists | Not newspaper metaphor | detail | — | — | High UX | Rebuild reader |
| Expanded categories | Category API | Product taxonomy | category_* | Yes | Yes | Medium | Data-driven |
| Publisher discovery | sourceName display | No pages | — | Yes | Yes | Medium | New feature module |
| Regional discovery | Region filter | Deeper geo UX | region_* | Yes | — | Medium | Improve |
| Personalized For You | Endpoint exists | Ranking quality unknown | for_you_* | Yes | Yes | High | Backend R&D |
| Audio / voice | ElevenLabs + TTS | Cost; UX polish | audio_* | Proxy key | — | High | Improve + proxy |
| Improved search | Basic search | Filters, suggest | search_tab | Yes | — | Medium | Improve |
| Better sharing | HTTPS links | OG previews, iOS UL | share/deep_link | Landing | Yes | Medium | Align landing |
| Push strategy | Token only | Handlers + campaigns | fcm_* | Yes | Yes | High | New |
| Onboarding | Exists | Length / value | onboarding, welcome | — | — | Medium | Shorten |
| Retention UX | Weak | Digests, streaks | — | Yes | Yes | High | New |
| Analytics | Interaction API only | Product analytics | — | Optional | Dashboard | Critical | Add Firebase Analytics |
| Monetization | AdMob | Density / formats | ads | — | RC/RTDB | Medium | Optimize |
| Subscriptions | None | IAP + entitlements | — | Yes | Yes | High | R&D |
| Remote features | RC heavy | Flag discipline | remote_config_* | — | Yes | Medium | Improve |
| Performance | Partial | God screens | feed/detail | — | — | High | Rebuild hotspots |
| Premium design | RC theme | Design system | theme, fonts | — | — | Medium | Design tokens |

---

## 27. Reuse vs Rebuild Analysis

### REUSE
- `ApiService` + Firestore endpoint map pattern
- `BackendNewsService` feed APIs
- Auth → JWT `UserService`
- Hive session / bookmarks
- Remote Config plumbing
- Deep link constants + Android App Links
- AdService policy model (with cleanup)
- Language split (app vs news)
- Region preference pipeline

### IMPROVE
- For You, Search, Bookmarks UX
- Image helper adoption everywhere
- Splash bridge
- Contact / settings
- Share + iOS universal links
- Category chip prefs sync

### REBUILD
- Home feed screen architecture
- News detail / reading experience
- Notification inbox + FCM routing
- Design system / cards
- Analytics layer

### REMOVE
- Unused `NewsApiService` feed path (or quarantine)
- Orphan `CategoriesTab` / `HeadLinesView` / sample Bloc
- Dead interstitial/anchor if unused
- Duplicate drawer bookmark if consolidated

### NEW
- AI summary UI
- Full article viewer
- Publisher pages
- Firebase Analytics + Crashlytics
- Notification open handling
- (Optional) subscriptions

---

## 28. Technical Debt Report

| ID | File | Problem | Impact | Risk | V2 action | Complexity |
|----|------|---------|--------|------|-----------|------------|
| TD-01 | `news_feed_tab_new.dart` | God widget | Blocks V2 Home | High | Split modules | Large |
| TD-02 | `news_detail_screen.dart` | Monolith | Reader redesign hard | High | Rebuild | Large |
| TD-03 | No Analytics | Blind product | High | Add FA | Medium |
| TD-04 | FCM handlers missing | Push useless for opens | High | Implement | Medium |
| TD-05 | Dual news stacks | Confusion | Medium | Delete dead NewsData path | Small |
| TD-06 | Globals in `main.dart` | Secrets/testability | High | Config injection | Medium |
| TD-07 | Debug SSL bypass | Misuse risk | Medium | Guard release | Small |
| TD-08 | Multiple card UIs | Inconsistent UX | Medium | Unify | Medium |
| TD-09 | Orphan screens | Dead code | Low | Delete | Small |
| TD-10 | Hive+Prefs split | Preference bugs | Medium | Single prefs API | Medium |
| TD-11 | `localization_helper` size | Maintainability | Medium | Modularize | Large |
| TD-12 | Android≠iOS package IDs | Ops confusion | Low | Document | Small |
| TD-13 | No Semantics | A11y | Medium | Add | Medium |
| TD-14 | Interstitial dead code | Noise | Low | Remove | Small |
| TD-15 | `aiSummary` unused | Missed product | Medium | Surface in UI | Small |

---

## 29. Recommended Mobile V2 Architecture

```
lib/
  app/                 # bootstrap, MaterialApp, DI
  core/
    networking/        # ApiClient (from ApiService)
    analytics/         # NEW
    storage/           # unified prefs/cache
    config/            # RC + RTDB facade
    theme/             # design tokens
    routing/           # typed routes / go_router
  features/
    home/
    breaking_news/
    news_detail/       # reader + summary + full article
    categories/
    publishers/        # NEW
    search/
    for_you/
    bookmarks/
    auth/
    profile/
    settings/
    notifications/     # NEW real inbox + FCM
    audio/
  shared/
    widgets/           # NewsCard DS
    models/
    extensions/
```

**Move:** screens into `features/*`; slim providers or controllers per feature.  
**Remain:** backend endpoint map, auth JWT, RC for copy/ads.  
**Consolidate:** cards, image loading, prefs.  
**Deprecate:** NewsData client path, orphan tabs, sample Bloc.

---

## 30. V2 Implementation Dependencies

| V2 Feature | Mobile | Backend | Admin | Firebase | AI | Third Party |
|------------|--------|---------|-------|----------|----|-------------|
| AI Summary | UI | serve/generate `ai_summary` | editorial tools | — | Yes | — |
| Full Article | WebView/launcher | stable `sourceUrl` | — | — | — | publisher sites |
| Newspaper reader | UI | — | — | — | — | — |
| Publishers | pages | publisher API | CMS | — | — | — |
| For You quality | — | ranking | labels | — | optional | — |
| Push | handlers | send pipeline | campaigns | FCM | — | — |
| Analytics | events | optional warehouse | dashboard | Analytics | — | — |
| Ads optimize | placement | — | RC/RTDB IDs | — | — | AdMob |
| Subscriptions | IAP | entitlements | plans | — | — | Stores |
| Audio | player | proxy TTS | — | — | — | ElevenLabs |
| Deep links | iOS AASA | landing | — | — | — | — |

---

## 31. Cursor Implementation Preparation

| Feature | Relevant files | Likely change | Likely create | Risks / unknowns |
|---------|----------------|---------------|---------------|------------------|
| AI Summary | `news_article.dart`, `news_detail_screen.dart` | Detail UI | summary widget | Is field populated in prod? |
| Full Article | detail, pubspec (webview?) | open URL | webview screen | Publisher blocks? |
| Home rebuild | `news_feed_tab_new.dart`, `home_screen.dart`, `news_grid_views.dart` | Split | `features/home/*` | Regression on ads/pagination |
| Analytics | `main.dart`, key screens | log calls | `analytics_service.dart` | PII policy |
| FCM routing | `fcm_service.dart`, `deep_link_service.dart` | handlers | notification router | Payload contract from backend |
| Publishers | — | — | feature module | API/admin readiness |
| iOS Universal Links | `Info.plist`, entitlements | config | — | AASA on api.newson.app |
| Design system | theme, cards | tokens | `shared/widgets/news_card.dart` | Visual QA |

**Do not implement yet** — backend/admin audits required for summary population, publisher APIs, push payloads, and For You ranking.

---

## 32. Final Executive Summary

### A. CURRENT PRODUCT STATE
Production Flutter news app (`newson`) with Provider architecture, backend-driven news (not live NewsData feeds), Firebase Remote Config/RTDB/Firestore/FCM-token, AdMob, dual-language (app vs news), region filter, For You, bookmarks, search, audio (ElevenLabs), deep links (stronger on Android), and English default language after recent preference fix.

### B. BIGGEST TECHNICAL PROBLEMS
1. God-level Home feed (~2193 lines) and detail (~1374 lines)  
2. No Firebase Analytics / Crashlytics  
3. FCM without message/open handlers  
4. Dual/legacy NewsData path + secrets as client globals  
5. Oversized providers and mixed storage  

### C. BIGGEST UX PROBLEMS
1. Long first-run path before news  
2. Notification screen is a stub  
3. Inconsistent cards/fonts  
4. Detail ads interrupt reading  
5. App vs news language can confuse users  
6. Android lacks iOS-style guest browse  

### D. BIGGEST PRODUCT GAPS
AI summary UI, full-article flow, publisher discovery, related news, real push journeys, subscriptions, robust analytics, newspaper-style reading.

### E. WHAT CAN BE REUSED
Backend `ApiService` map, auth JWT, news repository/backend services, RC, ads policy, language/region systems, share/deep-link Android setup, caches, category prefs.

### F. WHAT SHOULD BE REBUILT
Home feed composition, news reader experience, notifications, design system/cards, analytics foundation.

### G. WHAT MUST BE RESEARCHED BEFORE IMPLEMENTATION
- Is `ai_summary` populated in production responses?  
- Publisher and related-news APIs / admin models  
- FCM payload schema  
- For You ranking quality  
- iOS Associated Domains readiness  
- ElevenLabs cost / proxy strategy  
- Subscription business rules  

### H. MOBILE V2.0.0 PRIORITIES
1. Analytics + Crashlytics  
2. FCM open → article  
3. Surface AI summary + View Full Article  
4. Modularize Home + unify NewsCard  
5. Reader UX (newspaper transition)  
6. Publisher discovery (with backend)  
7. Push + retention loops  
8. Ad placement polish  
9. iOS Universal Links  
10. Subscriptions (R&D track)

### I. RISKS
Regression in ads/pagination while splitting Home; backend unreadiness for V2 content; client-held API keys; AdMob/SDK vs Dart version friction; scope creep without feature flags.

### J. DEPENDENCIES ON BACKEND / ADMIN / LANDING
Summaries, publishers, push campaigns, For You quality, endpoint registry, landing/OG for shares, AASA for iOS links, optional TTS proxy, subscription entitlements.

---

## 33. Document Control

- **Audit method:** Static source inspection only; no code modifications to application sources for feature work.  
- **This file:** `NEWSAN_MOBILE_V1_AUDIT.md` is the audit deliverable for V2 planning.  
- **Next step (out of scope here):** separate Git branch `v2.0.0` + backend/admin audits + Cursor implementation plans per feature.
