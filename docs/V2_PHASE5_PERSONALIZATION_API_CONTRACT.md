# V2 Phase 5 — Personalization API Contract

**Date:** 2026-09-16  
**Status:** Preferred public contract for mobile. This Flutter repo documents the
contract; ranking lives on the **backend**. Mobile does **not** re-score feeds.

## Current mobile reality (Phase 9)

| Capability | Mobile call when V2 flag ON | Notes |
|------------|-------------------------------|-------|
| For You | `GET /api/v2/for-you` via `V2ForYouApi` | Optional JWT; anonymous → backend `anonymous_fallback` |
| Search | `GET /api/v2/search` via `SearchRepository` | `q` + language + region |
| Interactions | `InteractionService` | open / read / bookmark / share / category_click |
| Analytics | Phase 1D `AnalyticsService` | separate from UserInteraction |

V1 tabs continue to use Firestore `news/forYou` and `BackendNewsService.searchNews`.

Preferred REST shapes below match backend Phase 6.

---

## GET /api/v2/for-you

**Auth:** required (user-scoped).  
**Query:**

| Param | Type | Notes |
|-------|------|-------|
| `userId` | string | Authenticated user |
| `language` | string | **News** language code/name (not UI locale) |
| `region` | object/fields | Existing region: `country`, `state`, `district` |
| `page` | int | ≥ 1 |
| `limit` | int | Bounded (mobile default 15, max ≤ 50) |

### Success (conceptual)

```json
{
  "message": "ok",
  "pagination": {
    "total": 120,
    "page": 1,
    "limit": 15,
    "totalPages": 8,
    "hasNextPage": true,
    "hasPrevPage": false
  },
  "articles": [ /* NewsArticle[] — no personalization scores, no PII */ ]
}
```

### Behavior

- Backend `PersonalizationService` generates bounded candidates, ranks
  deterministically, suppresses recent strong engagement, applies language/region.
- Cold start (no history): region + language + latest / popular — **never empty
  solely because personalization is missing**.
- Empty personalized page → mobile may call latest/today with region+language
  as **cold-start fallback** (no client ranking).

### Privacy

Do **not** return: internal scores, raw analytics payloads, email/phone/tokens.

---

## GET /api/v2/search

**Auth:** as existing project convention.  
**Query:**

| Param | Type | Notes |
|-------|------|-------|
| `q` / `search` | string | min 2, max 100 after trim |
| `language` | string | news language |
| `country` / `state` / `district` | string | optional region filters |
| `page` | int | ≥ 1 |
| `limit` | int | default 20, max 50 |
| `publisherId` / `category` | string | when schema supports |

### Validation

- Reject / soft-fail queries outside length bounds.
- Safe regex / indexed text search only — no unrestricted collection scans.
- Prefer text index on `title`, `description`, `source_name` **after** auditing
  existing indexes. Do **not** require MongoDB Atlas Search for Phase 5.

### Success

Same article list shape as other news list endpoints (`results` / `articles` +
pagination). No personalization scores.

---

## Analytics (client)

| Event | When |
|-------|------|
| `search` | Submitted / executed search only (not keystrokes) |
| `for_you_impression` | Section + per-article, deduped |
| `news_open` / `summary_view` / `full_article_click` | Article funnel |
| `bookmark` / `share` | Interactions |
| `publisher_view` / `category_view` | Discovery |

Analytics does **not** auto-create `UserInteraction`.

---

## Feature flags

| Key | Default | Effect when false |
|-----|---------|-------------------|
| `v2_search_enabled` | `false` | V1 `SearchTab` |
| `v2_for_you_enabled` | `false` | V1 `ForYouTab` / `ForYouProvider` |

---

## Not in this contract

- Admin personalization UI  
- ML / embeddings / vector DB  
- Subscriptions / notifications / campaigns / audio generation  
- Fabricated historical preference data  
