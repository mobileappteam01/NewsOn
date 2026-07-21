import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/bootstrap/app_bootstrap.dart';
import '../../core/constants/deep_link_constants.dart';
import '../../core/navigation/app_navigator.dart';
import '../../core/utils/connectivity_helper.dart';
import '../../screens/auth/auth_screen.dart';
import '../../screens/news_detail/news_detail_screen.dart';
import '../models/news_article.dart';
import 'api_service.dart';
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
  bool _homeSeeded = false;
  int _attemptCount = 0;

  static const int _maxAttempts = 8;

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
    _homeSeeded = false;
    _attemptCount = 0;
    if (coldStart) _fromColdStart = true;

    debugPrint('🔗 Pending article id: $articleId (coldStart: $coldStart)');
    _schedulePendingLinkAttempts();
  }

  /// Call after [MaterialApp] is mounted, home loads, or login completes.
  ///
  /// Set [navigationReady] when Splash/Auth/Home has finished its first route
  /// so cold-start share links don't open detail on top of the splash screen.
  void processPendingLink({bool navigationReady = false}) {
    if (navigationReady) {
      _homeSeeded = true;
    }
    _schedulePendingLinkAttempts();
  }

  void _schedulePendingLinkAttempts() {
    if (_pendingArticleId == null) return;
    // Longer cold-start window — API / Firebase may still be warming up.
    const delaysMs = [0, 300, 800, 1500, 2500, 4000, 6000, 9000];
    for (final delay in delaysMs) {
      Future<void>.delayed(Duration(milliseconds: delay), () {
        if (_pendingArticleId == null || _isResolving) return;
        unawaited(_tryOpenPending());
      });
    }
  }

  Future<bool> _ensureApiReady() async {
    final api = ApiService();
    if (api.isInitialized) return true;
    try {
      await api.initialize().timeout(const Duration(seconds: 10));
      return api.isInitialized;
    } catch (e) {
      debugPrint('🔗 ApiService not ready yet: $e');
      return api.isInitialized;
    }
  }

  Future<void> _tryOpenPending() async {
    if (_isResolving) return;

    final articleId = _pendingArticleId;
    if (articleId == null) return;

    final context = appNavigatorKey.currentContext;
    if (context == null) return;

    _isResolving = true;
    _attemptCount++;
    try {
      // Wait for bootstrap on cold start so Firebase/API are ready.
      if (!AppBootstrap.isReady) {
        final ready = await AppBootstrap.waitForReady(
          timeout: const Duration(seconds: 12),
        );
        if (!ready) {
          debugPrint('🔗 Bootstrap still not ready (attempt $_attemptCount)');
        }
      }

      if (!_userService.isLoggedIn) {
        debugPrint('🔗 Not logged in — routing to AuthScreen');
        _navigateToLogin();
        return;
      }

      final navigator = appNavigatorKey.currentState;
      if (navigator == null) return;

      // Cold-start routing is owned by SplashScreen → Home/Auth.
      // Splash / Home call processPendingLink after navigation and mark home ready.
      if (_fromColdStart && !_homeSeeded) {
        debugPrint('🔗 Waiting for splash/home before opening article');
        return;
      }
      if (_fromColdStart) {
        _fromColdStart = false;
      }

      if (!context.mounted) return;

      var article = NewsArticleResolver.findById(articleId);

      if (article == null) {
        final online = await ConnectivityHelper.hasConnection();
        if (!online) {
          debugPrint('🔗 Article $articleId not cached and offline');
          if (_attemptCount >= _maxAttempts) {
            _failPending(context, offline: true);
          }
          return;
        }

        final apiReady = await _ensureApiReady();
        if (!apiReady) {
          debugPrint(
              '🔗 Skipping article fetch — API not ready (attempt $_attemptCount)');
          return;
        }

        article = await _resolveWithLoading(context, articleId);
      }

      if (article == null) {
        debugPrint(
            '🔗 Article $articleId could not be loaded (attempt $_attemptCount)');
        if (_attemptCount >= _maxAttempts) {
          _failPending(context);
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

  void _failPending(BuildContext context, {bool offline = false}) {
    if (_userOpenedShareLink && !_showedNotFoundSnackBar) {
      _showNotFoundMessage(context, offline: offline);
      _showedNotFoundSnackBar = true;
    }
    // Keep pending cleared so we don't spam after final failure.
    _pendingArticleId = null;
    _userOpenedShareLink = false;
    _fromColdStart = false;
  }

  void _clearPending() {
    _pendingArticleId = null;
    _userOpenedShareLink = false;
    _showedNotFoundSnackBar = false;
    _routedToLogin = false;
    _fromColdStart = false;
    _homeSeeded = false;
    _attemptCount = 0;
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
    _attemptCount = 0;
    _showedNotFoundSnackBar = false;
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
    final api = ApiService();
    if (!api.isInitialized) {
      try {
        await api.initialize().timeout(const Duration(seconds: 10));
      } catch (_) {}
    }

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
