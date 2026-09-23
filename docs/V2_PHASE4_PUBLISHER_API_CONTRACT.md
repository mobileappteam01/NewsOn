# V2 Phase 4 — Publisher API Contract

**Date:** 2026-09-16  
**Status:** Preferred public contract. Mobile does **not** call Admin CRUD.

## Current mobile reality

As of Phase 4, the Flutter app has **no configured Firestore `apiEndPoints` module** for publishers in-repo.

`PublisherApi` attempts:

| Module | Endpoint key | Purpose |
|--------|--------------|---------|
| `publishers` | `getById` | Publisher metadata |
| `publishers` | `news` | Paginated NewsOn articles for publisher |

If these keys are missing or fail, `PublisherRepository` falls back to:

1. Synthesize `PublisherModel` from article provenance (`sourceName` / `sourceId` / `sourceIcon` / `sourceUrl` / optional `publisherId`)
2. Filter NewsOn news via existing `BackendNewsService.searchNews` / `fetchTodayNews` by publisher identity

No scraping. No Admin APIs. No fabricated publisher rankings.

---

## Preferred: GET publisher by id/slug

**Logical path:** `GET /api/publishers/:publisherId`  
**Firestore mapping:** module `publishers`, key `getById`  
**Query (mobile sends):** `publisherId`, `id`, `slug` (same value)

### Success response (conceptual)

```json
{
  "data": {
    "_id": "pub_123",
    "name": "The Hindu",
    "slug": "the-hindu",
    "logoUrl": "https://cdn.example/logo.png",
    "websiteUrl": "https://www.thehindu.com",
    "description": "Optional short description",
    "languageCodes": ["en"],
    "countryCodes": ["in"],
    "attributionName": "The Hindu",
    "attributionUrl": "https://www.thehindu.com",
    "isActive": true,
    "source_name": "The Hindu",
    "source_id": "the-hindu"
  }
}
```

### Errors

| Case | Expected |
|------|----------|
| Unknown id | 404 / empty → mobile shows unavailable |
| Inactive | `isActive: false` → mobile treats as unavailable |
| Network | soft error + Retry |

Do **not** expose adapter keys (`generic_rss`, `newsdata`) as display names.

---

## Preferred: GET publisher news

**Logical path:** `GET /api/publishers/:publisherId/news`  
**Firestore mapping:** module `publishers`, key `news`

### Query

| Param | Type | Notes |
|-------|------|--------|
| `publisherId` / `id` / `slug` | string | Publisher identity |
| `page` | int | 1-based |
| `limit` | int | default 20 |
| `language` | string | News language (not app UI language) |

### Success response (conceptual)

```json
{
  "results": [ /* NewsArticle objects already permitted for NewsOn */ ],
  "pagination": {
    "page": 1,
    "limit": 20,
    "total": 120,
    "hasMore": true
  }
}
```

Also accepted: `data.results`, `news`, `articles`.

### Sorting

Newest first (server-side). Mobile does not invent ranking.

### Filters

Only NewsOn-served articles. No full publisher feed body. No deleted/inactive articles.

---

## Article provenance fields (existing)

| Field | JSON |
|-------|------|
| `source_name` | display brand |
| `source_id` | legacy source key |
| `source_url` | often article/source site |
| `source_icon` | logo |
| `publisher_id` / nested `publisher` | optional entity id (Phase 4 parse) |

---

## Licensing boundary

Publisher pages show only content already available via NewsOn article APIs.  
Full article remains an external link to the original URL.  
No implication that NewsOn republishes full publisher content.
