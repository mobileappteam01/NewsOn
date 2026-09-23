# NewsOn Phase 10D — Real Android Device + FCM End-to-End Validation

**Date:** 2026-09-17 (updated afternoon retry)  
**Mode:** Validation-first. No production V2 enablement. No production campaigns.  
**Verdict:** Device-specific FCM / deep-link / in-app flows **not verified**. Device is attached, but `flutter run` still fails before install (`Dart compiler exited` / Gradle **143** after ~22 min). Staging process was aborted mid-session.

---

## Executive summary

| Checkpoint | Evidence |
|------------|----------|
| Real Android device | Earlier session: `M2006C3LI` (`NR9H7DSO9HUKZ5KN`) authorized. **At report time: `adb devices` empty.** |
| Staging backend `:8010` | Was brought up successfully mid-session (health 200). **At report time: not listening.** |
| App on device | `com.app.newson` **never installed** — `flutter run` / assembleDebug aborted (`Dart compiler exited`, Gradle exit **143**). Disk ~**98%** full. |
| FCM / Admin campaign / FG·BG·terminated | **Not executed** — no running app + no durable staging send path completed. |

Per Phase 10D §1: with no authorized device now → **DEVICE VALIDATION REQUIRED** for all device-bound sections.

---

## A. Device connection status

**Status: ⚠️ DEVICE VALIDATION REQUIRED**

- Prior evidence: Xiaomi `M2006C3LI` connected over USB, `adb` authorized.
- Current: `List of devices attached` is empty → **STOP** further device claims.

---

## B. Staging URL / config status

**Status: ✅ FIXED** (config) / **❌ BLOCKED** (process not running now)

| Item | Status |
|------|--------|
| Flutter staging override | `--dart-define=NEWSON_API_BASE_URL=http://127.0.0.1:8010` (+ `adb reverse tcp:8010`) |
| Production Firebase `ipAddress` | Not permanently changed |
| Admin `VITE_API_BASE_URL` | Was **MISSING** → fell back to `api.newson.app`. **Fixed** via gitignored `newsadmin/.env.local` → `http://127.0.0.1:8010` |
| Staging process | Health **200** observed when running; **down at report time** |

Controlled Flutter flag overrides (staging-only dart-defines, RC production defaults remain false):

- `NEWSON_V2_NOTIFICATIONS_ENABLED`
- `NEWSON_V2_SEARCH_ENABLED`
- `NEWSON_V2_FOR_YOU_ENABLED`
- (optional Cuts/Detail defines for Cut→Detail path)

---

## C. FCM token registration

**Status: ❌ BLOCKED**

App never reached a stable install/run on device. No FCM token generation / `POST /api/notifications/devices` evidence.  
Note: registration requires **logged-in JWT** in current Flutter code — even after install, anonymous-only runs cannot register.

---

## D. Foreground notification

**Status: ⚠️ DEVICE VALIDATION REQUIRED** / **❌ BLOCKED**

No test campaign delivered to a live app session.

---

## E. Background notification

**Status: ⚠️ DEVICE VALIDATION REQUIRED** / **❌ BLOCKED**

---

## F. Terminated-app notification

**Status: ⚠️ DEVICE VALIDATION REQUIRED** / **❌ BLOCKED**

Critical path not exercised.

---

## G. Deep-link validation

**Status: ⚠️ DEVICE VALIDATION REQUIRED**

Unit/contract coverage for `type` / `articleId` / `route` / `campaignId` exists from Phase 7B — **not** a substitute for real-device open of `news_article` / `news_cut`.

---

## H. `notification_open` analytics

**Status: ⚠️ DEVICE VALIDATION REQUIRED**

Phase 10B fixed track body (`eventName`, top-level dims, `/api/analytics/track`). Device tap → backend ingest **not** observed here.

---

## I. Search real-device result

**Status: ⚠️ DEVICE VALIDATION REQUIRED**

Staging `GET /api/v2/search` worked when backend was up (Phase 10B + mid-session probe). **No on-device UI validation.**

---

## J. For You result

**Status: ⚠️ DEVICE VALIDATION REQUIRED**

Anonymous staging API previously returned `anonymous_fallback`.  
Authenticated: **AUTHENTICATED FOR YOU DEVICE VALIDATION REQUIRED** (no staging JWT / no app session).

---

## K. Article Detail result

**Status: ⚠️ DEVICE VALIDATION REQUIRED**

---

## L. Audio result

**Status: ⚠️ CONFIGURATION REQUIRED** / **⚠️ DEVICE VALIDATION REQUIRED**

Generation remains off by design. READY playback pending. Unavailable path not shown on device.

---

## M. Lifecycle result

**Status: ⚠️ DEVICE VALIDATION REQUIRED**

---

## N. V1 regression

**Status: ✅ VERIFIED** (defaults only)

Production RC V2 flags not enabled. Dart-define overrides are opt-in for staging runs only; unset → flags stay OFF (existing unit coverage).

---

## O. Defects discovered

| ID | Finding | Type |
|----|---------|------|
| P10D-1 | Admin missing `VITE_API_BASE_URL` → production API fallback (unsafe for test campaigns) | Config |
| P10D-2 | Device debug install/run failed repeatedly (Dart compiler exit / Gradle **143**); disk **~98%** | Environment |
| P10D-3 | Staging process not durable across sessions (must be restarted for validation) | Ops |
| P10D-4 | No device attached at report time | Device |

No new Flutter notification/deep-link logic defect proven on-device (app never ran).

---

## P. Exact fixes applied

1. **Admin staging config:** `newsadmin/.env.local` with `VITE_API_BASE_URL=http://127.0.0.1:8010` (gitignored via `*.local`) so Admin does not target production for campaigns.
2. **Staging-only Flutter flag dart-defines** in `V2FeatureFlags` so Search / For You / Notifications can be enabled for a device run **without** flipping production Remote Config.

---

## Q. Exact files changed

- `lib/core/config/v2_feature_flags.dart`
- `test/core/config/v2_feature_flags_define_test.dart` (new)
- `newsadmin/.env.local` (local, gitignored)
- `docs/V2_PHASE10D_DEVICE_FCM_VALIDATION.md` (this report)

---

## R. `fvm flutter test`

**Status: N/A this close-out** (no app-code defect fix in the final blocked pass; prior default suite was green in Phase 10B).  
Re-run after a successful device install workflow.

---

## S. `fvm flutter analyze`

**Status: N/A this close-out** for full suite. Changed flag accessor file is small/staging-only. Re-run with device workflow.

---

## T. Remaining blockers

1. **Reconnect** authorized Android device (`adb devices` must show one device).
2. **Free disk** (data volume ~98% full) so `assembleDebug` can finish without SIGTERM / compiler abort.
3. **Start staging** on `:8010` with V2 Search / For You / Notifications env flags; `adb reverse tcp:8010 tcp:8010`.
4. **`fvm flutter run -d <id>`** with staging dart-defines (do not use production RC enablement).
5. **Logged-in test user** for FCM device registration + Admin **test-audience** campaign against staging only.
6. Complete FG / BG / terminated + `notification_open` + Search / For You / Detail checks with log evidence.

**Not production ready. Do not claim FCM delivery.**

---

## Suggested next command (when device + disk OK)

```bash
adb reverse tcp:8010 tcp:8010
fvm flutter run -d <deviceId> \
  --dart-define=NEWSON_API_BASE_URL=http://127.0.0.1:8010 \
  --dart-define=NEWSON_V2_NOTIFICATIONS_ENABLED=true \
  --dart-define=NEWSON_V2_SEARCH_ENABLED=true \
  --dart-define=NEWSON_V2_FOR_YOU_ENABLED=true
```
