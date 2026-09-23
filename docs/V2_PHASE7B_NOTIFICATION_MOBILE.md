# V2 Phase 7B — Flutter Notification + Deep-Link Integration

**Branch:** `feature/v2.0.0-phase-7b-notification-mobile`  
**Date:** 2026-09-16  
**Backend contract:** [V2_PHASE7_NOTIFICATIONS.md](./V2_PHASE7_NOTIFICATIONS.md)

## Payload contract

FCM `data` (strings):

```json
{
  "type": "news_article|news_cut|category|publisher|home",
  "articleId": "...",
  "categoryId": "...",
  "publisherId": "...",
  "route": "/news/...",
  "campaignId": "..."
}
```

`type` is required. `route` is a **hint only** — never executed as an arbitrary path.

## Lifecycle

| State | Behavior |
|-------|----------|
| Foreground | SnackBar with Open action — no auto-navigation |
| Background tap | Resolve destination after navigation ready |
| Terminated | Store pending payload → flush once Home seeds navigation |

## Routing (allowlisted)

| type | Destination |
|------|-------------|
| news_article / news_cut | `V2Routes.openArticle` after article resolve |
| category | `V2Routes.openCategory` → CategoriesTab |
| publisher | `V2Routes.openPublisher` (requires publisher pages flag) |
| home | `V2Routes.openHome` |
| unknown | Notification inbox / home |

Missing article → snackbar “No longer available” + home.

## Dedupe

Short-lived key: `type|campaignId|articleId|…` for 60s. Prevents duplicate opens from multiple FCM callbacks.

## Analytics

`notification_open` only on user open/tap, with optional `campaignId`. Never on receipt. Never logs FCM token.

## Preferences

`GET/PATCH /api/notifications/preferences`  
Fields: notificationsEnabled, breakingNewsEnabled, categoryNotificationsEnabled, publisherNotificationsEnabled.

Controller: `NotificationPreferencesController`.

## Token registration

V1 `ProfileService.updateFCMToken` unchanged.  
When `v2_notifications_enabled=true` and user logged in: also `POST /api/notifications/devices` (JWT auth, no userId body, token never logged).

## Feature flag

`v2_notifications_enabled` default **false**.

When false: V2 FCM open handlers are not attached; V1 token registration continues.

## Security

- Allowlisted destinations only  
- No arbitrary URI/route execution  
- No FCM token / JWT logging  
- Failures never block app launch  

## Limitations

- Category open lands on CategoriesTab (does not deep-filter by id yet)  
- Publisher open requires `v2_publisher_pages_enabled`  
- Foreground uses SnackBar (no custom inbox banner system)  
- Background isolate handler does not navigate (opens on resume via pending)  
- APK/iOS builds intentionally skipped for this phase  
