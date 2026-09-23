import 'package:flutter/material.dart';

import '../../../../data/models/news_article.dart';
import '../../../news/domain/news_summary.dart';

/// Plain editorial summary — no card, no "NewsOn Cut" label.
class V2SummarySection extends StatelessWidget {
  const V2SummarySection({
    super.key,
    required this.article,
    required this.cutsLabel,
  });

  final NewsArticle article;

  /// Kept for API compatibility with existing call sites.
  final String cutsLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = article.resolvedSummaryStatus;
    final cut = article.newsOnCutText;

    if (status == NewsSummaryStatus.available && cut != null) {
      return Text(
        cut,
        style: theme.textTheme.bodyMedium?.copyWith(
          height: 1.42,
          fontSize: 14,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.92),
          fontWeight: FontWeight.w400,
        ),
      );
    }

    String message;
    switch (status) {
      case NewsSummaryStatus.pending:
        message = 'NewsOn Cut is being prepared…';
        break;
      case NewsSummaryStatus.failed:
        message = 'NewsOn Cut is temporarily unavailable.';
        break;
      default:
        message = 'NewsOn Cut is not available for this article.';
    }

    return Text(
      message,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        height: 1.35,
      ),
    );
  }
}
