import 'dart:async';
import 'dart:io';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';

import '../../core/bootstrap/app_bootstrap.dart';
import '../../core/constants/deep_link_constants.dart';
import '../../core/navigation/app_navigator.dart';
import '../../core/utils/connectivity_helper.dart';
import '../../features/news_detail/presentation/v2_article_detail_screen.dart';
import '../../screens/auth/auth_screen.dart';
import '../../screens/home/home_screen.dart';
import '../../screens/news_detail/news_detail_screen.dart';
import '../models/news_article.dart';
import 'api_service.dart';
import 'news_article_resolver.dart';
import 'user_service.dart';

/// Handles share / deep links (Instagram-style).
///
/// - App installed + logged in → article detail for the shared article.
/// - App installed + not logged in (Android) → [AuthScreen], then article after login.
/// - App installed + not logged in (iOS) → guest browse → article (Guideline 5.1.1(v)).
/// - V2 links (`/v2/article/{id}`) open [V2ArticleDetailScreen] and never use
///   [NewsArticleResolver] or the V1 latest-news-by-id fetch path.
/// - Play Store is only in share text for users without the app (not handled here).
class DeepLinkService {
  DeepLinkService._();
  static final DeepLinkService instance = DeepLinkService._();

  final AppLinks _appLinks = AppLinks();
  final UserService _userService = UserService();

  StreamSubscription<Uri>? _linkSubscription;
  String? _pendingArticleId;
  String? _pendingV2ArticleId;
  String? _pendingLinkKey;
  /// Last successfully opened link — ignores warm duplicate redelivery.
  String? _lastOpenedLinkKey;
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
      (_pendingArticleId != null && _pendingArticleId!.isNotEmpty) ||
      (_pendingV2ArticleId != null && _pendingV2ArticleId!.isNotEmpty);

  String? get pendingArticleId => _pendingArticleId ?? _pendingV2ArticleId;

  bool get openedFromShareLink => _userOpenedShareLink;

  @visibleForTesting
  String? get debugLastOpenedLinkKey => _lastOpenedLinkKey;

  @visibleForTesting
  String? get debugPendingLinkKey => _pendingLinkKey;

  @visibleForTesting
  void debugReset() {
    _pendingArticleId = null;
    _pendingV2ArticleId = null;
    _pendingLinkKey = null;
    _lastOpenedLinkKey = null;
    _userOpenedShareLink = false;
    _showedNotFoundSnackBar = false;
    _isResolving = false;
    _routedToLogin = false;
    _fromColdStart = false;
    _homeSeeded = false;
    _attemptCount = 0;
  }

  @visibleForTesting
  void debugMarkOpened(String linkKey) {
    _lastOpenedLinkKey = linkKey;
  }

  @visibleForTesting
  void debugClearPendingOnly() {
    _pendingArticleId = null;
    _pendingV2ArticleId = null;
    _pendingLinkKey = null;
    _userOpenedShareLink = false;
    _showedNotFoundSnackBar = false;
    _routedToLogin = false;
    _fromColdStart = false;
    _homeSeeded = false;
    _attemptCount = 0;
  }

  /// Test seam: enqueue without AppLinks (does not schedule open attempts).
  @visibleForTesting
  void debugEnqueueUri(Uri uri, {bool coldStart = false}) {
    _enqueueFromUri(uri, coldStart: coldStart, scheduleAttempts: false);
  }

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

  void _enqueueFromUri(
    Uri uri, {
    bool coldStart = false,
    bool scheduleAttempts = true,
  }) {
    if (!DeepLinkConstants.isNewsDeepLink(uri)) return;

    final key = DeepLinkConstants.linkKey(uri);
    if (key == null) return;

    // Idempotency: ignore warm redelivery of an already-opened link
    // (e.g. return from WhatsApp share sheet).
    if (!coldStart && key == _lastOpenedLinkKey) {
      debugPrint('🔗 Ignoring already-opened deep link: $key');
      return;
    }
    // Same link already pending — do not reset attempt counters / spam.
    if (key == _pendingLinkKey) {
      debugPrint('🔗 Deep link already pending: $key');
      return;
    }

    final v2Id = DeepLinkConstants.parseV2ArticleId(uri);
    if (v2Id != null) {
      _pendingV2ArticleId = v2Id;
      _pendingArticleId = null;
      _pendingLinkKey = key;
      _userOpenedShareLink = true;
      _showedNotFoundSnackBar = false;
      _routedToLogin = false;
      _homeSeeded = false;
      _attemptCount = 0;
      if (coldStart) _fromColdStart = true;
      debugPrint('🔗 Pending V2 article id: $v2Id (coldStart: $coldStart)');
      if (scheduleAttempts) _schedulePendingLinkAttempts();
      return;
    }

    final articleId = DeepLinkConstants.parseArticleId(uri);
    if (articleId == null || articleId.isEmpty) return;

    _pendingArticleId = articleId;
    _pendingV2ArticleId = null;
    _pendingLinkKey = key;
    _userOpenedShareLink = true;
    _showedNotFoundSnackBar = false;
    _routedToLogin = false;
    _homeSeeded = false;
    _attemptCount = 0;
    if (coldStart) _fromColdStart = true;

    debugPrint('🔗 Pending article id: $articleId (coldStart: $coldStart)');
    if (scheduleAttempts) _schedulePendingLinkAttempts();
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
    if (!hasPendingArticle) return;
    // Longer cold-start window — API / Firebase may still be warming up.
    // V2 opens without resolver retries; still use short schedule for auth/nav.
    const delaysMs = [0, 300, 800, 1500, 2500, 4000, 6000, 9000];
    for (final delay in delaysMs) {
      Future<void>.delayed(Duration(milliseconds: delay), () {
        if (!hasPendingArticle || _isResolving) return;
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
    if (_pendingV2ArticleId != null) {
      await _tryOpenPendingV2();
      return;
    }
    await _tryOpenPendingV1();
  }

  Future<bool> _prepareNavigationGate() async {
    final context = appNavigatorKey.currentContext;
    if (context == null) return false;

    if (!AppBootstrap.isReady) {
      final ready = await AppBootstrap.waitForReady(
        timeout: const Duration(seconds: 12),
      );
      if (!ready) {
        debugPrint('🔗 Bootstrap still not ready (attempt $_attemptCount)');
      }
    }

    if (!_userService.isLoggedIn) {
      if (Platform.isIOS) {
        if (!_userService.isGuestBrowse) {
          await _userService.enableGuestBrowse();
        }
        final navigator = appNavigatorKey.currentState;
        if (navigator != null && !_homeSeeded) {
          navigator.pushAndRemoveUntil(
            MaterialPageRoute<void>(
              builder: (_) => const HomeScreen(selectedCategories: []),
            ),
            (route) => false,
          );
          _homeSeeded = true;
          _fromColdStart = false;
        }
      } else {
        debugPrint('🔗 Not logged in — routing to AuthScreen');
        _navigateToLogin();
        return false;
      }
    }

    final navigator = appNavigatorKey.currentState;
    if (navigator == null) return false;

    if (_fromColdStart && !_homeSeeded) {
      debugPrint('🔗 Waiting for splash/home before opening article');
      return false;
    }
    if (_fromColdStart) {
      _fromColdStart = false;
    }

    return context.mounted;
  }

  Future<void> _tryOpenPendingV2() async {
    if (_isResolving) return;

    final articleId = _pendingV2ArticleId?.trim();
    final linkKey = _pendingLinkKey;
    if (articleId == null || articleId.isEmpty) {
      _clearPending();
      return;
    }

    // Already showing this V2 detail — consume without pushing again.
    final ctx = appNavigatorKey.currentContext;
    final topName = ctx != null ? ModalRoute.of(ctx)?.settings.name : null;
    if (topName == '/v2/article/$articleId') {
      debugPrint('🔗 V2 detail already open for $articleId — consuming');
      _lastOpenedLinkKey = linkKey ?? 'v2:$articleId';
      _clearPending();
      return;
    }

    _isResolving = true;
    _attemptCount++;
    try {
      final ready = await _prepareNavigationGate();
      if (!ready) return;

      final navigator = appNavigatorKey.currentState;
      if (navigator == null) return;

      // Consume exactly once BEFORE push to block duplicate stream callbacks.
      _lastOpenedLinkKey = linkKey ?? 'v2:$articleId';
      _clearPending();

      debugPrint('🔗 Opening V2 article detail for $articleId (no V1 resolver)');
      try {
        await navigator.push(
          MaterialPageRoute<void>(
            settings: RouteSettings(name: '/v2/article/$articleId'),
            builder: (_) => V2ArticleDetailScreen(articleId: articleId),
          ),
        );
      } catch (e, st) {
        // Never crash the app on a bad share open — detail screen itself
        // shows a safe not-found/error state for missing articles.
        debugPrint('🔗 V2 detail navigation failed: $e\n$st');
      }
    } finally {
      _isResolving = false;
    }
  }

  Future<void> _tryOpenPendingV1() async {
    if (_isResolving) return;

    final articleId = _pendingArticleId;
    if (articleId == null) return;

    final context = appNavigatorKey.currentContext;
    if (context == null) return;

    _isResolving = true;
    _attemptCount++;
    try {
      final ready = await _prepareNavigationGate();
      if (!ready) return;

      final navigator = appNavigatorKey.currentState;
      if (navigator == null) return;
      if (!context.mounted) return;

      var article = NewsArticleResolver.findById(articleId);

      if (article == null) {
        final online = await ConnectivityHelper.hasConnection();
        if (!online) {
          debugPrint('🔗 Article $articleId not cached and offline');
          if (_attemptCount >= _maxAttempts) {
            final ctx = appNavigatorKey.currentContext;
            if (ctx != null && ctx.mounted) {
              _failPending(ctx, offline: true);
            }
          }
          return;
        }

        final apiReady = await _ensureApiReady();
        if (!apiReady) {
          debugPrint(
              '🔗 Skipping article fetch — API not ready (attempt $_attemptCount)');
          return;
        }

        final resolveCtx = appNavigatorKey.currentContext;
        if (resolveCtx == null || !resolveCtx.mounted) return;
        article = await _resolveWithLoading(resolveCtx, articleId);
      }

      if (article == null) {
        debugPrint(
            '🔗 Article $articleId could not be loaded (attempt $_attemptCount)');
        if (_attemptCount >= _maxAttempts) {
          final ctx = appNavigatorKey.currentContext;
          if (ctx != null && ctx.mounted) {
            _failPending(ctx);
          }
        }
        return;
      }

      final openCtx = appNavigatorKey.currentContext;
      if (openCtx == null || !openCtx.mounted) return;

      _lastOpenedLinkKey = _pendingLinkKey ?? 'v1:$articleId';
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
    _pendingV2ArticleId = null;
    _pendingLinkKey = null;
    _userOpenedShareLink = false;
    _fromColdStart = false;
  }

  void _clearPending() {
    _pendingArticleId = null;
    _pendingV2ArticleId = null;
    _pendingLinkKey = null;
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
    debugPrint('🔗 Opening article detail for ${article.articleId}');
    // Flag-aware entry: V2 ArticleDetailScreen when enabled, else V1.
    NewsDetailScreen.open(navigator.context, article: article);
  }

  /// For testing / manual open from in-app debug.
  void openArticleById(String articleId) {
    _pendingArticleId = articleId;
    _pendingV2ArticleId = null;
    _pendingLinkKey = 'v1:$articleId';
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
