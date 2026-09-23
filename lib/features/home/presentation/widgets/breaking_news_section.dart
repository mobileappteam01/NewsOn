import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../app/routing/v2_routes.dart';
import '../../../../core/analytics/analytics_service.dart';
import '../../../../core/utils/localization_helper.dart';
import '../../../../core/utils/shared_functions.dart';
import '../../../../data/models/news_article.dart';
import '../../../news/domain/news_summary.dart';
import '../../../publishers/presentation/widgets/publisher_attribution.dart';
import 'home_section_header.dart';

/// Horizontal breaking news pager with gentle optional auto-advance.
class BreakingNewsSection extends StatefulWidget {
  const BreakingNewsSection({
    super.key,
    required this.articles,
    this.error,
    this.onRetry,
    this.autoScroll = true,
  });

  final List<NewsArticle> articles;
  final String? error;
  final VoidCallback? onRetry;
  final bool autoScroll;

  @override
  State<BreakingNewsSection> createState() => _BreakingNewsSectionState();
}

class _BreakingNewsSectionState extends State<BreakingNewsSection> {
  final PageController _controller = PageController(viewportFraction: 0.88);
  final Set<String> _impressed = {};
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _maybeStartAutoScroll();
  }

  @override
  void didUpdateWidget(covariant BreakingNewsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.articles.length != widget.articles.length) {
      _timer?.cancel();
      _maybeStartAutoScroll();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _maybeStartAutoScroll() {
    if (!widget.autoScroll || widget.articles.length < 2) return;
    _timer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!mounted || !_controller.hasClients) return;
      final next = (_index + 1) % widget.articles.length;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _trackImpression(NewsArticle article) {
    final id = article.analyticsNewsId;
    if (_impressed.contains(id)) return;
    _impressed.add(id);
    AnalyticsService.instance.newsImpression(
      newsId: id,
      publisher: article.publisherDisplayName,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.articles.isEmpty && widget.error == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HomeSectionHeader(
          title: LocalizationHelper.v2BreakingNews(context),
        ),
        if (widget.error != null && widget.articles.isEmpty)
          HomeSectionError(message: widget.error!, onRetry: widget.onRetry)
        else
          SizedBox(
            height: 168,
            child: PageView.builder(
              controller: _controller,
              itemCount: widget.articles.length,
              onPageChanged: (i) {
                _index = i;
                _trackImpression(widget.articles[i]);
              },
              itemBuilder: (context, i) {
                final article = widget.articles[i];
                if (i == 0) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) _trackImpression(article);
                  });
                }
                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: _BreakingCard(
                    article: article,
                    onTap: () {
                      AnalyticsService.instance
                          .newsOpen(newsId: article.analyticsNewsId);
                      V2Routes.openArticle(
                        context,
                        article: article,
                        articles: widget.articles,
                        initialIndex: i,
                      );
                    },
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _BreakingCard extends StatelessWidget {
  const _BreakingCard({required this.article, required this.onTap});

  final NewsArticle article;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final image = article.imageUrl;
    return Semantics(
      button: true,
      label:
          '${LocalizationHelper.v2BreakingNews(context)}. ${article.title}. ${article.publisherDisplayName}',
      child: Material(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Row(
            children: [
              SizedBox(
                width: 110,
                height: double.infinity,
                child: image != null && image.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: image,
                        fit: BoxFit.cover,
                        placeholder: (_, __) =>
                            Container(color: theme.dividerColor),
                        errorWidget: (_, __, ___) => newsOnImageFallback(),
                      )
                    : newsOnImageFallback(),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
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
                      const SizedBox(height: 6),
                      Expanded(
                        child: Text(
                          article.title,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            height: 1.25,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
