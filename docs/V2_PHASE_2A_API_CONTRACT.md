# V2 Phase 2A — Backend API Contract Requests

Mobile Phase 2A is flag-gated and backward compatible. The following backend
capabilities improve the product but have client fallbacks where noted.

## 1. Article summary fields (feed + detail)

Preferred JSON fields on news documents / list items:

| Field | Type | Notes |
|-------|------|-------|
| `v2_summary` | string | ~60-word NewsOn Cut |
| `summary_status` | string | `available` \| `pending` \| `unavailable` \| `failed` |
| `ai_summary` | string | Legacy fallback if `v2_summary` missing |
| `source_name` | string | Publisher display |
| `source_icon` | string | Optional icon URL |
| `source_url` / `link` | string | Canonical publisher URL for Full Article |

Aliases accepted by mobile: `v2Summary`, `newson_cut`, `summaryStatus`.

## 2. Related news endpoint (optional)

Firestore `apiEndPoints` module/key:

- module: `news`
- key: `relatedNews`

Suggested query:

- `newsId`
- `limit`
- `language`

Response: list under `data` or `results` of article objects.

**Fallback if missing:** same publisher / same category from today news (explicitly not AI personalization).

## 3. Analytics track endpoint (optional)

- module: `analytics`
- key: `trackEvent`

Body:

```json
{
  "event": "summary_view",
  "sessionId": "sess_…",
  "timestamp": "ISO-8601",
  "platform": "iOS|Android",
  "params": { "newsId": "…" }
}
```

Auth: optional Bearer JWT. **Do not require client `userId`** — derive from JWT.

If endpoint missing, mobile soft-fails and never blocks UI.

## 4. Remote Config flags

| Key | Default | Purpose |
|-----|---------|---------|
| `v2_news_cuts_enabled` | false | V2 home Cuts feed |
| `v2_new_article_detail_enabled` | false | V2 article detail |
| `v2_full_article_enabled` | false | Full article WebView CTA |
| `v2_related_news_enabled` | false | Related section |
| `v2_page_turn_enabled` | false | Page-turn between feed articles |
| `v2_news_cuts_label` | `NewsOn Cuts` | Product label |
