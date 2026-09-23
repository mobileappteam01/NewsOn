import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/localization_helper.dart';
import '../../../../core/utils/shared_functions.dart';
import '../../../../data/models/news_article.dart';
import '../../../news/domain/news_summary.dart';
import '../../../publishers/presentation/widgets/publisher_attribution.dart';

class LatestNewsCard extends StatelessWidget {
  const LatestNewsCard({
    super.key,
    required this.article,
    this.isBookmarked = false,
    this.onTap,
    this.onBookmark,
    this.onShare,
  });

  final NewsArticle article;
  final bool isBookmarked;
  final VoidCallback? onTap;
  final VoidCallback? onBookmark;
  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final image = article.imageUrl;
    final excerpt = NewsSummaryResolver.descriptionFallback(article);
    final time = () {
      final dt = DateFormatter.parseApiDate(article.pubDate);
      if (dt == null) return '';
      return DateFormatter.getRelativeTime(dt);
    }();

    return Semantics(
      button: true,
      label:
          '${article.publisherDisplayName}. ${article.title}. ${LocalizationHelper.v2OpenArticle(context)}',
      child: Material(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 88,
                    height: 88,
                    child: image != null && image.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: image,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => newsOnImageFallback(),
                          )
                        : newsOnImageFallback(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PublisherAttribution(
                        article: article,
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        article.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                        ),
                      ),
                      if (excerpt != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          excerpt,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.hintColor,
                            height: 1.3,
                          ),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          if (time.isNotEmpty)
                            Text(
                              time,
                              style: TextStyle(
                                fontSize: 11,
                                color: theme.hintColor,
                              ),
                            ),
                          const Spacer(),
                          Semantics(
                            button: true,
                            label: LocalizationHelper.v2Bookmark(context),
                            child: IconButton(
                              visualDensity: VisualDensity.compact,
                              iconSize: 20,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 32,
                                minHeight: 32,
                              ),
                              icon: Icon(
                                isBookmarked
                                    ? Icons.bookmark
                                    : Icons.bookmark_border,
                              ),
                              onPressed: onBookmark,
                            ),
                          ),
                          Semantics(
                            button: true,
                            label: LocalizationHelper.v2Share(context),
                            child: IconButton(
                              visualDensity: VisualDensity.compact,
                              iconSize: 20,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 32,
                                minHeight: 32,
                              ),
                              icon: const Icon(Icons.share_outlined),
                              onPressed: onShare,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
