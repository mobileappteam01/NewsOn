# V2 Phase 9 — Flutter Integration Audit Report

**Date:** 2026-09-16  
**Scope:** Audit → verify contracts → fix proven mismatches only.

## Proven mismatch fixed

| Feature | Was | Now (when V2 flags on) |
|---------|-----|-------------------------|
| Search | V1 `news/breakingNews` + `search=` | `GET /api/v2/search?q=` |
| For You | Firestore `news/forYou` only | `GET /api/v2/for-you` via `V2ForYouApi` |

V1 `ForYouService` / `BackendNewsService.searchNews` **unchanged** for V1 tabs.

## Mapper

`V2FeedItemMapper` adapts Phase 6 `{ articleId, image, publisher, v2Summary, … }`
into `NewsArticle` without dropping Cut / publisher fields.

## Unchanged (audit OK)

- Audio → `/api/v2/audio/article/:id` (+ `/request`)
- Notifications Phase 7B allowlisted deep links + dedupe
- Analytics event names + session dedupe windows
- Remote Config V2 flags default `false`
- NewsOn Cuts resolver (v2Summary → aiSummary → never fake)
