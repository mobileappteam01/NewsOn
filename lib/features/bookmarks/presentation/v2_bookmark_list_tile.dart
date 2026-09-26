import 'package:flutter/material.dart';

import '../../../core/utils/date_formatter.dart';
import '../../../data/models/news_article.dart';

/// V2 bookmark row. Does not use [NewsGridView].
///
/// `GET /api/v2/bookmarks` items have no category list. This row treats
/// category, image, and time as optional and does not read remote config.
class V2BookmarkListTile extends StatelessWidget {
  const V2BookmarkListTile({
    super.key,
    required this.article,
    required this.bookmarked,
    required this.onOpen,
    required this.onBookmark,
    required this.onShare,
  });

  final NewsArticle article;
  final bool bookmarked;
  final VoidCallback onOpen;
  final VoidCallback onBookmark;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final category = _firstCategory(article);
    final time = _timeLabel(article);

    return InkWell(
      onTap: onOpen,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Thumb(url: article.imageUrl),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (category != null)
                    Text(
                      category,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  Text(
                    article.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (time != null)
                    Text(
                      time,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            IconButton(
              onPressed: onBookmark,
              icon: Icon(
                bookmarked ? Icons.bookmark : Icons.bookmark_border,
              ),
            ),
            IconButton(
              onPressed: onShare,
              icon: const Icon(Icons.ios_share_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

String? _firstCategory(NewsArticle article) {
  final categories = article.category;
  if (categories == null || categories.isEmpty) return null;
  final first = categories.first.trim();
  if (first.isEmpty) return null;
  return first;
}

String? _timeLabel(NewsArticle article) {
  final raw = article.pubDate;
  if (raw == null || raw.trim().isEmpty) return null;
  final parsed = DateFormatter.parseApiDate(raw);
  if (parsed == null) return null;
  return DateFormatter.getRelativeTime(parsed);
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final resolved = url?.trim();
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 96,
        height: 72,
        child: resolved == null || resolved.isEmpty
            ? ColoredBox(
                color: theme.colorScheme.surfaceContainerHighest,
                child: Icon(
                  Icons.image_outlined,
                  color: theme.colorScheme.outline,
                ),
              )
            : Image.network(
                resolved,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => ColoredBox(
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: theme.colorScheme.outline,
                  ),
                ),
              ),
      ),
    );
  }
}
