import 'package:flutter/material.dart';

import '../../../../app/routing/v2_routes.dart';
import '../../../../core/analytics/analytics_service.dart';
import '../../../../core/utils/localization_helper.dart';
import '../../../../data/models/news_article.dart';
import '../../../news/domain/news_summary.dart';
import 'home_section_header.dart';
import 'latest_news_card.dart';

/// Compact For You strip — hidden when empty / unavailable.
class ForYouSection extends StatefulWidget {
  const ForYouSection({
    super.key,
    required this.articles,
    required this.isBookmarked,
    required this.onBookmark,
    required this.onShare,
    this.onViewAll,
  });

  final List<NewsArticle> articles;
  final bool Function(NewsArticle) isBookmarked;
  final void Function(NewsArticle article) onBookmark;
  final void Function(NewsArticle article) onShare;
  final VoidCallback? onViewAll;

  @override
  State<ForYouSection> createState() => _ForYouSectionState();
}

class _ForYouSectionState extends State<ForYouSection> {
  bool _sectionImpressed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.articles.isEmpty || _sectionImpressed) return;
      _sectionImpressed = true;
      AnalyticsService.instance.forYouImpression();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.articles.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HomeSectionHeader(
          title: LocalizationHelper.forYou(context),
          trailingLabel: LocalizationHelper.v2ViewAll(context),
          onTrailingTap: widget.onViewAll,
        ),
        SizedBox(
          height: 148,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: widget.articles.length.clamp(0, 8),
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final article = widget.articles[index];
              return SizedBox(
                width: 280,
                child: LatestNewsCard(
                  article: article,
                  isBookmarked: widget.isBookmarked(article),
                  onTap: () {
                    AnalyticsService.instance
                        .newsOpen(newsId: article.analyticsNewsId);
                    AnalyticsService.instance
                        .forYouImpression(newsId: article.analyticsNewsId);
                    V2Routes.openArticle(
                      context,
                      article: article,
                      articles: widget.articles,
                      initialIndex: index,
                    );
                  },
                  onBookmark: () => widget.onBookmark(article),
                  onShare: () => widget.onShare(article),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
