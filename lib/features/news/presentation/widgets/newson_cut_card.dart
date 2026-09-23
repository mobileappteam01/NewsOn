import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/analytics/analytics_service.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/localization_helper.dart';
import '../../../../data/models/news_article.dart';
import '../../../audio/presentation/widgets/audio_button.dart';
import '../../../publishers/presentation/widgets/publisher_attribution.dart';
import '../../domain/news_summary.dart';

/// Feed card optimized for fast understanding (NewsOn Cuts).
class NewsOnCutCard extends StatefulWidget {
  const NewsOnCutCard({
    super.key,
    required this.article,
    required this.cutsLabel,
    this.onTap,
    this.onBookmark,
    this.onShare,
    this.isBookmarked = false,
  });

  final NewsArticle article;
  final String cutsLabel;
  final VoidCallback? onTap;
  final VoidCallback? onBookmark;
  final VoidCallback? onShare;
  final bool isBookmarked;

  @override
  State<NewsOnCutCard> createState() => _NewsOnCutCardState();
}

class _NewsOnCutCardState extends State<NewsOnCutCard> {
  bool _impressed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _trackImpression());
  }

  void _trackImpression() {
    if (_impressed || !mounted) return;
    _impressed = true;
    final category =
        (widget.article.category != null && widget.article.category!.isNotEmpty)
            ? widget.article.category!.first
            : null;
    AnalyticsService.instance.newsImpression(
      newsId: widget.article.analyticsNewsId,
      category: category,
      publisher: widget.article.publisherDisplayName,
    );
  }

  String _relativeTime(String? pubDate) {
    final dt = DateFormatter.parseApiDate(pubDate);
    if (dt == null) return '';
    return DateFormatter.getRelativeTime(dt);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final article = widget.article;
    final status = article.resolvedSummaryStatus;
    final cut = article.newsOnCutText;
    final category = (article.category != null && article.category!.isNotEmpty)
        ? article.category!.first
        : null;

    return Semantics(
      button: true,
      label:
          '${article.publisherDisplayName}. ${article.title}. ${LocalizationHelper.v2OpenArticle(context)}',
      child: Material(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _PublisherAvatar(article: article),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          PublisherAttribution(
                            article: article,
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            _relativeTime(article.pubDate),
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: theme.hintColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (category != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: theme.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          category,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: theme.primaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                if (article.imageUrl != null &&
                    article.imageUrl!.isNotEmpty) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: CachedNetworkImage(
                        imageUrl: article.imageUrl!,
                        fit: BoxFit.cover,
                        memCacheWidth: 800,
                        errorWidget: (_, __, ___) => Container(
                          color: Colors.grey.shade200,
                          alignment: Alignment.center,
                          child: const Icon(Icons.image_not_supported),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                Text(
                  article.title,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  widget.cutsLabel,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: theme.primaryColor,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 4),
                _SummaryBody(status: status, cut: cut),
                const SizedBox(height: 8),
                Row(
                  children: [
                    V2AudioButton(article: article, compact: true),
                    if (widget.onBookmark != null)
                      IconButton(
                        tooltip: LocalizationHelper.v2Bookmark(context),
                        onPressed: widget.onBookmark,
                        icon: Icon(
                          widget.isBookmarked
                              ? Icons.bookmark
                              : Icons.bookmark_border,
                          color: theme.primaryColor,
                        ),
                      ),
                    if (widget.onShare != null)
                      IconButton(
                        tooltip: LocalizationHelper.v2Share(context),
                        onPressed: widget.onShare,
                        icon: const Icon(Icons.share_outlined),
                      ),
                    const Spacer(),
                    Text(
                      LocalizationHelper.v2OpenArticle(context),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: theme.primaryColor,
                      ),
                    ),
                    Icon(Icons.chevron_right, color: theme.primaryColor),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryBody extends StatelessWidget {
  const _SummaryBody({required this.status, required this.cut});

  final NewsSummaryStatus status;
  final String? cut;

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case NewsSummaryStatus.available:
        return Text(
          cut ?? '',
          style: GoogleFonts.inter(fontSize: 14, height: 1.45),
          maxLines: 5,
          overflow: TextOverflow.ellipsis,
        );
      case NewsSummaryStatus.pending:
        return Text(
          LocalizationHelper.v2SummaryComingSoon(context),
          style: GoogleFonts.inter(
            fontSize: 13,
            fontStyle: FontStyle.italic,
            color: Theme.of(context).hintColor,
          ),
        );
      case NewsSummaryStatus.failed:
      case NewsSummaryStatus.unavailable:
        return Text(
          LocalizationHelper.v2SummaryUnavailable(context),
          style: GoogleFonts.inter(
            fontSize: 13,
            color: Theme.of(context).hintColor,
          ),
        );
    }
  }
}

class _PublisherAvatar extends StatelessWidget {
  const _PublisherAvatar({required this.article});
  final NewsArticle article;

  @override
  Widget build(BuildContext context) {
    final icon = article.sourceIcon;
    if (icon != null && icon.isNotEmpty) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: icon,
          width: 28,
          height: 28,
          fit: BoxFit.cover,
          errorWidget: (_, __, ___) => _fallback(context),
        ),
      );
    }
    return _fallback(context);
  }

  Widget _fallback(BuildContext context) {
    final letter = article.publisherDisplayName.isNotEmpty
        ? article.publisherDisplayName[0].toUpperCase()
        : 'N';
    return CircleAvatar(
      radius: 14,
      backgroundColor: Theme.of(context).primaryColor.withOpacity(0.15),
      child: Text(
        letter,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).primaryColor,
        ),
      ),
    );
  }
}
