# NewsOn V2 Phase 7 — Notifications + Re-engagement Foundation

**Date:** 2026-09-16  
**Scope:** Safe, targeted, measurable V2 campaign notifications.  
**Defaults:** `V2_NOTIFICATIONS_ENABLED=false`, `V2_NOTIFICATION_SCHEDULER_ENABLED=false`.

V1 in-app notifications (`/api/notification-admin`, `/api/notification-user`) and `SendNotification.ts` / `fcmTokenUser` remain unchanged.

**No campaign is sent unless flags are ON and an admin explicitly calls send (or scheduler is enabled for due campaigns).**

---

## Architecture

```
Admin API (/api/admin/notifications)
  → NotificationCampaignService
       → NotificationAudienceService (bounded cursor)
       → NotificationFrequencyService (caps + prefs)
       → NotificationFcmDeliveryService (batched FCM)
       → NotificationDelivery rows

Mobile (/api/notifications/preferences|devices)
  → preference updates / DeviceToken registry

Analytics notification_open + metadata.campaignId
  → markDeliveryOpened (send ≠ open)
```

---

## Campaign lifecycle

`draft` → `scheduled` (optional) → `sending` → `sent` | `failed`  
Also: `cancelled` from draft/scheduled.

Idempotent send: atomic claim + `sendIdempotencyKey` prevents repeat sends.

Statuses: draft | scheduled | sending | sent | cancelled | failed.

---

## Audience rules

Explicit DTO only (no raw Mongo):

| Field | Meaning |
|-------|---------|
| `allUsers` | Eligible users with prefs allowing notifications |
| `activity` | `active` / `inactive` / `all` |
| `language` / `languages` | newsLanguage / appLanguage |
| `countryId` / `stateId` / `districtId` | preferred region ObjectIds |
| `categoryId` | category preference or categoryScores > 0 |
| `publisherId` | optional; only when reliable IDs exist |

**Not accepted from admin DTO:** arbitrary `userIds` lists.

Audience resolution: cursor batches (`_id` ascending), max 5,000 users default, projection limited.

---

## Preferences

Mobile API (authenticated, JWT user only):

- `GET/PATCH /api/notifications/preferences`
- Fields: `notificationsEnabled`, `breakingNewsEnabled`, `categoryNotificationsEnabled`, `publisherNotificationsEnabled`

Defaults when unset: **enabled** (backward compatible). Master off blocks all campaign types.

Stored on `user.notificationPreferences` (additive fields; existing data not wiped).

---

## Frequency controls

| Constant | Default |
|----------|---------|
| Min hours between non-breaking | 6 |
| Max non-breaking per user / UTC day | 3 |
| Breaking news | bypasses interval/daily caps; still respects `notificationsEnabled` + `breakingNewsEnabled` |
| Max delivery attempts concept | 3 |

---

## FCM delivery

- Batch size ≤ 500 (default 100)
- Uses `admin.messaging().sendEachForMulticast`
- Invalid tokens → disable `DeviceToken`, unset matching `fcmTokenUser`, pull from `devices[]`
- Temporary failures recorded; no infinite retry loop
- Tokens never logged or returned in APIs
- Delivery stores `deviceRef` (opaque), not raw token

V1 `fcmTokenUser` still works as fallback token source.  
V2 `POST /api/notifications/devices` registers into `device_tokens` + syncs V1 field.

---

## Deep links

FCM `data` payload (strings only):

```json
{
  "type": "news_article",
  "articleId": "...",
  "route": "/news/...",
  "campaignId": "..."
}
```

Types: `news_article` | `news_cut` | `category` | `publisher` | `home`.

No article body / Mongo document in payload.

### Mobile open contract

| App state | Expected |
|-----------|----------|
| Foreground | Show / route via payload |
| Background tap | Navigate `route` |
| Terminated tap | Cold start → `route` |

Invalid payload → home / notification inbox safely.

Client should emit analytics `notification_open` with `metadata.campaignId`.

---

## Analytics

- Reuses Phase 1D `notification_open`
- Delivery `opened` / `openedAt` updated only from open events — **not** from send success
- Send attempts do not inflate opens
- Reporting distinguishes: providerAccepted (sent) ≠ device delivery guarantee ≠ open

---

## Security

- All campaign admin routes: `AdminAuthentication`
- Send endpoint: `destructiveRateLimiter`
- No FCM tokens / email / phone in preview or reports
- Preview samples use masked `userRef` (`u_` + last 6 of id)
- User isolation on preferences
- Feature flag gate on all mutating campaign ops

---

## Scheduler

`src/jobs/notificationScheduler.ts` — in-process interval.

**Single-process limitation:** enable `V2_NOTIFICATION_SCHEDULER_ENABLED` on one Node instance only. Same-campaign overlap still blocked by status claim.

---

## Admin APIs

| Method | Path |
|--------|------|
| GET | `/api/admin/notifications/campaigns` |
| GET | `/api/admin/notifications/campaigns/:id` |
| POST | `/api/admin/notifications/campaigns` |
| PATCH | `/api/admin/notifications/campaigns/:id` |
| POST | `/api/admin/notifications/campaigns/:id/cancel` |
| POST | `/api/admin/notifications/campaigns/:id/preview-audience` |
| POST | `/api/admin/notifications/campaigns/:id/send` |

Header `Idempotency-Key` optional on send.

---

## Feature flags / rollback

| Env | Default |
|-----|---------|
| `V2_NOTIFICATIONS_ENABLED` | `false` |
| `V2_NOTIFICATION_SCHEDULER_ENABLED` | `false` |

Rollback: set both false. V1 continues. No destructive migration.

---

## Limitations

- In-process scheduler (not multi-replica safe without external lock)
- Frequency checks are per-user DB queries (batched users, not batched caps)
- FCM “sent” means provider accepted — not confirmed device delivery
- No AI-generated notification copy
- No automatic breaking-news fanout on every article
- `publisherId` audience only useful when articles/users have publisher linkage
- Does not migrate historical V1 inbox notifications into Campaign/Delivery

---

## Production activation checklist

1. Ensure indexes (campaign status/scheduleAt, deliveries, device_tokens)
2. Staging: `V2_NOTIFICATIONS_ENABLED=true`, scheduler OFF
3. Create draft → preview-audience → send to small language/region audience
4. Verify preference opt-out and frequency caps
5. Enable scheduler only on one instance if needed
6. Never enable in production without ops review
