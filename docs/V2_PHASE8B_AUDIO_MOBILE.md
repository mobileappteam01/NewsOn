# V2 Phase 8B — Flutter Audio Player Integration

**Branch:** `feature/v2.0.0-phase-8b-audio-mobile`  
**Date:** 2026-09-16  
**Backend contract:** `newsbackend/docs/V2_PHASE8_AUDIO.md`

## Principle

**Fetch existing audio first.** Only POST generation when status is
`unavailable`/`failed` **and** `v2_audio_generation_enabled=true`.

No client-side TTS. No automatic generation on screen open.

## Module

`lib/features/audio/`

| Layer | Role |
|-------|------|
| `domain/article_audio.dart` | Status enum + payload |
| `domain/audio_state.dart` | UI phases |
| `data/audio_api.dart` | GET/POST `/api/v2/audio/article/:id` |
| `data/audio_repository.dart` | Short TTL ready-cache |
| `data/v2_audio_playback_service.dart` | Dedicated `just_audio` player |
| `presentation/audio_controller.dart` | Listen flow + polling |
| `presentation/widgets/*` | Listen button, bar, sheet |

## API

| Method | Path |
|--------|------|
| GET | `/api/v2/audio/article/:articleId` |
| POST | `/api/v2/audio/article/:articleId/request` |

Optional Bearer token. Never sends `text`/`content`. Never sends userId in body.

## State machine

```
Listen tap
  → GET status
      ready → play URL
      processing → poll (3s, max ~60s / 20 ticks)
      unavailable → POST if generation flag ON else hide
      failed → POST if generation flag ON else Retry UI
      API error → soft error (article still readable)
```

Polling stops on: ready, non-processing terminal status, timeout, dispose.

## Player

Single shared `V2AudioPlaybackService` (just_audio). Starting article B stops A.
Independent of V1 `AudioPlayerProvider` / ElevenLabs / VoiceService.

## Cache

In-memory ready status cache TTL 5 minutes. Backend remains source of truth.
Bypass cache while polling.

## Analytics

`audio_click` via `AnalyticsService.audioClick` — only on user Listen/Retry tap.
Not on poll, build, or status fetch.

## Feature flags (Remote Config)

| Key | Default |
|-----|---------|
| `v2_audio_enabled` | false |
| `v2_audio_generation_enabled` | false |

When `v2_audio_enabled=false`: no V2 Listen UI; V1 voice unchanged.

## UI placement

- Article detail: Listen under NewsOn Cut + optional bottom player bar
- Home Cut card: compact Listen icon only (no embedded large player)

## V1 fallback

`VoiceService`, GCS audio, `audio_status`, `AudioPlayerProvider`, mini player remain.

## Known limitations

- Playback uses a separate just_audio instance (not audio_service notification by default)
- Generation depends on backend flags + Redis queue
- iOS validation manual
- Firestore endpoint keys optional; path fallback `/api/v2/audio/...` used
