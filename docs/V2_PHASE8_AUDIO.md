# NewsOn V2 Phase 8 — Cost-Controlled Audio / Voice Backend

**Date:** 2026-09-16  
**Principle:** GENERATE ONCE → CACHE → REUSE  
**Defaults:** `V2_AUDIO_ENABLED=false`, `V2_AUDIO_GENERATION_ENABLED=false`, `V2_AUDIO_QUEUE_ENABLED=false`

V1 voice (`VoiceService`, GCS URLs, `audio_status`, `VOICE_TTS_TEMPORARILY_DISABLED`) is **unchanged** and remains independently gated off.

---

## Architecture

```
GET/POST /api/v2/audio/article/:id
  → ArticleAudioService (cache-first)
       → ArticleAudio (Mongo metadata only)
       → AudioQueueService.enqueue (BullMQ article-audio)
            → worker handleArticleAudioJob
                 → resolve NewsOn Cut summary text
                 → AudioProvider.generate (buffer only)
                 → S3 upload (deterministic key)
                 → status ready
```

HTTP **never** runs TTS synchronously.

---

## Provider abstraction

`AudioProvider` interface:

- `generate({ text, language, voiceId, outputFormat })`
- `isAvailable()`

Implementations:

| Provider | Config `V2_AUDIO_PROVIDER` |
|----------|----------------------------|
| `MockAudioProvider` | `mock` (default) |
| `GoogleCloudTtsAudioProvider` | `google_cloud_tts` |
| `GeminiAudioProvider` | `gemini` (falls back to Google when needed) |

Only **one** active provider. Providers do not touch Mongo, queues, or users.

If credentials unavailable → generation fails safely (`provider_unavailable`); no silent V1 re-enable.

---

## Cache identity

Unique: `(articleId, language, voiceId)`

Content hash:

```
generateAudioContentHash(text, language, voiceId, version=v1)
```

Summary text change → new hash → re-request required (old object key preserved).

---

## Storage

S3 key (deterministic, never overwrite another hash):

```
audio/{language}/{voiceId}/{contentHash}.{format}
```

No audio binaries in Mongo. Optional `V2_AUDIO_PUBLIC_URL_BASE` for public URLs.

---

## Queue

BullMQ queue: `article-audio`  
Job id: `article-audio:{articleId}:{language}:{voiceId}:{contentHash}`

Idempotent enqueue (duplicate waiting/active skipped).

Requires: `REDIS_ENABLED` + `REDIS_URL` + `V2_AUDIO_QUEUE_ENABLED=true`.

---

## Cost controls

| Env | Default |
|-----|---------|
| `V2_AUDIO_ENABLED` | false |
| `V2_AUDIO_GENERATION_ENABLED` | false |
| `AUDIO_MAX_INPUT_CHARS` | 2500 |
| `AUDIO_MAX_DURATION_SECONDS` | 180 |
| `AUDIO_MAX_DAILY_GENERATIONS` | 200 |
| `AUDIO_MAX_GENERATION_ATTEMPTS` | 3 |

Both V2 audio flags required for new generation.  
Cached retrievals do not count toward daily generation.

Input = NewsOn Cut / canonical summary only — **not** full article body.

---

## Generation lifecycle

`unavailable` → `queued` → `generating` → `ready` | `failed`

Client statuses: `ready` | `processing` | `unavailable` | `failed`

Retries: transient provider errors only; permanent (invalid input, auth, unsupported language) do not loop.

---

## API

| Method | Path | Auth |
|--------|------|------|
| GET | `/api/v2/audio/article/:articleId` | Optional |
| POST | `/api/v2/audio/article/:articleId/request` | Optional |

Ready response:

```json
{ "status": "ready", "audioUrl": "...", "durationMs": 123000 }
```

Rejects `body.text` / `body.content` (no arbitrary TTS).

---

## Provider health

In-process `AudioProviderHealthService`: last success/failure, counts, latency.

---

## Admin diagnostics

| Method | Path |
|--------|------|
| GET | `/api/admin/audio/overview` |
| GET | `/api/admin/audio/:articleId` |

AdminAuthentication required. No credentials / raw provider secrets.

---

## Analytics

Mobile emits existing `audio_click`. Generation metrics stay on `ArticleAudio` / health — not inflated into user DAU.

---

## Feature flags / rollback

Set all V2 audio flags `false`. V1 remains independent. No migration rollback needed.

---

## Rollout

1. Flags OFF  
2. Enable retrieval only in QA (`V2_AUDIO_ENABLED=true`, generation still false)  
3. Enable generation for small set (`V2_AUDIO_GENERATION_ENABLED` + queue + Redis + mock/provider)  
4. Observe daily count / failures / cost  
5. Expand only after validation  

**Do not auto-enable production generation.**

---

## Limitations

- Duration estimate may be approximate for mock / when provider does not return exact length  
- S3 credentials required for real uploads when generation enabled  
- In-process health metrics reset on process restart  
- Does not migrate or replace V1 GCS title/description/content audio URLs  
- Queue shares Redis with summary queue when both enabled  

---

## Migration strategy

Additive only. Old V1 audio fields stay. New clients use `/api/v2/audio`. No rewrite of historical voice URLs.
