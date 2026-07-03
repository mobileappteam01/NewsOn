import 'package:flutter/foundation.dart';

import '../data/models/news_article.dart';
import '../data/services/for_you_service.dart';
import '../data/services/user_service.dart';

/// State for the personalized For You feed tab.
class ForYouProvider with ChangeNotifier {
  final ForYouService _forYouService = ForYouService();
  final UserService _userService = UserService();

  static const int _defaultLimit = 15;

  List<NewsArticle> _articles = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _error;
  int _currentPage = 1;
  bool _hasMore = true;
  int _totalResults = 0;

  List<NewsArticle> get articles => _articles;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  String? get error => _error;
  bool get hasMore => _hasMore;
  bool get hasArticles => _articles.isNotEmpty;
  int get totalResults => _totalResults;

  bool get requiresSignIn => !_userService.isLoggedIn;

  /// Initial load or pull-to-refresh.
  Future<void> refresh({int limit = _defaultLimit}) async {
    if (requiresSignIn) {
      _articles = [];
      _error = 'Please sign in to see your personalized feed';
      _hasMore = false;
      notifyListeners();
      return;
    }

    _currentPage = 1;
    _hasMore = true;
    _error = null;
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _forYouService.fetchForYou(
        page: 1,
        limit: limit,
      );
      _articles = response.articles;
      _totalResults = response.pagination.total;
      _currentPage = response.pagination.page;
      _hasMore = response.pagination.hasMore;
      _isLoading = false;
      _error = null;
      debugPrint('✅ ForYouProvider refreshed: ${_articles.length} items');
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      if (_articles.isEmpty) {
        _hasMore = false;
      }
      debugPrint('❌ ForYouProvider refresh error: $e');
    }

    notifyListeners();
  }

  /// Infinite scroll — next page.
  Future<void> loadMore({int limit = _defaultLimit}) async {
    if (requiresSignIn || _isLoading || _isLoadingMore || !_hasMore) {
      return;
    }

    _isLoadingMore = true;
    notifyListeners();

    try {
      final nextPage = _currentPage + 1;
      final response = await _forYouService.fetchForYou(
        page: nextPage,
        limit: limit,
      );

      if (response.articles.isEmpty) {
        _hasMore = false;
      } else {
        _articles = [..._articles, ...response.articles];
        _currentPage = response.pagination.page;
        _hasMore = response.pagination.hasMore;
        _totalResults = response.pagination.total;
      }

      _isLoadingMore = false;
      _error = null;
    } catch (e) {
      _isLoadingMore = false;
      _error = e.toString();
      debugPrint('❌ ForYouProvider loadMore error: $e');
    }

    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
