import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../data/services/completed_news_service.dart';
import '../data/services/user_service.dart';

/// Completed news provider with local-first approach.
/// Local Hive storage is the primary source for instant UI updates.
/// Firestore syncs in the background for cross-device persistence.
class CompletedNewsProvider with ChangeNotifier {
  CompletedNewsProvider() {
    _userService = UserService();
  }

  late final UserService _userService;
  final CompletedNewsService _completedService = CompletedNewsService.instance;

  String? _userId;
  String? get userId => _userId;

  Set<String> _completedNewsIds = {};
  Set<String> get completedNewsIds => Set.unmodifiable(_completedNewsIds);

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  StreamSubscription<Set<String>>? _streamSubscription;

  static const String _hiveBoxName = 'completed_news';

  Future<Box<String>> _getBox() async {
    if (Hive.isBoxOpen(_hiveBoxName)) {
      return Hive.box<String>(_hiveBoxName);
    }
    return await Hive.openBox<String>(_hiveBoxName);
  }

  /// Load completed IDs from local Hive storage for a given user.
  Future<Set<String>> _loadLocal(String userId) async {
    try {
      final box = await _getBox();
      final key = 'completed_$userId';
      final raw = box.get(key);
      if (raw != null && raw.isNotEmpty) {
        return raw.split(',').toSet();
      }
    } catch (e) {
      debugPrint('⚠️ [CompletedNewsProvider] local load error: $e');
    }
    return {};
  }

  /// Save completed IDs to local Hive storage.
  Future<void> _saveLocal(String userId, Set<String> ids) async {
    try {
      final box = await _getBox();
      final key = 'completed_$userId';
      await box.put(key, ids.join(','));
    } catch (e) {
      debugPrint('⚠️ [CompletedNewsProvider] local save error: $e');
    }
  }

  /// Call on app start and after login.
  Future<void> loadForCurrentUser() async {
    final id = _userService.getUserId();
    debugPrint(
        '🔄 [CompletedNewsProvider] loadForCurrentUser userId=${id ?? "null"}');

    if (id == null || id.isEmpty) {
      await _clearUser();
      return;
    }
    if (_userId == id) return;

    await _clearUser();
    _userId = id;
    _isLoading = true;
    notifyListeners();

    // Load from local storage first (instant)
    _completedNewsIds = await _loadLocal(id);
    _isLoading = false;
    debugPrint(
        '✅ [CompletedNewsProvider] local load count=${_completedNewsIds.length}');
    notifyListeners();

    // Then try Firestore in background
    try {
      final firestoreIds = await _completedService.getCompletedNewsOnce(id);
      if (firestoreIds.isNotEmpty) {
        _completedNewsIds = {..._completedNewsIds, ...firestoreIds};
        await _saveLocal(id, _completedNewsIds);
        notifyListeners();
      }

      _streamSubscription?.cancel();
      _streamSubscription =
          _completedService.getCompletedNewsStream(id).listen(
                (ids) {
                  if (ids.isNotEmpty) {
                    _completedNewsIds = {..._completedNewsIds, ...ids};
                    _saveLocal(id, _completedNewsIds);
                  }
                  notifyListeners();
                },
                onError: (e) {
                  debugPrint(
                      '⚠️ [CompletedNewsProvider] stream error (using local): $e');
                },
              );
    } catch (e) {
      debugPrint(
          '⚠️ [CompletedNewsProvider] Firestore load failed, using local only: $e');
    }
  }

  Future<void> clearUser() async {
    debugPrint('🔄 [CompletedNewsProvider] clearUser');
    await _clearUser();
  }

  Future<void> _clearUser() async {
    await _streamSubscription?.cancel();
    _streamSubscription = null;
    _userId = null;
    _completedNewsIds = {};
    _isLoading = false;
    notifyListeners();
  }

  /// Marks news as completed: updates local storage immediately, then writes to Firestore.
  Future<bool> markNewsCompleted(String newsId, String category) async {
    final id = _userId ?? _userService.getUserId();
    if (id == null || id.isEmpty) {
      debugPrint('❌ [CompletedNewsProvider] markNewsCompleted: no userId');
      return false;
    }
    if (newsId.isEmpty) return false;

    // Update local immediately so UI turns green right away
    _completedNewsIds = {..._completedNewsIds, newsId};
    notifyListeners();
    await _saveLocal(id, _completedNewsIds);
    debugPrint(
        '✅ [CompletedNewsProvider] marked locally newsId=$newsId count=${_completedNewsIds.length}');

    // Try Firestore in background (non-blocking)
    _completedService
        .markNewsCompleted(userId: id, newsId: newsId, category: category)
        .then((ok) {
      if (ok) {
        debugPrint('✅ [CompletedNewsProvider] Firestore write success');
      } else {
        debugPrint(
            '⚠️ [CompletedNewsProvider] Firestore write failed, local is still valid');
      }
    });

    return true;
  }

  Future<bool> removeCompletedNews(String newsId) async {
    final id = _userId ?? _userService.getUserId();
    if (id == null || id.isEmpty) return false;
    if (newsId.isEmpty) return false;

    _completedNewsIds = Set.from(_completedNewsIds)..remove(newsId);
    notifyListeners();
    await _saveLocal(id, _completedNewsIds);

    return _completedService.removeCompletedNews(userId: id, newsId: newsId);
  }

  bool isCompleted(String newsId) {
    if (newsId.isEmpty) return false;
    return _completedNewsIds.contains(newsId);
  }
}
