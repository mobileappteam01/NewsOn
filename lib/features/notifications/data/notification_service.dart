import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import '../../../app/routing/v2_routes.dart';
import '../../../core/analytics/analytics_service.dart';
import '../../../core/bootstrap/app_bootstrap.dart';
import '../../../core/config/v2_feature_flags.dart';
import '../../../core/navigation/app_navigator.dart';
import '../../../core/utils/localization_helper.dart';
import '../../../data/models/remote_config_model.dart';
import '../../../data/services/fcm_service.dart';
import '../../../data/services/news_article_resolver.dart';
import '../../../data/services/user_service.dart';
import '../domain/notification_destination.dart';
import '../domain/notification_destination_resolver.dart';
import '../domain/notification_open_dedupe.dart';
import 'notification_payload.dart';
import 'notification_preferences_api.dart';

/// Top-level background handler — required by firebase_messaging.
@pragma('vm:entry-point')
Future<void> v2FirebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Do not navigate here. Persist nothing sensitive. Open handled on resume.
  debugPrint('ℹ️ V2 FCM background message received (no navigation)');
}

/// V2 notification lifecycle + allowlisted deep-link navigation.
class V2NotificationService {
  V2NotificationService._();
  static final V2NotificationService instance = V2NotificationService._();

  /// Lazily resolved so constructing the singleton in VM unit tests does not
  /// require Firebase.initializeApp().
  FirebaseMessaging? _messagingOrNull;
  FirebaseMessaging get _messaging =>
      _messagingOrNull ??= FirebaseMessaging.instance;

  final NotificationPreferencesApi _prefsApi = NotificationPreferencesApi();
  final UserService _users = UserService();

  bool _initialized = false;
  bool _navigationReady = false;
  bool _processingOpen = false;
  NotificationPayload? _pendingOpen;
  StreamSubscription<RemoteMessage>? _foregroundSub;
  StreamSubscription<RemoteMessage>? _openedSub;

  final NotificationOpenDedupe _openDedupe = NotificationOpenDedupe();

  /// Test hooks — do not use in production paths.
  @visibleForTesting
  NotificationPayload? get debugPendingOpen => _pendingOpen;

  @visibleForTesting
  set debugPendingOpen(NotificationPayload? value) => _pendingOpen = value;

  @visibleForTesting
  bool get debugNavigationReady => _navigationReady;

  @visibleForTesting
  set debugNavigationReady(bool value) => _navigationReady = value;

  @visibleForTesting
  NotificationOpenDedupe get debugOpenDedupe => _openDedupe;

  bool _enabled(RemoteConfigModel? config) {
    if (config == null) return false;
    return V2FeatureFlags.notifications(config);
  }

  /// Call once after Firebase is ready. Safe when flag is OFF (no-op listeners).
  Future<void> initialize({
    required RemoteConfigModel config,
  }) async {
    if (_initialized) return;
    _initialized = true;

    if (!_enabled(config)) {
      debugPrint('ℹ️ V2 notifications disabled — skipping FCM open handlers');
      return;
    }

    try {
      FirebaseMessaging.onBackgroundMessage(
        v2FirebaseMessagingBackgroundHandler,
      );
    } catch (e) {
      debugPrint('ℹ️ Background handler already set or unavailable: $e');
    }

    _foregroundSub = FirebaseMessaging.onMessage.listen(_onForeground);
    _openedSub = FirebaseMessaging.onMessageOpenedApp.listen(_onOpened);

    try {
      final initial = await _messaging.getInitialMessage();
      if (initial != null) {
        final payload = _payloadFromMessage(initial);
        if (payload != null) {
          _pendingOpen = payload;
          debugPrint('ℹ️ Pending V2 notification from terminated state');
        }
      }
    } catch (e) {
      debugPrint('ℹ️ getInitialMessage failed: $e');
    }

    // Soft device registration when logged in — never blocks launch.
    unawaited(_maybeRegisterDevice());
  }

  /// Mark navigation stack ready (Home/Auth/Splash finished first route).
  void processPendingOpen({bool navigationReady = false}) {
    if (navigationReady) _navigationReady = true;
    unawaited(_flushPendingOpen());
  }

  Future<void> _maybeRegisterDevice() async {
    try {
      if (!_users.isLoggedIn) return;
      final token = await FcmService().getToken();
      if (token == null || token.isEmpty) return;
      await _prefsApi.registerDevice(fcmToken: token);
    } catch (_) {
      // Soft
    }
  }

  /// Re-register after login when V2 notifications are enabled.
  Future<void> onUserAuthenticated(RemoteConfigModel config) async {
    if (!_enabled(config)) return;
    await _maybeRegisterDevice();
  }

  void _onForeground(RemoteMessage message) {
    final payload = _payloadFromMessage(message);
    if (payload == null) return;
    // Foreground: never navigate automatically.
    _showForegroundBanner(payload);
  }

  void _onOpened(RemoteMessage message) {
    final payload = _payloadFromMessage(message);
    if (payload == null) {
      _pendingOpen = null;
      return;
    }
    _pendingOpen = payload;
    unawaited(_flushPendingOpen());
  }

  NotificationPayload? _payloadFromMessage(RemoteMessage message) {
    try {
      final data = <String, dynamic>{};
      message.data.forEach((k, v) => data[k] = v);
      // Prefer notification title/body for foreground UI only.
      final n = message.notification;
      if (n?.title != null) data.putIfAbsent('title', () => n!.title);
      if (n?.body != null) data.putIfAbsent('body', () => n!.body);
      return NotificationPayload.tryParse(data);
    } catch (_) {
      return null;
    }
  }

  Future<void> _flushPendingOpen() async {
    if (_processingOpen) return;
    final payload = _pendingOpen;
    if (payload == null) return;
    if (!_navigationReady) return;

    try {
      await AppBootstrap.waitForReady(
        timeout: const Duration(seconds: 12),
      );
    } catch (_) {}

    if (_openDedupe.shouldSkip(payload.dedupeKey)) return;

    _processingOpen = true;
    _pendingOpen = null;
    try {
      await _navigateFromPayload(payload, emitAnalytics: true);
    } catch (e) {
      debugPrint('ℹ️ V2 notification open failed safely: $e');
      await _openHomeSafe();
    } finally {
      _processingOpen = false;
    }
  }

  Future<void> _navigateFromPayload(
    NotificationPayload payload, {
    required bool emitAnalytics,
  }) async {
    if (emitAnalytics) {
      unawaited(
        AnalyticsService.instance.notificationOpen(
          campaignId: payload.campaignId,
          type: payload.type,
          newsId: payload.articleId,
        ),
      );
    }

    final dest = NotificationDestinationResolver.resolve(payload);
    final context = appNavigatorKey.currentContext;
    if (context == null || !context.mounted) {
      _pendingOpen = payload;
      return;
    }

    switch (dest) {
      case ArticleDestination(:final articleId, :final fromCut):
        final article = await NewsArticleResolver.resolveById(articleId);
        if (!context.mounted) return;
        if (article == null) {
          _showUnavailable(context);
          await V2Routes.openHome(context);
          return;
        }
        await V2Routes.openArticle(context, article: article);
        if (fromCut) {
          // Cut context is ArticleDetail when V2 detail flag is on — already handled.
        }
        break;

      case CategoryDestination(:final categoryId):
        await V2Routes.openCategory(context, categoryId: categoryId);
        break;

      case PublisherDestination(:final publisherId):
        if (publisherId.trim().isEmpty) {
          await V2Routes.openHome(context);
          return;
        }
        if (!V2Routes.publisherLinksEnabled(context)) {
          await V2Routes.openHome(context);
          return;
        }
        await V2Routes.openPublisher(
          context,
          publisherId: publisherId,
        );
        break;

      case InboxDestination():
        await V2Routes.openNotificationInbox(context);
        break;

      case HomeDestination():
        await V2Routes.openHome(context);
        break;
    }
  }

  void _showForegroundBanner(NotificationPayload payload) {
    final context = appNavigatorKey.currentContext;
    if (context == null || !context.mounted) return;
    final title = payload.title ??
        LocalizationHelper.v2NotificationTitle(context);
    final body = payload.body ?? '';
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(
      SnackBar(
        content: Semantics(
          label: '$title. $body',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              if (body.isNotEmpty) Text(body),
            ],
          ),
        ),
        action: SnackBarAction(
          label: LocalizationHelper.v2NotificationOpen(context),
          onPressed: () {
            _pendingOpen = payload;
            unawaited(_flushPendingOpen());
          },
        ),
        duration: const Duration(seconds: 6),
      ),
    );
  }

  void _showUnavailable(BuildContext context) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(LocalizationHelper.v2NotificationUnavailable(context)),
      ),
    );
  }

  Future<void> _openHomeSafe() async {
    final context = appNavigatorKey.currentContext;
    if (context == null || !context.mounted) return;
    await V2Routes.openHome(context);
  }

  void dispose() {
    _foregroundSub?.cancel();
    _openedSub?.cancel();
    _foregroundSub = null;
    _openedSub = null;
  }
}
