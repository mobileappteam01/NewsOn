import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/analytics/analytics_service.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/localization_helper.dart';
import '../../../core/utils/shared_functions.dart';
import '../../../data/models/news_article.dart';
import '../../../data/services/interaction_service.dart';
import '../../../data/services/news_share_service.dart';
import '../../../features/home_v2/presentation/v2_news_text_scale.dart';
import '../../../features/home_v2/presentation/widgets/v2_vintage_paper_background.dart';
import '../../../providers/bookmark_provider.dart';
import '../../../providers/language_provider.dart';
import '../../../providers/remote_config_provider.dart';
import '../../../app/routing/v2_routes.dart';
import '../../news/domain/news_summary.dart';
import '../data/v2_article_detail_api.dart';
import '../domain/v2_article_body_resolver.dart';

/// V2 article detail — editorial paper UI, V2 data only.
///
/// Fetches `GET /api/v2/article/{articleId}` and renders [NewsArticle.content]
/// as the full article body. Never uses V1 APIs or [NewsArticle.v2Summary]
/// as the body.
class V2ArticleDetailScreen extends StatefulWidget {
  const V2ArticleDetailScreen({
    super.key,
    required this.articleId,
    this.seedArticle,
    this.detailApi,
  });

  /// V2 ObjectId used for `GET /api/v2/article/{articleId}`.
  final String articleId;

  /// Optional feed/search snapshot for optimistic hero chrome while loading.
  final NewsArticle? seedArticle;

  /// Injectable for tests; production uses [V2ArticleDetailApi].
  final V2ArticleDetailApi? detailApi;

  @override
  State<V2ArticleDetailScreen> createState() => _V2ArticleDetailScreenState();
}

enum _DetailLoadState { loading, ready, error }

class _V2ArticleDetailScreenState extends State<V2ArticleDetailScreen> {
  final InteractionService _interactionService = InteractionService();
  static const double _heroHeight = 220;
  static const double _contentTextSize = 16.5;

  late final V2ArticleDetailApi _api;
  late bool _bookmarked;
  _DetailLoadState _loadState = _DetailLoadState.loading;
  NewsArticle? _article;
  Object? _error;
  var _trackedOpen = false;

  String get _resolvedArticleId {
    final fromArg = widget.articleId.trim();
    if (fromArg.isNotEmpty) return fromArg;
    return widget.seedArticle?.analyticsNewsId.trim() ?? '';
  }

  /// Hero/chrome may use seed; article body only after a successful fetch.
  NewsArticle get _displayArticle {
    final fetched = _article;
    if (fetched != null) return fetched;
    final seed = widget.seedArticle;
    if (seed != null) return seed;
    return NewsArticle(
      articleId: _resolvedArticleId,
      newsId: _resolvedArticleId,
      title: '',
    );
  }

  @override
  void initState() {
    super.initState();
    _api = widget.detailApi ?? V2ArticleDetailApi();
    final seed = widget.seedArticle;
    _bookmarked = seed?.isBookmarked == true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_load());
      _syncBookmarkFromProvider();
    });
  }

  void _syncBookmarkFromProvider() {
    try {
      final value =
          context.read<BookmarkProvider>().isBookmarked(_displayArticle);
      if (mounted && value != _bookmarked) {
        setState(() => _bookmarked = value);
      }
    } catch (_) {
      // Provider/Firebase unavailable (e.g. widget tests) — keep local state.
    }
  }

  Future<void> _load() async {
    final id = _resolvedArticleId;
    if (id.isEmpty) {
      if (!mounted) return;
      setState(() {
        _loadState = _DetailLoadState.error;
        _error = V2ArticleDetailException('missing_article_id');
      });
      return;
    }

    setState(() {
      _loadState = _DetailLoadState.loading;
      _error = null;
    });

    try {
      final fetched = await _api.fetch(id);
      if (!mounted) return;
      setState(() {
        _article = fetched;
        _bookmarked = fetched.isBookmarked == true || _bookmarked;
        _loadState = _DetailLoadState.ready;
        _error = null;
      });
      _syncBookmarkFromProvider();
      if (!_trackedOpen) {
        _trackedOpen = true;
        unawaited(_trackOpen(fetched));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadState = _DetailLoadState.error;
        _error = e;
      });
    }
  }

  Future<void> _trackOpen(NewsArticle article) async {
    try {
      await AnalyticsService.instance.newsOpen(
        newsId: article.analyticsNewsId,
        v2Only: true,
      );
    } catch (_) {}
    try {
      await _interactionService.trackOpen(article);
    } catch (_) {}
  }

  void _pop() {
    Navigator.of(context).maybePop();
  }

  Future<void> _share() async {
    final article = _displayArticle;
    unawaited(_interactionService.trackShare(article));
    await NewsShareService.shareArticle(
      article,
      curiousCta: LocalizationHelper.shareNewsCuriousCta(context),
      v2: true,
    );
    try {
      await AnalyticsService.instance.share(
        newsId: article.analyticsNewsId,
        v2Only: true,
      );
    } catch (_) {}
  }

  Future<void> _toggleBookmark() async {
    final article = _displayArticle;
    try {
      final nowBookmarked =
          await context.read<BookmarkProvider>().toggleBookmarkV2(article);
      try {
        await AnalyticsService.instance.bookmark(
          newsId: article.analyticsNewsId,
          v2Only: true,
        );
      } catch (_) {}
      if (!mounted) return;
      setState(() => _bookmarked = nowBookmarked);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        try {
          _bookmarked =
              context.read<BookmarkProvider>().isBookmarked(article);
        } catch (_) {
          // Keep prior local flag when provider unavailable.
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(LocalizationHelper.error(context, e.toString())),
        ),
      );
    }
  }

  String _relativeTime(NewsArticle article) {
    final dt = DateFormatter.parseApiDate(article.pubDate);
    if (dt == null) return '';
    return DateFormatter.getRelativeTime(dt);
  }

  String _categoryLabel(NewsArticle article) {
    final cats = article.category;
    if (cats == null || cats.isEmpty) return '';
    final first = cats.first.trim();
    if (first.isEmpty) return '';
    if (first.length == 1) return first.toUpperCase();
    return '${first[0].toUpperCase()}${first.substring(1)}';
  }

  String _errorMessage() {
    final err = _error;
    if (err is V2ArticleDetailException && err.code == 'not_found') {
      return 'Article not found';
    }
    return LocalizationHelper.v2ArticleContentUnavailable(context);
  }

  TextStyle _headlineStyle(ThemeData theme, {double size = 28}) {
    return GoogleFonts.playfairDisplay(
      fontSize: size,
      fontWeight: FontWeight.w600,
      height: 1.25,
      letterSpacing: -0.25,
      color: theme.colorScheme.onSurface,
    );
  }

  TextStyle _bodyStyle(ThemeData theme) {
    return GoogleFonts.inriaSerif(
      fontSize: _contentTextSize,
      fontWeight: FontWeight.w500,
      height: 1.7,
      color: theme.colorScheme.onSurface.withValues(alpha: 0.88),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final article = _displayArticle;
    final topInset = MediaQuery.paddingOf(context).top;
    final paper = V2VintagePaperBackground.stageBaseFor(theme.brightness);
    final bodyStyle = _bodyStyle(theme);

    // Keep RemoteConfigProvider watched so theme logo / flags stay live.
    context.watch<RemoteConfigProvider>().config;

    return Scaffold(
      backgroundColor: paper,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const V2VintagePaperBackground(intensity: V2PaperIntensity.stage),
          Column(
            children: [
              SizedBox(height: topInset + 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: _buildHero(theme, article),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: V2NewsTextScope(
                  child: _buildSheetBody(theme, bodyStyle, article),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHero(ThemeData theme, NewsArticle article) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: _heroHeight,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildHeroImage(article),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.0, 0.22, 0.55, 1.0],
                  colors: [
                    Color(0x99000000),
                    Colors.transparent,
                    Colors.transparent,
                    Color(0xCC000000),
                  ],
                ),
              ),
            ),
            // Top chrome: back ····· [bookmark][share]
            Positioned(
              top: 10,
              left: 10,
              right: 10,
              child: Row(
                children: [
                  _HeroActionButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    tooltip: 'Back',
                    onTap: _pop,
                  ),
                  const Spacer(),
                  _HeroActionButton(
                    icon: _bookmarked
                        ? Icons.bookmark
                        : Icons.bookmark_border,
                    tooltip: LocalizationHelper.v2Bookmark(context),
                    accent: _bookmarked,
                    onTap: () => unawaited(_toggleBookmark()),
                  ),
                  const SizedBox(width: 8),
                  _HeroActionButton(
                    icon: Icons.share_rounded,
                    tooltip: LocalizationHelper.v2Share(context),
                    onTap: () => unawaited(_share()),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 14,
              right: 14,
              bottom: 12,
              child: _buildHeroMetadata(article),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroMetadata(NewsArticle article) {
    final publisher = article.publisherDisplayName.trim();
    final ago = _relativeTime(article);
    final category = _categoryLabel(article);
    final canOpen = V2Routes.canOpenPublisher(context, article);

    final style = GoogleFonts.inter(
      color: Colors.white.withValues(alpha: 0.88),
      fontSize: 12,
      fontWeight: FontWeight.w500,
      height: 1.3,
    );

    if (publisher.isEmpty && ago.isEmpty && category.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 0,
      children: [
        if (publisher.isNotEmpty)
          canOpen
              ? Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      debugPrint(
                        '[PublisherTap] screen=detail enabled=true '
                        'publisherId=${article.publisherId} '
                        'publisherName=$publisher',
                      );
                      V2Routes.openPublisherFromArticle(
                        context,
                        article,
                        sourceScreen: 'article_detail',
                        language:
                            context.read<LanguageProvider>().newsLanguageCode,
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        publisher,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: style.copyWith(
                          fontWeight: FontWeight.w700,
                          decoration: TextDecoration.underline,
                          decorationColor:
                              Colors.white.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ),
                )
              : Text(publisher, style: style),
        if (publisher.isNotEmpty && (ago.isNotEmpty || category.isNotEmpty))
          Text('  ·  ', style: style),
        if (ago.isNotEmpty) Text(ago, style: style),
        if (ago.isNotEmpty && category.isNotEmpty) Text('  ·  ', style: style),
        if (category.isNotEmpty) Text(category, style: style),
      ],
    );
  }

  Widget _buildSheetBody(
    ThemeData theme,
    TextStyle bodyStyle,
    NewsArticle article,
  ) {
    if (_loadState == _DetailLoadState.loading) {
      return Column(
        children: [
          if (article.title.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 4, 22, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  article.title,
                  style: _headlineStyle(theme, size: 27),
                ),
              ),
            ),
          const Expanded(
            child: Center(child: CircularProgressIndicator()),
          ),
        ],
      );
    }

    if (_loadState == _DetailLoadState.error || _article == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _errorMessage(),
                textAlign: TextAlign.center,
                style: bodyStyle.copyWith(
                  fontStyle: FontStyle.italic,
                  color: theme.hintColor,
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => unawaited(_load()),
                child: Text(LocalizationHelper.v2ArticleContentRetry(context)),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(22, 4, 22, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (article.title.isNotEmpty)
            Text(
              article.title,
              style: _headlineStyle(theme),
            ),
          const SizedBox(height: 18),
          _buildArticleBody(theme, bodyStyle, article),
          SizedBox(height: MediaQuery.paddingOf(context).bottom + 12),
        ],
      ),
    );
  }

  Widget _buildArticleBody(
    ThemeData theme,
    TextStyle bodyStyle,
    NewsArticle article,
  ) {
    final raw = V2ArticleBodyResolver.rawBody(article);
    if (raw == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            LocalizationHelper.v2ArticleContentUnavailable(context),
            style: bodyStyle.copyWith(
              fontStyle: FontStyle.italic,
              color: theme.hintColor,
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => unawaited(_load()),
            child: Text(LocalizationHelper.v2ArticleContentRetry(context)),
          ),
        ],
      );
    }

    if (V2ArticleBodyResolver.looksLikeHtml(raw)) {
      return Html(
        data: raw,
        style: {
          'body': Style(
            margin: Margins.zero,
            padding: HtmlPaddings.zero,
            fontSize: FontSize(_contentTextSize),
            fontWeight: FontWeight.w500,
            lineHeight: const LineHeight(1.7),
            color: bodyStyle.color,
            fontFamily: bodyStyle.fontFamily,
          ),
          'p': Style(
            margin: Margins.only(bottom: 16),
          ),
          'a': Style(
            color: theme.colorScheme.primary,
            textDecoration: TextDecoration.none,
          ),
        },
      );
    }

    final paragraphs = V2ArticleBodyResolver.paragraphs(raw);
    if (paragraphs.length == 1) {
      return Text(paragraphs.first, style: bodyStyle);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < paragraphs.length; i++) ...[
          if (i > 0) const SizedBox(height: 16),
          Text(paragraphs[i], style: bodyStyle),
        ],
      ],
    );
  }

  Widget _buildHeroImage(NewsArticle article) {
    final url = (article.imageUrl ?? article.sourceIcon)?.trim() ?? '';
    if (url.isEmpty) {
      return newsOnImageFallback(
        width: double.infinity,
        height: _heroHeight,
      );
    }
    return CachedNetworkImage(
      imageUrl: url,
      height: _heroHeight,
      width: double.infinity,
      fit: BoxFit.cover,
      errorWidget: (context, url, error) => newsOnImageFallback(
        width: double.infinity,
        height: _heroHeight,
      ),
    );
  }
}

/// Circular translucent hero action — 46px visual, ≥44px touch.
class _HeroActionButton extends StatelessWidget {
  const _HeroActionButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.accent = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  final bool accent;

  static const double _size = 46;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = accent ? theme.colorScheme.primary : Colors.white;

    return Semantics(
      button: true,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: Ink(
              width: _size,
              height: _size,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.42),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(icon, color: color, size: 20),
            ),
          ),
        ),
      ),
    );
  }
}
