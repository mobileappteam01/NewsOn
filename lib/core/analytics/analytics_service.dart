import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/services/api_service.dart';
import '../../data/services/user_service.dart';
import '../../data/services/v2_api_config_service.dart';
import 'analytics_events.dart';
import 'analytics_session.dart';

/// Central analytics emitter. Failures never block UI.
///
/// Posts to `POST /api/analytics/track` (Phase 1D). Soft-fails on network errors.
/// Keep InteractionService (personalization) separate from these product events.
class AnalyticsService {
  AnalyticsService._();
  static final AnalyticsService instance = AnalyticsService._();

  ApiService? _apiService;
  UserService? _userService;
  final AnalyticsSession _session = AnalyticsSession.instance;

  /// Canonical mobile ingest path (bypasses Firestore endpoint catalog).
  static const String trackPath = '/api/analytics/track';

  /// Impression / summary_view debounce window.
  static const Duration _dedupeWindow = Duration(seconds: 8);

  final Map<String, DateTime> _recentKeys = {};
  bool _sessionStartSent = false;

  /// After V2 returns 403 Invalid Token, skip bearer until token identity changes.
  bool _skipBearerAfterInvalidToken = false;
  String? _bearerIdentity;

  /// Test seam — inject ApiService without Firebase when validating payloads.
  @visibleForTesting
  void debugReset({ApiService? apiService, UserService? userService}) {
    _apiService = apiService;
    _userService = userService;
    _recentKeys.clear();
    _sessionStartSent = false;
    _skipBearerAfterInvalidToken = false;
    _bearerIdentity = null;
  }

  String get sessionId => _session.sessionId;

  ApiService? get _api {
    try {
      return _apiService ??= ApiService();
    } catch (_) {
      return null;
    }
  }

  UserService? get _users {
    try {
      return _userService ??= UserService();
    } catch (_) {
      return null;
    }
  }

  void ensureSessionStarted() {
    _session.startSession();
    if (!_sessionStartSent) {
      _sessionStartSent = true;
      unawaited(log(AnalyticsEvents.sessionStart));
      unawaited(log(AnalyticsEvents.appOpen));
    }
  }

  /// Builds the Phase 1D track body. Dimensions are top-level; extras → metadata.
  @visibleForTesting
  static Map<String, dynamic> buildTrackBody({
    required String eventName,
    required String sessionId,
    required String platform,
    DateTime? timestamp,
    Map<String, dynamic>? params,
  }) {
    final body = <String, dynamic>{
      'eventName': eventName,
      'sessionId': sessionId,
      'timestamp': (timestamp ?? DateTime.now().toUtc()).toIso8601String(),
      'platform': normalizePlatform(platform),
    };

    if (params == null || params.isEmpty) return body;

    final metadata = <String, dynamic>{};
    for (final entry in params.entries) {
      final key = entry.key;
      final value = entry.value;
      if (value == null) continue;
      final asString = value is String ? value.trim() : value.toString().trim();
      if (asString.isEmpty) continue;

      switch (key) {
        case 'newsId':
          // Backend requires Mongo ObjectId; never send titles/slugs.
          if (RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(asString)) {
            body['newsId'] = asString;
          }
          break;
        case 'publisherId':
          if (RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(asString)) {
            body['publisherId'] = asString;
          } else {
            metadata['publisherIdHint'] = asString;
          }
          break;
        case 'categoryId':
          if (RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(asString)) {
            body['categoryId'] = asString;
          }
          break;
        case 'language':
        case 'newsLanguage':
          body['language'] = asString;
          break;
        case 'region':
        case 'regionLabel':
          body['region'] = asString;
          break;
        default:
          // Non-dimension extras (queryLength, url, publisherName, …).
          metadata[key] = value is String ? asString : value;
      }
    }

    // Soft alias: category name alone is not categoryId (ObjectId required).
    if (!body.containsKey('categoryId') &&
        params['category'] is String &&
        (params['category'] as String).trim().isNotEmpty) {
      metadata.putIfAbsent('category', () => (params['category'] as String).trim());
    }

    if (metadata.isNotEmpty) {
      body['metadata'] = metadata;
    }
    return body;
  }

  /// Canonical platform tokens expected by V2 `/api/analytics/track`.
  @visibleForTesting
  static String normalizePlatform(String raw) {
    final p = raw.trim().toLowerCase();
    if (p == 'ios' || p == 'iphone' || p == 'ipad') return 'ios';
    if (p == 'android') return 'android';
    if (p == 'web' || p == 'fuchsia' || p == 'linux' || p == 'macos' || p == 'windows') {
      return 'web';
    }
    // TargetPlatform.iOS.name == 'iOS' → ios after lowercasing above.
    return 'android';
  }

  /// Optional JWT for analytics — anonymous when absent/rejected.
  @visibleForTesting
  static String? resolveOptionalBearer({
    required bool isLoggedIn,
    String? token,
    required bool skipAfterInvalidToken,
  }) {
    if (skipAfterInvalidToken) return null;
    if (!isLoggedIn) return null;
    final t = token?.trim();
    if (t == null || t.isEmpty) return null;
    return t;
  }

  @visibleForTesting
  static bool isInvalidTokenResponse({
    required int? statusCode,
    String? error,
  }) {
    if (statusCode != 403) return false;
    final msg = (error ?? '').toLowerCase();
    return msg.contains('invalid token') ||
        msg.contains('invalid jwt') ||
        msg.contains('jwt expired') ||
        msg.contains('token expired') ||
        msg.contains('unauthorized') ||
        msg == 'access forbidden.';
  }

  /// Stable non-secret fingerprint so a new login clears the skip flag.
  static String? _tokenIdentity(String? token) {
    final t = token?.trim();
    if (t == null || t.isEmpty) return null;
    return '${t.length}:${t.hashCode}';
  }

  static String _runtimePlatform() =>
      normalizePlatform(defaultTargetPlatform.name);

  Future<void> log(
    String event, {
    Map<String, dynamic>? params,
    String? dedupeKey,
    Duration? dedupeFor,
    bool v2Only = false,
  }) async {
    try {
      ensureSessionStarted();

      final key = dedupeKey ?? event;
      if (!_shouldEmit(key, dedupeFor ?? _dedupeWindow)) {
        return;
      }

      final body = buildTrackBody(
        eventName: event,
        sessionId: _session.sessionId,
        platform: _runtimePlatform(),
        params: params,
      );

      // Events that require newsId must have a Mongo ObjectId (not a title).
      final needsNewsId = event == AnalyticsEvents.newsOpen ||
          event == AnalyticsEvents.newsImpression ||
          event == AnalyticsEvents.summaryView ||
          event == AnalyticsEvents.fullArticleClick ||
          event == AnalyticsEvents.forYouImpression ||
          event == AnalyticsEvents.bookmark ||
          event == AnalyticsEvents.share ||
          event == AnalyticsEvents.audioClick;
      if (needsNewsId && body['newsId'] == null) {
        debugPrint(
          '📊 Analytics skipped ($event) — newsId missing or not an ObjectId',
        );
        return;
      }

      // Do not send userId — backend derives from JWT when present.
      // Prefer anonymous when logged-out or after V2 rejected the JWT (403).
      String? rawToken;
      var loggedIn = false;
      try {
        final users = _users;
        loggedIn = users?.isLoggedIn == true;
        rawToken = users?.getToken();
      } catch (_) {
        rawToken = null;
        loggedIn = false;
      }

      final identity = _tokenIdentity(rawToken);
      if (identity != _bearerIdentity) {
        _bearerIdentity = identity;
        // New / cleared session — allow bearer again.
        _skipBearerAfterInvalidToken = false;
      }

      var bearer = resolveOptionalBearer(
        isLoggedIn: loggedIn,
        token: rawToken,
        skipAfterInvalidToken: _skipBearerAfterInvalidToken,
      );
      debugPrint('📊 Analytics auth token present=${bearer != null}');

      final api = _api;
      if (api == null) {
        debugPrint('📊 Analytics (offline/no API): $event $params');
        return;
      }

      // Prefer isolated V2 host when ready; otherwise keep V1 behavior
      // (unless [v2Only] — V2 surfaces must never fall back to api.newson.app).
      try {
        await V2ApiConfigService.instance.ensureReady();
      } catch (_) {
        // Soft — analytics must never block product UI.
      }
      final v2Base = V2ApiConfigService.instance.baseUrlIfEnabled;
      final canUseV2 = v2Base != null && v2Base.isNotEmpty;

      if (v2Only) {
        if (!canUseV2) {
          debugPrint(
            '📊 Analytics skipped ($event) — V2 host unavailable (v2Only)',
          );
          return;
        }
      } else if (!canUseV2 && !_hasUsableBaseUrl(api)) {
        debugPrint('📊 Analytics (offline/no API): $event $params');
        return;
      }

      final useV2Host = v2Only || canUseV2;

      try {
        var response = await api.postByPath(
          trackPath,
          body: body,
          bearerToken: bearer,
          useV2Host: useV2Host,
        );

        // Stale/invalid JWT on V2 → 403 while anonymous still records 201.
        if (!response.success &&
            bearer != null &&
            isInvalidTokenResponse(
              statusCode: response.statusCode,
              error: response.error,
            )) {
          debugPrint(
            '📊 Analytics 403 invalid token — retrying anonymously '
            '($event)',
          );
          _skipBearerAfterInvalidToken = true;
          bearer = null;
          response = await api.postByPath(
            trackPath,
            body: body,
            bearerToken: null,
            useV2Host: useV2Host,
          );
        }

        if (!response.success) {
          // Surface contract/backend failures without blocking UI.
          debugPrint(
            '📊 Analytics rejected ($event) '
            'host=${useV2Host ? 'V2' : 'V1'} '
            'status=${response.statusCode} '
            'error=${response.error} '
            'authPresent=${bearer != null} '
            'bodyKeys=${body.keys.toList()}',
          );
        }
      } catch (e) {
        // Never block product UI.
        debugPrint('📊 Analytics emit soft-fail ($event): $e');
      }
    } catch (e) {
      debugPrint('📊 Analytics unexpected error ($event): $e');
    }
  }

  bool _hasUsableBaseUrl(ApiService api) {
    try {
      final url = api.getBaseUrl().trim();
      return url.isNotEmpty;
    } catch (_) {
      return api.isInitialized;
    }
  }

  Future<void> newsImpression({
    required String newsId,
    String? category,
    String? publisher,
    bool v2Only = false,
  }) {
    return log(
      AnalyticsEvents.newsImpression,
      params: {
        'newsId': newsId,
        if (category != null) 'category': category,
        if (publisher != null) 'publisher': publisher,
      },
      dedupeKey: 'impression::$newsId',
      v2Only: v2Only,
    );
  }

  Future<void> newsOpen({
    required String newsId,
    bool v2Only = false,
  }) {
    return log(
      AnalyticsEvents.newsOpen,
      params: {'newsId': newsId},
      dedupeKey: 'open::$newsId',
      dedupeFor: const Duration(seconds: 2),
      v2Only: v2Only,
    );
  }

  Future<void> summaryView({
    required String newsId,
    bool v2Only = false,
  }) {
    return log(
      AnalyticsEvents.summaryView,
      params: {'newsId': newsId},
      dedupeKey: 'summary::$newsId',
      v2Only: v2Only,
    );
  }

  Future<void> fullArticleClick({
    required String newsId,
    String? url,
    bool v2Only = false,
  }) {
    return log(
      AnalyticsEvents.fullArticleClick,
      params: {
        'newsId': newsId,
        if (url != null) 'url': url,
      },
      dedupeKey: 'full::$newsId',
      dedupeFor: const Duration(seconds: 2),
      v2Only: v2Only,
    );
  }

  Future<void> categoryView({
    required String category,
    bool v2Only = false,
  }) {
    return log(
      AnalyticsEvents.categoryView,
      params: {'category': category},
      dedupeKey: 'category_view::$category',
      dedupeFor: const Duration(seconds: 30),
      v2Only: v2Only,
    );
  }

  Future<void> publisherView({
    required String publisherId,
    String? publisherName,
    String? language,
    String? sourceScreen,
    bool v2Only = false,
  }) {
    return log(
      AnalyticsEvents.publisherView,
      params: {
        'publisherId': publisherId,
        if (publisherName != null) 'publisherName': publisherName,
        if (language != null && language.isNotEmpty) 'language': language,
        if (sourceScreen != null && sourceScreen.isNotEmpty)
          'sourceScreen': sourceScreen,
      },
      dedupeKey: 'publisher_view::$publisherId',
      dedupeFor: const Duration(seconds: 60),
      v2Only: v2Only,
    );
  }

  Future<void> publisherClick({
    required String publisherId,
    String? publisherName,
    String? language,
    String? sourceScreen,
    bool v2Only = false,
  }) {
    return log(
      AnalyticsEvents.publisherClick,
      params: {
        'publisherId': publisherId,
        if (publisherName != null) 'publisherName': publisherName,
        if (language != null && language.isNotEmpty) 'language': language,
        if (sourceScreen != null && sourceScreen.isNotEmpty)
          'sourceScreen': sourceScreen,
      },
      dedupeKey: 'publisher_click::$publisherId::${sourceScreen ?? ''}',
      dedupeFor: const Duration(seconds: 2),
      v2Only: v2Only,
    );
  }

  Future<void> forYouImpression({
    String? newsId,
    bool v2Only = false,
  }) {
    return log(
      AnalyticsEvents.forYouImpression,
      params: {
        if (newsId != null) 'newsId': newsId,
      },
      dedupeKey: newsId != null
          ? 'for_you_impression::$newsId'
          : 'for_you_impression::section',
      dedupeFor: const Duration(seconds: 60),
      v2Only: v2Only,
    );
  }

  /// Emit only on submitted / executed search — never per keystroke.
  Future<void> search({
    required String query,
    bool v2Only = false,
  }) {
    final q = query.trim();
    if (q.isEmpty) return Future.value();
    return log(
      AnalyticsEvents.search,
      params: {'queryLength': q.length},
      dedupeKey: 'search::${q.toLowerCase()}',
      dedupeFor: const Duration(seconds: 5),
      v2Only: v2Only,
    );
  }

  /// Emit only on actual user Listen / audio control interaction.
  Future<void> audioClick({
    required String newsId,
    bool v2Only = false,
  }) {
    final id = newsId.trim();
    if (id.isEmpty) return Future.value();
    return log(
      AnalyticsEvents.audioClick,
      params: {'newsId': id},
      dedupeKey: 'audio_click::$id',
      dedupeFor: const Duration(seconds: 2),
      v2Only: v2Only,
    );
  }

  /// Emit only when the user opens/taps a notification (not on receipt).
  Future<void> notificationOpen({
    String? campaignId,
    String? type,
    String? newsId,
    bool v2Only = false,
  }) {
    return log(
      AnalyticsEvents.notificationOpen,
      params: {
        if (campaignId != null && campaignId.isNotEmpty)
          'campaignId': campaignId,
        if (type != null && type.isNotEmpty) 'type': type,
        if (newsId != null && newsId.isNotEmpty) 'newsId': newsId,
      },
      dedupeKey:
          'notification_open::${campaignId ?? ''}::${type ?? ''}::${newsId ?? ''}',
      dedupeFor: const Duration(seconds: 5),
      v2Only: v2Only,
    );
  }

  Future<void> bookmark({
    required String newsId,
    bool v2Only = false,
  }) {
    return log(
      AnalyticsEvents.bookmark,
      params: {'newsId': newsId},
      dedupeKey: 'bookmark::$newsId',
      dedupeFor: const Duration(seconds: 2),
      v2Only: v2Only,
    );
  }

  Future<void> share({
    required String newsId,
    bool v2Only = false,
  }) {
    return log(
      AnalyticsEvents.share,
      params: {'newsId': newsId},
      dedupeKey: 'share::$newsId',
      dedupeFor: const Duration(seconds: 2),
      v2Only: v2Only,
    );
  }

  Future<void> languageChange({
    required String newsLanguage,
    bool v2Only = false,
  }) {
    return log(
      AnalyticsEvents.languageChange,
      params: {'newsLanguage': newsLanguage},
      dedupeKey: 'language_change::$newsLanguage',
      dedupeFor: const Duration(seconds: 2),
      v2Only: v2Only,
    );
  }

  Future<void> regionChange({
    String? regionLabel,
    bool v2Only = false,
  }) {
    return log(
      AnalyticsEvents.regionChange,
      params: {
        if (regionLabel != null) 'region': regionLabel,
      },
      dedupeKey: 'region_change::${regionLabel ?? 'cleared'}',
      dedupeFor: const Duration(seconds: 2),
      v2Only: v2Only,
    );
  }

  bool _shouldEmit(String key, Duration window) {
    final now = DateTime.now();
    final last = _recentKeys[key];
    if (last != null && now.difference(last) < window) {
      return false;
    }
    _recentKeys[key] = now;
    // Bound map growth
    if (_recentKeys.length > 400) {
      final cutoff = now.subtract(const Duration(minutes: 10));
      _recentKeys.removeWhere((_, t) => t.isBefore(cutoff));
    }
    return true;
  }
}
