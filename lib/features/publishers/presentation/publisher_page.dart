import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../app/routing/v2_routes.dart';
import '../../../core/analytics/analytics_service.dart';
import '../../../core/utils/localization_helper.dart';
import '../../../data/models/news_article.dart';
import '../../../features/home_v2/presentation/widgets/v2_vintage_paper_background.dart';
import '../../../features/news/domain/news_summary.dart';
import '../../../providers/language_provider.dart';
import '../../../providers/remote_config_provider.dart';
import '../data/publisher_repository.dart';
import 'publisher_controller.dart';
import 'publisher_state.dart';
import 'widgets/publisher_article_list.dart';
import 'widgets/publisher_header.dart';

/// Editorial Publisher page — NewsOn articles attributed to a publisher brand.
class PublisherPage extends StatefulWidget {
  const PublisherPage({
    super.key,
    required this.publisherKey,
    this.seedArticle,
    this.repository,
    this.sourceScreen = 'unknown',
  });

  final String publisherKey;
  final NewsArticle? seedArticle;
  final PublisherRepository? repository;

  /// Screen that opened this page (for analytics).
  final String sourceScreen;

  @override
  State<PublisherPage> createState() => _PublisherPageState();
}

class _PublisherPageState extends State<PublisherPage> {
  late final PublisherController _controller;
  late final LanguageProvider _languageProvider;
  final ScrollController _scrollController = ScrollController();
  bool _viewTracked = false;
  String? _lastLanguage;

  @override
  void initState() {
    super.initState();
    _languageProvider = context.read<LanguageProvider>();
    _lastLanguage = _languageProvider.newsLanguageCode;
    _controller = PublisherController(
      repository: widget.repository ?? PublisherRepository(),
      languageProvider: _languageProvider,
    );
    _scrollController.addListener(_onScroll);
    _languageProvider.addListener(_onLanguageChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPrint(
        '[PublisherPage] publisherId=${widget.publisherKey} '
        'sourceScreen=${widget.sourceScreen}',
      );
      _controller.open(
        publisherKey: widget.publisherKey,
        seedArticle: widget.seedArticle,
      );
    });
  }

  @override
  void dispose() {
    _languageProvider.removeListener(_onLanguageChanged);
    _scrollController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onLanguageChanged() {
    final next = _languageProvider.newsLanguageCode;
    if (next == _lastLanguage) return;
    _lastLanguage = next;
    _viewTracked = false;
    _controller.refresh();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 420) {
      _controller.loadMore();
    }
  }

  void _trackPublisherView(PublisherState state) {
    if (_viewTracked || state.publisher == null) return;
    if (state.status != PublisherLoadStatus.ready &&
        state.status != PublisherLoadStatus.loadingMore) {
      return;
    }
    _viewTracked = true;
    AnalyticsService.instance.publisherView(
      publisherId: state.publisher!.id,
      publisherName: state.publisher!.displayName,
      language: _languageProvider.newsLanguageCode,
      sourceScreen: widget.sourceScreen,
      v2Only: true,
    );
  }

  Future<void> _openArticle(NewsArticle article, int index) async {
    await AnalyticsService.instance.newsOpen(
      newsId: article.analyticsNewsId,
      v2Only: true,
    );
    if (!mounted) return;
    await V2Routes.openArticle(
      context,
      article: article,
      articles: _controller.state.articles,
      initialIndex: index,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Watch remote config so flag changes rebuild chrome if needed.
    context.watch<RemoteConfigProvider>().config;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final state = _controller.state;
        _trackPublisherView(state);

        return Scaffold(
          backgroundColor: V2VintagePaperBackground.stageBaseFor(
            theme.brightness,
          ),
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            title: Text(
              state.publisher?.displayName ??
                  LocalizationHelper.v2Publisher(context),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                fontSize: 17,
                letterSpacing: -0.2,
              ),
            ),
          ),
          body: Stack(
            fit: StackFit.expand,
            children: [
              const V2VintagePaperBackground(intensity: V2PaperIntensity.stage),
              RefreshIndicator(
                color: theme.colorScheme.primary,
                onRefresh: _controller.refresh,
                child: CustomScrollView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: PublisherHeader(
                        publisher: state.publisher,
                        isLoading: state.isLoadingHeader,
                      ),
                    ),
                    if (state.status == PublisherLoadStatus.error &&
                        state.publisher == null)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: _ErrorBody(
                          code: state.errorCode,
                          onBack: () => Navigator.of(context).maybePop(),
                          onRetry: () => _controller.open(
                            publisherKey: widget.publisherKey,
                            seedArticle: widget.seedArticle,
                          ),
                        ),
                      )
                    else ...[
                      if (state.isLoadingList)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.all(40),
                            child: Center(
                              child: CircularProgressIndicator(
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                        )
                      else
                        SliverToBoxAdapter(
                          child: PublisherArticleList(
                            articles: state.articles,
                            isLoadingMore: state.status ==
                                PublisherLoadStatus.loadingMore,
                            onOpen: _openArticle,
                          ),
                        ),
                      if (state.errorCode != null &&
                          state.publisher != null &&
                          state.articles.isEmpty &&
                          !state.isLoadingList)
                        SliverToBoxAdapter(
                          child: _ErrorBody(
                            code: state.errorCode,
                            onBack: () => Navigator.of(context).maybePop(),
                            onRetry: _controller.refresh,
                          ),
                        ),
                      SliverToBoxAdapter(
                        child: SizedBox(height: isDark ? 48 : 40),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({
    this.code,
    this.onRetry,
    this.onBack,
  });

  final String? code;
  final VoidCallback? onRetry;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isNotFound =
        code == 'missing_publisher' || code == 'inactive_publisher';
    final message = isNotFound
        ? LocalizationHelper.v2PublisherUnavailable(context)
        : LocalizationHelper.v2PublisherLoadError(context);

    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isNotFound ? Icons.storefront_outlined : Icons.cloud_off_outlined,
            size: 40,
            color: theme.hintColor,
          ),
          const SizedBox(height: 14),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 15,
              height: 1.4,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 18),
          if (onBack != null)
            TextButton(
              onPressed: onBack,
              child: Text(
                MaterialLocalizations.of(context).backButtonTooltip,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          if (onRetry != null && !isNotFound)
            TextButton(
              onPressed: onRetry,
              child: Text(LocalizationHelper.v2Retry(context)),
            ),
        ],
      ),
    );
  }
}
