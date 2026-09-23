# V2 Phase 2B — QA Report

**Branch:** `feature/v2.0.0-phase-2a`  
**Date:** 2026-09-16  
**Scope:** SDK/dependency stabilization + Phase 2A build/QA baseline. No product features.

---

## Environment

| Item | Value |
|------|--------|
| Flutter (FVM) | 3.29.2 |
| Dart | 3.7.2 |
| Global Flutter (avoid) | 3.24.5 / Dart 3.5.4 — causes `google_mobile_ads` resolve failure |
| Xcode | 26.6 (17F113) |
| JDK | OpenJDK 17 |
| Android | compile/target 36, minSdk 23, AGP 8.7.0, Gradle 8.10.2 |
| iOS deployment | 15.0 |
| Disk (during iOS) | Was ~221 MiB free (pod install failed); freed to ~4–9 GiB for retry |

---

## Flutter Analyze

**PASS** (exit 0) via `fvm flutter analyze`  
498 existing info/warning findings; **0 errors** after fixing `newson_cut_card.dart` relative imports.

---

## Tests

### Phase 2B gate (relevant suite)

```text
fvm flutter test test/features/ test/core/analytics/ \
  test/ad_placement_helper_test.dart test/detail_carousel_ad_helper_test.dart \
  test/news_share_service_test.dart test/deep_link_constants_test.dart \
  test/news_audio_cache_collect_test.dart test/datetime_ampm_test.dart
```

**PASS** — **30** passed, **0** failed  
Includes NewsOn Cut summary states, V2 article parsing, analytics sessionId stability.

### Full `fvm flutter test`

**Not a clean PASS for the whole tree.** Pre-existing failures / hangs unrelated to SDK pin:

- Background music / `just_audio` / `AudioSession` (missing `WidgetsFlutterBinding` / plugin channels)
- Voice search / `speech_to_text` (`MissingPluginException` in unit tests)
- Some category-selection widget tests (Firebase/network assumptions)
- Full suite can hang on plugin integration tests

Classification: **pre-existing / environment**, not caused by Flutter 3.29.2 pin or pubspec SDK constraint alignment.

---

## Android Build

```text
fvm flutter build apk --debug
```

**PASS** — `build/app/outputs/flutter-apk/app-debug.apk`

---

## iOS Build

```text
fvm flutter build ios --no-codesign
```

| Attempt | Result |
|---------|--------|
| 1 | **FAIL** — CocoaPods: `fatal: write error: No space left on device` while cloning pods |
| 2 | Pod install succeeded after freeing ~1–9 GiB; Xcode build ran ~40+ min; process aborted before Flutter printed `✓ Built` (incomplete `Runner.app`) |
| 3+ | Re-run required when disk and session stability allow |

**Documented limitation:** local disk exhaustion blocked a verified successful iOS artifact. Tooling (Xcode 26.6, CocoaPods 1.16.2, iOS 15.0 Podfile) is present; do not claim iOS PASS without a completed `✓ Built` line.

---

## V1 Regression (flags OFF — static + code review)

Remote Config defaults in `remote_config_service.dart`:

- `v2_news_cuts_enabled` = false  
- `v2_new_article_detail_enabled` = false  
- `v2_full_article_enabled` = false  
- `v2_related_news_enabled` = false  
- `v2_page_turn_enabled` = false  

`home_screen.dart` uses `NewsFeedTabNew` when `V2FeatureFlags.newsCuts` is false.  
`news_detail_screen.dart` opens V1 detail unless `newArticleDetail` is true.

**PASS (structural / defaults)** — no production RC rollout performed. Device walkthrough of feed/ads/auth/push not executed in this phase run.

---

## V2 Phase 2A QA (flags ON — static + unit)

| Area | Result | Notes |
|------|--------|-------|
| Summary available / pending / failed / unavailable | PASS (unit) | `news_summary_test.dart` |
| Description never labeled NewsOn Cut | PASS (unit) | Explicit test |
| Full article via `url_launcher` | PASS (structural) | Invalid URL / launch failure show error; no WebView added |
| Page turn + reduce motion | PASS (structural) | `PageTurnPageRoute` respects `MediaQuery.disableAnimationsOf` |
| Related news | PASS (structural) | Service + flag gating present |
| Analytics soft-fail | PASS (code review) | `AnalyticsService` catches errors; no userId spoofing |
| SessionId stability | PASS (unit) | `analytics_session_test.dart` |
| Localization helpers | PASS (structural) | `LocalizationHelper.v2*` keys with English fallbacks |
| Accessibility Semantics | PASS (structural) | Cut card + detail actions wrapped |

**Device QA with RC toggles:** not run on a physical device in this session.

---

## AdMob QA

- Still `google_mobile_ads: ^6.0.0` → lock **6.0.0**
- Compiles under Flutter 3.29.2
- No ad unit ID / monetization behavior changes in Phase 2B

**PASS (compile / no redesign)**

---

## Firebase QA

Locked Firebase packages unchanged; `main.dart` still initializes Firebase before ads.  
**PASS (compile / intact wiring)** — no Analytics SDK added.

---

## Analytics QA

- Soft failure on POST  
- `sessionId` owned by `AnalyticsSession`  
- JWT optional via bearer; no client `userId` in body  
- Dedupe window for impressions  

**PASS (code + unit for session)** — live endpoint exercise not run.

---

## Known Limitations

1. Must use **FVM Flutter 3.29.2** (`fvm flutter …`); global 3.24.5 fails `pub get`.
2. Full test suite has pre-existing plugin/integration failures.
3. iOS `--no-codesign` not verified green due to disk space / aborted long Xcode run.
4. Device QA (V1 flags OFF / V2 flags ON) remains for human QA.
5. Not production-ready solely from local analyze/APK.

---

## Production Safety

- V2 Remote Config flags remain **OFF** by default  
- No production RC rollout  
- No backend production changes  
- No secrets added  
