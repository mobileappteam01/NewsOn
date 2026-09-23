import 'package:flutter/material.dart';

import '../../../../core/config/v2_feature_flags.dart';
import '../../../../data/models/news_article.dart';
import '../../../../data/models/remote_config_model.dart';
import '../../../news/presentation/widgets/newson_cut_card.dart';
import 'home_section_header.dart';

/// Re-export / thin home wrapper around the shared NewsOn Cut card.
class NewsCutCard extends StatelessWidget {
  const NewsCutCard({
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
  Widget build(BuildContext context) {
    return NewsOnCutCard(
      article: article,
      cutsLabel: cutsLabel,
      onTap: onTap,
      onBookmark: onBookmark,
      onShare: onShare,
      isBookmarked: isBookmarked,
    );
  }
}

class NewsCutsSection extends StatelessWidget {
  const NewsCutsSection({
    super.key,
    required this.articles,
    required this.config,
    required this.isBookmarked,
    required this.onOpen,
    required this.onBookmark,
    required this.onShare,
    this.error,
    this.onRetry,
    this.isLoading = false,
  });

  final List<NewsArticle> articles;
  final RemoteConfigModel config;
  final bool Function(NewsArticle) isBookmarked;
  final void Function(NewsArticle article, int index) onOpen;
  final void Function(NewsArticle article) onBookmark;
  final void Function(NewsArticle article) onShare;
  final String? error;
  final VoidCallback? onRetry;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final label = V2FeatureFlags.cutsLabel(config);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HomeSectionHeader(title: label),
        if (isLoading && articles.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (error != null && articles.isEmpty)
          HomeSectionError(message: error!, onRetry: onRetry)
        else
          ...List.generate(articles.length, (index) {
            final article = articles[index];
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: NewsCutCard(
                article: article,
                cutsLabel: label,
                isBookmarked: isBookmarked(article),
                onTap: () => onOpen(article, index),
                onBookmark: () => onBookmark(article),
                onShare: () => onShare(article),
              ),
            );
          }),
      ],
    );
  }
}
