# V2 Phase 4 — Publisher Pages Report

**Branch:** `feature/v2.0.0-phase-4-publishers`  
**Base:** `feature/v2.0.0-phase-3-home`  
**Date:** 2026-09-16

## Publisher architecture

Module: `lib/features/publishers/`

- `domain/publisher_model.dart` — editorial brand model + provenance synthesis  
- `domain/publisher_article_filter.dart` — ID/name matching, dedupe  
- `domain/publisher_url_validator.dart` — trusted website validation  
- `data/publisher_api.dart` — public Firestore-mapped endpoints when configured  
- `data/publisher_repository.dart` — API + NewsOn article fallback  
- `presentation/publisher_page.dart` + controller/state/widgets  

## Routes

`V2Routes.openPublisher` / `openPublisherFromArticle`  
Route name: `/publisher/:id`

## Feature flag

`v2_publisher_pages_enabled` default **false**  
When false: attribution remains visible but not tappable.

## Licensing boundary

Only NewsOn-served articles. No full publisher body. Visit Publisher uses validated backend website URLs only. No scraping / ingestion / Admin APIs.

## Analytics

`publisher_view` (deduped 60s), `news_open`, existing `full_article_click` on detail CTA.

## Known limitations

- Dedicated publisher GET endpoints are not yet configured in Firestore for this app; fallback synthesizes publisher from article fields and filters news client-side.  
- No Home “Top Sources” strip (no ranking API).  
- Search list UI not rewritten; publisher tappable on Cut/Latest/Detail/Breaking when flag ON.  
- iOS build deferred.

## Validation

- `fvm flutter analyze`  
- `fvm flutter test` (feature suites)  
- `fvm flutter build apk --debug`  
