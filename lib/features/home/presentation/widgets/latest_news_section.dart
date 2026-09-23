import 'package:flutter/material.dart';

import '../../../../core/utils/localization_helper.dart';
import '../../../../data/models/news_article.dart';
import 'home_section_header.dart';
import 'latest_news_card.dart';

class LatestNewsSection extends StatelessWidget {
  const LatestNewsSection({
    super.key,
    required this.articles,
    required this.isBookmarked,
    required this.onOpen,
    required this.onBookmark,
    required this.onShare,
    this.title,
    this.error,
    this.onRetry,
    this.isLoading = false,
    this.isLoadingMore = false,
  });

  final List<NewsArticle> articles;
  final bool Function(NewsArticle) isBookmarked;
  final void Function(NewsArticle article, int index) onOpen;
  final void Function(NewsArticle article) onBookmark;
  final void Function(NewsArticle article) onShare;
  final String? title;
  final String? error;
  final VoidCallback? onRetry;
  final bool isLoading;
  final bool isLoadingMore;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HomeSectionHeader(
          title: title ?? LocalizationHelper.v2Latest(context),
        ),
        if (isLoading && articles.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (error != null && articles.isEmpty)
          HomeSectionError(message: error!, onRetry: onRetry)
        else if (articles.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(LocalizationHelper.v2NoNews(context)),
          )
        else ...[
          ...List.generate(articles.length, (index) {
            final article = articles[index];
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: LatestNewsCard(
                article: article,
                isBookmarked: isBookmarked(article),
                onTap: () => onOpen(article, index),
                onBookmark: () => onBookmark(article),
                onShare: () => onShare(article),
              ),
            );
          }),
          if (isLoadingMore)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ],
    );
  }
}
