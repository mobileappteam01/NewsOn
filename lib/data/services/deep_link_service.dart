import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/constants/deep_link_constants.dart';
import '../../core/navigation/app_navigator.dart';
import '../../core/utils/connectivity_helper.dart';
import '../../screens/auth/auth_screen.dart';
import '../../screens/home/home_screen.dart';
import '../../screens/news_detail/news_detail_screen.dart';
import '../models/news_article.dart';
import 'news_article_resolver.dart';
import 'user_service.dart';

/// Handles share / deep links (Instagram-style).
///
/// - App installed + logged in → [NewsDetailScreen] for the shared article.
/// - App installed + not logged in → [AuthScreen], then article after login.
/// - Play Store is only in share text for users without the app (not handled here).
class DeepLinkService {
  DeepLinkService._();
  static final DeepLinkService instance = DeepLinkService._();

  final AppLinks _appLinks = AppLinks();
  final UserService _userService = UserService();

  StreamSubscription<Uri>? _linkSubscription;
  String? _pendingArticleId;
  bool _initialized = false;
  bool _userOpenedShareLink = false;
  bool _showedNotFoundSnackBar = false;
  bool _isResolving = false;
  bool _routedToLogin = false;
  bool _fromColdStart = false;

  /// True when a share link is waiting to be opened.
  bool get hasPendingArticle =>
      _pendingArticleId != null && _pendingArticleId!.isNotEmpty;

  String? get pendingArticleId => _pendingArticleId;

  bool get openedFromShareLink => _userOpenedShareLink;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) {
        debugPrint('🔗 Initial deep link: $initial');
        _enqueueFromUri(initial, coldStart: true);
      }

      _linkSubscription = _appLinks.uriLinkStream.listen(
        (uri) {
          debugPrint('🔗 Deep link stream: $uri');
          _enqueueFromUri(uri);
          unawaited(_tryOpenPending());
        },
        onError: (e) => debugPrint('❌ Deep link stream error: $e'),
      );
    } catch (e) {
      debugPrint('❌ DeepLinkService init failed: $e');
    }
  }

  void dispose() {
    _linkSubscription?.cancel();
    _linkSubscription = null;
    _initialized = false;
  }

  void _enqueueFromUri(Uri uri, {bool coldStart = false}) {
    if (!DeepLinkConstants.isNewsDeepLink(uri)) return;
    final articleId = DeepLinkConstants.parseArticleId(uri);
    if (articleId == null || articleId.isEmpty) return;

    _pendingArticleId = articleId;
    _userOpenedShareLink = true;
    _showedNotFoundSnackBar = false;
    _routedToLogin = false;
    if (coldStart) _fromColdStart = true;

    debugPrint('🔗 Pending article id: $articleId (coldStart: $coldStart)');
    _schedulePendingLinkAttempts();
  }

  /// Call after [MaterialApp] is mounted, home loads, or login completes.
  void processPendingLink() {
    _schedulePendingLinkAttempts();
  }

  void _schedulePendingLinkAttempts() {
    if (_pendingArticleId == null) return;
    const delaysMs = [0, 200, 500, 1000, 2000, 3500];
    for (final delay in delaysMs) {
      Future<void>.delayed(Duration(milliseconds: delay), () {
        if (_pendingArticleId == null || _isResolving) return;
        unawaited(_tryOpenPending());
      });
    }
  }

  Future<void> _tryOpenPending() async {
    if (_isResolving) return;

    final articleId = _pendingArticleId;
    if (articleId == null) return;

    final context = appNavigatorKey.currentContext;
    if (context == null) return;

    _isResolving = true;
    try {
      // Instagram-style: must be logged in before opening the article.
      if (!_userService.isLoggedIn) {
        debugPrint('🔗 Not logged in — routing to AuthScreen');
        _navigateToLogin();
        return;
      }

      final navigator = appNavigatorKey.currentState;
      if (navigator == null) return;

      // Cold start from share link: land on home first, then open article.
      if (_fromColdStart) {
        _fromColdStart = false;
        await _navigateToHome(navigator);
      }

      if (!context.mounted) return;

      var article = NewsArticleResolver.findById(articleId);

      if (article == null) {
        final online = await ConnectivityHelper.hasConnection();
        if (!online) {
          debugPrint('🔗 Article $articleId not cached and offline');
          if (_userOpenedShareLink && !_showedNotFoundSnackBar) {
            _showNotFoundMessage(context, offline: true);
            _showedNotFoundSnackBar = true;
          }
          return;
        }

        article = await _resolveWithLoading(context, articleId);
      }

      if (article == null) {
        debugPrint('🔗 Article $articleId could not be loaded');
        if (_userOpenedShareLink && !_showedNotFoundSnackBar) {
          _showNotFoundMessage(context);
          _showedNotFoundSnackBar = true;
        }
        return;
      }

      if (!context.mounted) return;

      _clearPending();
      _openDetail(navigator, article);
    } finally {
      _isResolving = false;
    }
  }

  void _clearPending() {
    _pendingArticleId = null;
    _userOpenedShareLink = false;
    _showedNotFoundSnackBar = false;
    _routedToLogin = false;
    _fromColdStart = false;
  }

  void _navigateToLogin() {
    if (_routedToLogin) return;
    final navigator = appNavigatorKey.currentState;
    if (navigator == null) return;

    _routedToLogin = true;
    debugPrint('🔗 Navigating to login for shared article');
    navigator.pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const AuthScreen()),
      (route) => false,
    );
  }

  Future<void> _navigateToHome(NavigatorState navigator) async {
    debugPrint('🔗 Navigating to home before opening shared article');
    navigator.pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => const HomeScreen(selectedCategories: []),
      ),
      (route) => false,
    );
    // Allow HomeScreen init (API, providers) to start.
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }

  Future<NewsArticle?> _resolveWithLoading(
    BuildContext context,
    String articleId,
  ) async {
    final navigator = appNavigatorKey.currentState;
    if (navigator == null) {
      return NewsArticleResolver.resolveById(articleId);
    }

    return navigator.push<NewsArticle?>(
      MaterialPageRoute<NewsArticle?>(
        fullscreenDialog: true,
        builder: (_) => _SharedArticleLoadingRoute(articleId: articleId),
      ),
    );
  }

  void _openDetail(NavigatorState navigator, NewsArticle article) {
    debugPrint('🔗 Opening NewsDetailScreen for ${article.articleId}');
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => NewsDetailScreen(article: article),
      ),
    );
  }

  /// For testing / manual open from in-app debug.
  void openArticleById(String articleId) {
    _pendingArticleId = articleId;
    _userOpenedShareLink = true;
    unawaited(_tryOpenPending());
  }

  void _showNotFoundMessage(
    BuildContext context, {
    bool offline = false,
  }) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          offline
              ? 'This article is not saved on your device. Connect to the internet and open the link again.'
              : 'Could not load this article. Check your connection and try again.',
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }
}

/// Brief loading screen while fetching a shared article from the API.
class _SharedArticleLoadingRoute extends StatefulWidget {
  const _SharedArticleLoadingRoute({required this.articleId});

  final String articleId;

  @override
  State<_SharedArticleLoadingRoute> createState() =>
      _SharedArticleLoadingRouteState();
}

class _SharedArticleLoadingRouteState extends State<_SharedArticleLoadingRoute> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final article = await NewsArticleResolver.resolveById(widget.articleId);
    if (!mounted) return;
    Navigator.of(context).pop(article);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Opening article'),
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading article…'),
          ],
        ),
      ),
    );
  }
}
