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

  /// Test seam — inject ApiService without Firebase when validating payloads.
  @visibleForTesting
  void debugReset({ApiService? apiService, UserService? userService}) {
    _apiService = apiService;
    _userService = userService;
    _recentKeys.clear();
    _sessionStartSent = false;
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
      'platform': platform,
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
          body['newsId'] = asString;
          break;
        case 'publisherId':
          body['publisherId'] = asString;
          break;
        case 'categoryId':
          body['categoryId'] = asString;
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

  Future<void> log(
    String event, {
    Map<String, dynamic>? params,
    String? dedupeKey,
    Duration? dedupeFor,
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
        platform: defaultTargetPlatform.name,
        params: params,
      );

      // Do not send userId — backend derives from JWT when present.
      String? token;
      try {
        token = _users?.getToken();
      } catch (_) {
        token = null;
      }

      final api = _api;
      if (api == null) {
        debugPrint('📊 Analytics (offline/no API): $event $params');
        return;
      }

      // Prefer isolated V2 host when ready; otherwise keep V1 behavior.
      try {
        await V2ApiConfigService.instance.ensureReady();
      } catch (_) {
        // Soft — analytics must never block product UI.
      }
      final v2Base = V2ApiConfigService.instance.baseUrlIfEnabled;
      final canUseV2 = v2Base != null && v2Base.isNotEmpty;
      if (!canUseV2 && !_hasUsableBaseUrl(api)) {
        debugPrint('📊 Analytics (offline/no API): $event $params');
        return;
      }

      try {
        await api.postByPath(
          trackPath,
          body: body,
          bearerToken: (token != null && token.isNotEmpty) ? token : null,
          useV2Host: canUseV2,
        );
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
  }) {
    return log(
      AnalyticsEvents.newsImpression,
      params: {
        'newsId': newsId,
        if (category != null) 'category': category,
        if (publisher != null) 'publisher': publisher,
      },
      dedupeKey: 'impression::$newsId',
    );
  }

  Future<void> newsOpen({required String newsId}) {
    return log(
      AnalyticsEvents.newsOpen,
      params: {'newsId': newsId},
      dedupeKey: 'open::$newsId',
      dedupeFor: const Duration(seconds: 2),
    );
  }

  Future<void> summaryView({required String newsId}) {
    return log(
      AnalyticsEvents.summaryView,
      params: {'newsId': newsId},
      dedupeKey: 'summary::$newsId',
    );
  }

  Future<void> fullArticleClick({
    required String newsId,
    String? url,
  }) {
    return log(
      AnalyticsEvents.fullArticleClick,
      params: {
        'newsId': newsId,
        if (url != null) 'url': url,
      },
      dedupeKey: 'full::$newsId',
      dedupeFor: const Duration(seconds: 2),
    );
  }

  Future<void> categoryView({required String category}) {
    return log(
      AnalyticsEvents.categoryView,
      params: {'category': category},
      dedupeKey: 'category_view::$category',
      dedupeFor: const Duration(seconds: 30),
    );
  }

  Future<void> publisherView({
    required String publisherId,
    String? publisherName,
  }) {
    return log(
      AnalyticsEvents.publisherView,
      params: {
        'publisherId': publisherId,
        if (publisherName != null) 'publisherName': publisherName,
      },
      dedupeKey: 'publisher_view::$publisherId',
      dedupeFor: const Duration(seconds: 60),
    );
  }

  Future<void> forYouImpression({String? newsId}) {
    return log(
      AnalyticsEvents.forYouImpression,
      params: {
        if (newsId != null) 'newsId': newsId,
      },
      dedupeKey: newsId != null
          ? 'for_you_impression::$newsId'
          : 'for_you_impression::section',
      dedupeFor: const Duration(seconds: 60),
    );
  }

  /// Emit only on submitted / executed search — never per keystroke.
  Future<void> search({required String query}) {
    final q = query.trim();
    if (q.isEmpty) return Future.value();
    return log(
      AnalyticsEvents.search,
      params: {'queryLength': q.length},
      dedupeKey: 'search::${q.toLowerCase()}',
      dedupeFor: const Duration(seconds: 5),
    );
  }

  /// Emit only on actual user Listen / audio control interaction.
  Future<void> audioClick({required String newsId}) {
    final id = newsId.trim();
    if (id.isEmpty) return Future.value();
    return log(
      AnalyticsEvents.audioClick,
      params: {'newsId': id},
      dedupeKey: 'audio_click::$id',
      dedupeFor: const Duration(seconds: 2),
    );
  }

  /// Emit only when the user opens/taps a notification (not on receipt).
  Future<void> notificationOpen({
    String? campaignId,
    String? type,
    String? newsId,
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
    );
  }

  Future<void> bookmark({required String newsId}) {
    return log(
      AnalyticsEvents.bookmark,
      params: {'newsId': newsId},
      dedupeKey: 'bookmark::$newsId',
      dedupeFor: const Duration(seconds: 2),
    );
  }

  Future<void> share({required String newsId}) {
    return log(
      AnalyticsEvents.share,
      params: {'newsId': newsId},
      dedupeKey: 'share::$newsId',
      dedupeFor: const Duration(seconds: 2),
    );
  }

  Future<void> languageChange({required String newsLanguage}) {
    return log(
      AnalyticsEvents.languageChange,
      params: {'newsLanguage': newsLanguage},
      dedupeKey: 'language_change::$newsLanguage',
      dedupeFor: const Duration(seconds: 2),
    );
  }

  Future<void> regionChange({String? regionLabel}) {
    return log(
      AnalyticsEvents.regionChange,
      params: {
        if (regionLabel != null) 'region': regionLabel,
      },
      dedupeKey: 'region_change::${regionLabel ?? 'cleared'}',
      dedupeFor: const Duration(seconds: 2),
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
