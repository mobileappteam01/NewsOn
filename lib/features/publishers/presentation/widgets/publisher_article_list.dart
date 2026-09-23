import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/localization_helper.dart';
import '../../../../core/utils/shared_functions.dart';
import '../../../../data/models/news_article.dart';
import '../../../news/domain/news_summary.dart';

/// Publisher-page article list — image / headline / time / summary.
/// Omits large publisher chrome (user is already on the publisher screen).
class PublisherArticleList extends StatelessWidget {
  const PublisherArticleList({
    super.key,
    required this.articles,
    required this.onOpen,
    this.isLoadingMore = false,
  });

  final List<NewsArticle> articles;
  final void Function(NewsArticle article, int index) onOpen;
  final bool isLoadingMore;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ...List.generate(articles.length, (index) {
          final article = articles[index];
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: _PublisherNewsCard(
              article: article,
              onTap: () => onOpen(article, index),
            ),
          );
        }),
        if (isLoadingMore)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
        if (articles.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            child: Text(
              LocalizationHelper.v2NoPublisherNews(context),
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: Theme.of(context).hintColor,
                fontSize: 14.5,
                height: 1.4,
              ),
            ),
          ),
      ],
    );
  }
}

class _PublisherNewsCard extends StatelessWidget {
  const _PublisherNewsCard({
    required this.article,
    required this.onTap,
  });

  final NewsArticle article;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final image = article.imageUrl;
    final summary = article.v2Summary?.trim();
    final excerpt = (summary != null && summary.isNotEmpty)
        ? summary
        : NewsSummaryResolver.descriptionFallback(article);
    final time = () {
      final dt = DateFormatter.parseApiDate(article.pubDate);
      if (dt == null) return '';
      return DateFormatter.getRelativeTime(dt);
    }();

    return Semantics(
      button: true,
      label: '${article.title}. ${LocalizationHelper.v2OpenArticle(context)}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: image != null && image.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: image,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) =>
                              newsOnImageFallback(),
                        )
                      : newsOnImageFallback(),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                article.title,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                  height: 1.25,
                  letterSpacing: -0.25,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              if (time.isNotEmpty) ...[
                const SizedBox(height: 5),
                Text(
                  time,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: theme.hintColor,
                  ),
                ),
              ],
              if (excerpt != null && excerpt.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  excerpt.trim(),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    height: 1.4,
                    fontWeight: FontWeight.w400,
                    color: theme.colorScheme.onSurface.withValues(
                      alpha: isDark ? 0.78 : 0.72,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
