# V2 Phase 5 — Search + For You + Personalization Report

**Branch:** `feature/v2.0.0-phase-5-personalization`  
**Base:** Phase 4 publishers branch  
**Date:** 2026-09-16  
**Repo scope:** Flutter mobile (backend ranking documented; Node service not in this repo)

## Ranking architecture

Personalization ranking is **backend-owned**. Mobile:

1. Calls existing `news/forYou` via `ForYouService`
2. On empty / failure (page 1), applies **cold-start fallback** via today/breaking
   news with news language + applied region
3. Does **not** re-implement scoring on device

Documented constants: `lib/features/for_you/domain/personalization_ranking_config.dart`

| Factor | Role | Notes |
|--------|------|-------|
| Recency | Stronger for recent items | Half-life documented (36h) |
| Category preference | Affinity | Bounded weight |
| Publisher affinity | Only when `publisherId` exists | No text guessing |
| Region | district → state → country → global | Existing region IDs |
| Language | News language ≠ UI locale | |
| Engagement | bookmark > share > open ≫ impression | Clamped; one click cannot dominate |

Scores clamp to `[0, 1]`. Decay / weights centralized — not scattered in UI.

## Candidate generation (backend preferred)

Bounded pools: preferred categories + publishers + regional + latest fallback →
dedupe by article ID → rank → paginate. No full-collection scoring.

## Signals

| Stronger | Weaker |
|----------|--------|
| bookmark, share, open/read | impression, single category click |

`AnalyticsEvent` remains separate from `UserInteraction`. Analytics do **not**
mutate categoryScores directly on the client.

## Suppression

Already-seen uses bounded windows (documented hours). Impression alone must not
permanently hide. Strong engagement reduces duplicate exposure more than a glance.

## Cold start

New / thin history → region + language + latest/popular. UI copy switches to
fallback subtitle; never “you have no personalized content” when general news
is available.

## Search

Module: `lib/features/search/`

- Query validation (2–100)
- Local recent searches (bounded, deduped, clear all)
- Debounced **local** suggestions only (no fabricated server suggestions)
- Submit → `search` analytics (query length only; no sensitive logging)
- Results reuse Cut / Latest cards + bookmark/share

## For You (mobile)

Module: `lib/features/for_you/`

- `ForYouRepository` + `ForYouController` + `V2ForYouTab`
- Lazy list, pagination only for personalized source
- Impression dedupe (section + per article)

## Feature flags

| Flag | Default |
|------|---------|
| `v2_search_enabled` | false → V1 `SearchTab` |
| `v2_for_you_enabled` | false → V1 `ForYouTab` |

## Analytics

Phase 1D: `search`, `for_you_impression`, `news_open`, `bookmark`, `share`, etc.
Duplicate impressions prevented via dedupe windows.

## Rollback

Set both flags false in Remote Config — V1 Search and For You unchanged.

## Known limitations

- Backend `PersonalizationService` / dedicated `GET /api/search` may still map
  through existing Firestore endpoints; this repo documents preferred contract.
- No Mongo text-index migration in this Flutter repo.
- No Admin personalization UI.
- No ML / embeddings / subscriptions / notifications / audio generation.
- iOS build not run in Phase 5 validation (Android debug APK only).
- Client cold-start is deterministic latest/region/language, not a second ranker.

## Validation

- `fvm flutter analyze` (Phase 5 modules) — pass (1 pre-existing prefer_const info)
- `fvm flutter test test/features` — pass
- `fvm flutter build apk --debug` — pass (`app-debug.apk`)
- Backend `npm test` / `tsc` / `build` — **N/A** (no Node backend in this Flutter repo)
- iOS build — deferred per Phase 5 instructions
