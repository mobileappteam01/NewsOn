# V2 Phase 3 — Home Experience + Discovery Architecture

**Branch:** `feature/v2.0.0-phase-3-home`  
**Base:** `feature/v2.0.0-phase-2a`  
**Date:** 2026-09-16

---

## Summary

Modular V2 Home under `lib/features/home/` with section order:

**Breaking → NewsOn Cuts → Explore → Latest → For You**

V1 `news_feed_tab_new.dart` untouched. V2 remains behind `v2_news_cuts_enabled`.

---

## Architecture

| Piece | Path |
|-------|------|
| Shell | `presentation/v2_home_feed_tab.dart` |
| Screen | `presentation/v2_home_screen.dart` |
| Controller | `presentation/home_controller.dart` |
| State | `presentation/home_state.dart` |
| Dedupe | `domain/home_deduper.dart` |
| Explore picker | `domain/explore_category_picker.dart` |
| Widgets | `presentation/widgets/*` |

Uses existing Provider stack (`NewsProvider`, `ForYouProvider`, `RegionProvider`, `LanguageProvider`).

---

## Validation

| Check | Result |
|-------|--------|
| `fvm flutter analyze` | PASS (0 errors) |
| `fvm flutter test test/features/ test/core/analytics/` | PASS (23) |
| `fvm flutter build apk --debug` | PASS |
| iOS long build | **Deferred** (not run by agent) |

---

## Feature flags

Unchanged defaults (all OFF):

- `v2_news_cuts_enabled`
- `v2_new_article_detail_enabled`
- `v2_full_article_enabled`
- `v2_related_news_enabled`
- `v2_page_turn_enabled`

---

## Production safety

- V1 remains default when flags OFF  
- No production RC rollout  
- No iOS long-running build executed by the agent  
