import 'package:flutter/foundation.dart';

import '../../../data/services/api_service.dart';
import '../../../data/services/user_service.dart';
import '../domain/notification_inbox_state.dart';

/// Inbox list client — existing notification-user endpoint on the API host.
class V2NotificationInboxApi {
  V2NotificationInboxApi({
    ApiService? apiService,
    UserService? userService,
  })  : _apiOrNull = apiService,
        _usersOrNull = userService;

  ApiService? _apiOrNull;
  UserService? _usersOrNull;

  ApiService get _api => _apiOrNull ??= ApiService();
  UserService get _users => _usersOrNull ??= UserService();

  static const path = '/api/notification-user/getCustomerNotifications';

  Future<List<V2NotificationInboxItem>> fetch({
    int page = 1,
    int limit = 50,
  }) async {
    final token = _users.getToken();
    if (token == null || token.isEmpty || !_users.isLoggedIn) {
      return const [];
    }

    final response = await _api.getByPath(
      path,
      queryParameters: {
        'page': '$page',
        'limit': '$limit',
      },
      bearerToken: token,
    );

    if (!response.success || response.data == null) {
      throw V2NotificationInboxException(
        response.error ?? 'Failed to load notifications',
      );
    }
    return V2NotificationInboxState.parseList(response.data);
  }
}

class V2NotificationInboxException implements Exception {
  V2NotificationInboxException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Loads and refreshes the V2 notification inbox.
class V2NotificationInboxController extends ChangeNotifier {
  V2NotificationInboxController({V2NotificationInboxApi? api})
      : _api = api ?? V2NotificationInboxApi();

  final V2NotificationInboxApi _api;

  V2NotificationInboxState _state = const V2NotificationInboxState();
  V2NotificationInboxState get state => _state;

  bool _refreshInFlight = false;
  bool get refreshInFlight => _refreshInFlight;

  Future<void> loadInitial() async {
    _state = const V2NotificationInboxState(
      phase: V2NotificationInboxPhase.loading,
    );
    notifyListeners();
    try {
      final items = await _api.fetch();
      _state = V2NotificationInboxState.fromSuccess(items);
    } catch (e) {
      debugPrint('⚠️ V2NotificationInbox load failed: $e');
      _state = V2NotificationInboxState.fromError(e.toString());
    }
    notifyListeners();
  }

  Future<void> refresh() async {
    if (_refreshInFlight) return;
    _refreshInFlight = true;
    notifyListeners();
    try {
      final items = await _api.fetch();
      _state = V2NotificationInboxState.fromSuccess(items);
    } catch (e) {
      debugPrint('⚠️ V2NotificationInbox refresh failed: $e');
      _state = V2NotificationInboxState.fromError(
        e.toString(),
        preserve: _state.items,
      );
    } finally {
      _refreshInFlight = false;
      notifyListeners();
    }
  }
}
