# NewsOn Phase 10 — Real Backend + Device Integration Validation

**Date:** 2026-09-16  
**Mode:** Validation-first (no redesign; no global V2 enablement; no fake data; no APK/iOS builds)  
**Code changes this phase:** none (no proven Flutter integration defect)

---

## Executive verdict

Phase 10 **cannot claim production readiness** for V2 Search, For You, Audio, Notifications, Cuts, or Publisher flows against a live V2 stack.

Evidence shows:

1. **Production host `https://api.newson.app` serves V1** (`GET /api/latestnews/getActiveNewsMobile` → HTTP 200, live article payload).
2. **V2 mobile routes are not present on that host** (`/api/v2/search`, `/api/v2/for-you`, `/api/v2/audio/article/:id` → HTTP 404 Not Found).
3. **Phase 0 health route is not present on production** (`GET /api/health` → HTTP 404). Sibling `newsbackend` source *does* register `/api/health` and `/api/v2/*`, so production appears to be an older / non-V2 deployment relative to local backend source.
4. **Local backend is not running** (`127.0.0.1:8000` connection refused).
5. **No Android device attached** (`adb devices` empty) — real-device notification / lifecycle validation blocked.
6. **Local `newsbackend` `.env` omits all `V2_*` keys** → runtime defaults **false**; Redis config absent; `VOICE_GENERATION_ENABLED=false`, `VOICE_GENERATION_PAUSED=true`.
7. Flutter Remote Config / in-app defaults keep all V2 flags **false** (V1 preserved by design).

No Flutter code was changed. No tests were weakened.

---

## A. Environment readiness

**Status: ⚠️ CONFIGURATION REQUIRED**

### Backend (`newsbackend` local `.env` — key presence only; secrets redacted)

| Item | Evidence |
|------|----------|
| `PORT` | `8000` |
| `MONGO_URI` | present |
| `GEMINI_API_KEY` | present |
| `V2_SEARCH_ENABLED` | **MISSING** → defaults `false` (per `.env.example` / `v2SearchPersonalizationConfig`) |
| `V2_FOR_YOU_ENABLED` | **MISSING** → defaults `false` |
| `V2_AUDIO_*` | **MISSING** → defaults `false` |
| `V2_NOTIFICATIONS_*` | **MISSING** → defaults `false` (example file) |
| Redis (`REDIS_URL` / `REDIS_HOST`) | **MISSING** |
| `VOICE_GENERATION_ENABLED` | `false` |
| `VOICE_GENERATION_PAUSED` | `true` |
| Process listening on `:8000` | **No** |

`.env.example` documents the intended V2 flag surface (all default `false`). Those keys were **not** copied into the active local `.env`.

### Flutter (`NewsOn`)

| Item | Evidence |
|------|----------|
| `.env` | Only non-Firebase secret key present: `NEWSDATA_API_KEY` (redacted). No local `v2_*` overrides. |
| API base URL | Resolved at runtime via `ApiService` / Firestore endpoint config (not hardcoded V2 base in `.env`). Deep-link host: `api.newson.app`. |
| Firebase | `android/app/google-services.json` and `ios/Runner/GoogleService-Info.plist` present on disk. |
| Remote Config defaults | All V2 flags default `false` in `RemoteConfigService` and `firebase_remote_config_template.json`. |
| V2 clients (code) | Search → `GET /api/v2/search`; For You → `GET /api/v2/for-you`; Audio → `GET/POST /api/v2/audio/article/:id` (Phase 9 contracts). |

### Admin (`newsadmin`)

| Item | Evidence |
|------|----------|
| API base | Documented / configured toward `https://api.newson.app` |
| `VITE_V2_ADMIN_SHELL` | Development can enable shell; production guidance is keep false until QA |
| Notification campaigns / analytics / audio admin | Cannot be exercised against production V2 APIs while `/api/v2/*` returns 404 |

---

## B. Backend health status

**Status: ❌ BLOCKED** (for V2 validation targets)

| Target | Result |
|--------|--------|
| `http://127.0.0.1:8000/api/health` | Connection refused (backend not running) |
| `https://api.newson.app/api/health` | HTTP **404** `Not Found - /api/health` |
| `https://api.newson.app/health` | HTTP **404** |
| `https://api.newson.app/api/latestnews/getActiveNewsMobile?...` | HTTP **200** (V1 alive; Mongo path functional for V1 news) |
| `https://api.newson.app/api/v2/search?...` | HTTP **404** |
| `https://api.newson.app/api/v2/for-you?...` | HTTP **404** |
| `https://api.newson.app/api/v2/audio/article/test` | HTTP **404** |

**Interpretation:** Production is reachable and serving V1. It does **not** expose the V2 route tree or Phase 0 health endpoint that exists in current `newsbackend` source (`app.get("/api/health")`, `app.use("/api/v2", ...)`). Authentication, Redis, and FCM connectivity for V2 were **not** validated (no live V2 surface).

---

## C. Search real-backend result

**Status: ❌ BLOCKED**

- Production `GET /api/v2/search` → **404** (route absent; not a feature-gate 4xx/5xx from `V2SearchService`).
- Local backend not running → cannot exercise valid/min/invalid query, pagination, empty/populated results, or text-index presence.
- Flutter Search against real backend **not executed** (would hit 404 or offline local).

Required Flutter fields (`articleId`, title, description, summary fields, image, publisher, etc.) **not** confirmed on a live response in this phase.

---

## D. For You real-backend result

**Status: ❌ BLOCKED**

- Production `GET /api/v2/for-you` → **404**.
- Auth / anonymous / cold-start / history / empty / failure matrix **not** run.
- No claim about ranking fields vs `V2FeedItemMapper` on live data.
- Empty ranked response vs API-failure fallback behavior remains covered by prior Phase 9 unit tests only — **not** re-validated live.

---

## E. NewsOn Cuts real-data result

**Status: ⚠️ CONFIGURATION REQUIRED** / **❌ BLOCKED** for AI summary states

- V1 article list works on production (sample article returned).
- `v2Summary` / pending / unavailable / failed Cuts states require V2 article summary pipeline + Flutter Cuts flags.
- Local: `GEMINI_API_KEY` present, but backend not running; V2 AI/summary feature flags not set in `.env`.
- `VOICE_GENERATION_*` is paused/disabled (audio-adjacent; not Cuts summaries).
- **Do not invent summaries.** Live Cuts AI-state matrix **not verified**.

---

## F. Publisher result

**Status: ⚠️ CONFIGURATION REQUIRED**

- Publisher pages remain behind Remote Config (`v2_publisher_pages_enabled` default false).
- End-to-end Article → Publisher → articles **not** validated on device against configured Firestore/backend publisher data in this phase.
- Not claimed production-ready.

---

## G. Notification real-device result

**Status: ⚠️ DEVICE VALIDATION REQUIRED** / **❌ BLOCKED**

| Check | Result |
|-------|--------|
| Android device via `adb` | **No devices attached** |
| Admin test campaign → FG / BG / terminated | **Not performed** |
| Payload (`type`, `articleId`, `route`, `campaignId`) | **Not performed** |
| Tap → route → `notification_open` | **Not performed** |
| Duplicate navigation / open events | **Not performed** |

Unit/integration coverage from Phase 7B remains the only evidence; **not** a substitute for real-device FCM.

---

## H. Audio real-backend/device result

**Status: ❌ BLOCKED** / **⚠️ CONFIGURATION REQUIRED**

- Production `/api/v2/audio/article/:id` → **404**.
- Local: `V2_AUDIO_*` unset (default false); Redis missing (queue required when generation/queue enabled); `VOICE_GENERATION_ENABLED=false`, `VOICE_GENERATION_PAUSED=true`.
- Playback / lifecycle / cache / no unnecessary regeneration **not** validated live.
- Old synchronous expensive TTS was **not** re-enabled (no code change).

---

## I. Analytics result

**Status: ⚠️ DEVICE VALIDATION REQUIRED**

- Controlled device activity → backend/admin analytics verification **not** performed (no device; V2 surfaces not live on production).
- Canonical event list not observed end-to-end in this phase.
- Prior unit coverage for session / event naming remains; live duplicate-event checks **not** done.

---

## J. Remote Config result

**Status: ✅ VERIFIED** (defaults / false-path design only)

| Flag | Template + in-app default | Live rollout this phase |
|------|---------------------------|-------------------------|
| `v2_search_enabled` | `false` | **Not enabled** |
| `v2_for_you_enabled` | `false` | **Not enabled** |
| `v2_audio_enabled` | `false` | **Not enabled** |
| `v2_audio_generation_enabled` | `false` | **Not enabled** |
| `v2_notifications_enabled` | `false` | **Not enabled** |
| Cuts / publisher / home V2 flags | default `false` in `RemoteConfigService` | **Not enabled** |

Controlled sequential enablement (Search → For You → Cuts → …) **was not executed** because backend V2 was unreachable. False defaults correctly preserve V1 by design (code + template evidence).

---

## K. V1 regression result

**Status: ✅ VERIFIED** (production smoke only; limited scope)

- Production V1 news mobile endpoint returns HTTP 200 with paginated article data.
- Flutter V2 flags remain default-off → V1 Search / For You / voice paths remain the active product paths without Remote Config overrides.
- Full manual V1 regression matrix (ads, auth UI, home gestures) **not** re-run on device (no device). No V1 code was rewritten this phase.

---

## L. Bugs discovered

| ID | Finding | Severity |
|----|---------|----------|
| P10-1 | Production `api.newson.app` does not expose `/api/v2/*` (404) despite Flutter clients targeting those paths when flags are on | **Environment / deploy blocker** |
| P10-2 | Production missing `/api/health` (404) while current `newsbackend` source defines it | **Deploy / version mismatch** |
| P10-3 | Local backend not running; local `.env` missing all `V2_*` and Redis | **Local env blocker** |
| P10-4 | No Android device attached for FCM / lifecycle / analytics | **Device blocker** |

No Flutter contract/mapping defect was newly proven against a live V2 response in this phase (cannot call V2).

---

## M. Exact fixes applied

**None.** Per phase policy: only fix proven integration defects. Blockers are deployment, configuration, and device availability—not Flutter code bugs demonstrated against live V2.

---

## N. Exact files changed

**None** (report document only: `docs/V2_PHASE10_INTEGRATION_VALIDATION.md`).

---

## O. `fvm flutter test` result

**Status: N/A this phase (no code changes)**

Last verified baseline cited before this phase: **151/151 passed**. Suite was **not** re-run here because no application code changed. Re-run required after any future fix.

---

## P. `fvm flutter analyze` result

**Status: N/A this phase (no code changes)**

Last verified baseline: **0 errors, 0 warnings**. Not re-run this phase for the same reason.

---

## Q. Remaining blockers

1. **Deploy (or point Flutter at) a backend build that includes Phase 0 health + Phase 6/7/8 `/api/v2` routes.**
2. **Set explicit backend env** (staging first): `V2_SEARCH_ENABLED`, `V2_FOR_YOU_ENABLED`, audio/notification flags, Redis for queues — without enabling all production flags at once.
3. **Ensure Mongo text index** for Phase 6 search is created/synced on the target environment.
4. **Start a local or staging backend** with those flags for contract probes before any RC rollout.
5. **Attach a real Android device** and run Admin **test-audience-only** notification campaign (FG/BG/terminated).
6. **Confirm Remote Config** values in Firebase console for the test app instance (do not permanently enable all production flags).
7. **Gemini / summary pipeline** must be enabled intentionally if Cuts summary states are to be validated with real AI output.

---

## R. Device/configuration-only limitations

- No USB/wireless Android device in `adb`.
- No permission to invent secrets or invent successful live V2 responses.
- Production V1 host ≠ V2-capable API surface (404 on V2).
- Local `.env` incomplete vs `.env.example` V2 section.
- Admin campaign / FCM / analytics admin verification requires authenticated admin session + working notification backend — not available in this validation window.
- APK/iOS builds intentionally not run (Phase 10 build policy).

---

## Recommended next validation sequence (ops, not code)

1. Deploy current `newsbackend` (or staging) with health + `/api/v2` mounted.
2. Enable **only** `V2_SEARCH_ENABLED=true` on staging → probe search matrix → then Flutter RC `v2_search_enabled=true` on a test cohort.
3. Repeat for For You, then Cuts/publisher, then notifications (device), then audio (Redis + provider), then analytics spot-checks.
4. Keep production RC V2 flags **false** until each stage has evidence.

---

## Status legend used

| Symbol | Meaning |
|--------|---------|
| ✅ VERIFIED | Evidence collected supporting the claim |
| ⚠️ CONFIGURATION REQUIRED | Code may exist; env/flags/secrets/indexes missing |
| ⚠️ DEVICE VALIDATION REQUIRED | Needs real device / FCM / lifecycle |
| ❌ BLOCKED | Cannot validate with current environment |
| ✅ FIXED | Defect fixed in this phase (unused — no fixes) |
