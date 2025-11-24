import 'package:flutter/foundation.dart';
import '../data/models/news_article.dart';
import '../data/models/news_response.dart';
import '../data/repositories/news_repository.dart';

/// Provider for managing news state
class NewsProvider with ChangeNotifier {
  final NewsRepository _repository;

  NewsProvider({NewsRepository? repository})
    : _repository = repository ?? NewsRepository(apiKey: "");

  // State variables
  List<NewsArticle> _articles = [];
  List<NewsArticle> _breakingNews = [];
  List<NewsArticle> _todayNews = []; // News for selected date
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _isLoadingToday = false;
  String? _error;
  String? _nextPage;
  String? _currentCategory;
  String? _currentQuery;
  DateTime? _selectedDate; // Selected date for archive news

  // Getters
  List<NewsArticle> get articles => _articles;
  List<NewsArticle> get breakingNews => _breakingNews;
  List<NewsArticle> get todayNews => _todayNews;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get isLoadingToday => _isLoadingToday;
  String? get error => _error;
  bool get hasNextPage => _nextPage != null;
  String? get currentCategory => _currentCategory;
  String? get currentQuery => _currentQuery;
  DateTime? get selectedDate => _selectedDate;

  /// Fetch breaking/top news
  Future<void> fetchBreakingNews() async {
    try {
      debugPrint("Fetching breaking news");
      _isLoading = true;
      _error = null;
      notifyListeners();

      final response = await _repository.fetchBreakingNews();
      debugPrint("Fetching breaking news 2.11 : ${response.results.length}");
      debugPrint("Response status: ${response.status}");
      debugPrint("Total results: ${response.totalResults}");

      if (response.results.isNotEmpty) {
        debugPrint("First article title: ${response.results.first.title}");
      }

      _breakingNews = response.results;
      _isLoading = false;
      debugPrint("Breaking news assigned: ${_breakingNews.length} articles");
      notifyListeners();
    } catch (e, stackTrace) {
      debugPrint("Error fetching breaking news: $e");
      debugPrint("Stack trace: $stackTrace");
      _error = e.toString();
      _isLoading = false;
      _breakingNews = [];
      notifyListeners();
    }
  }

  /// Fetch news by category
  Future<void> fetchNewsByCategory(
    String category, {
    bool refresh = false,
  }) async {
    try {
      if (refresh) {
        _articles = [];
        _nextPage = null;
      }

      _isLoading = true;
      _error = null;
      _currentCategory = category;
      _currentQuery = null;
      notifyListeners();

      final response = await _repository.fetchNewsByCategory(category);
      _articles = response.results;
      _nextPage = response.nextPage;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load more news (pagination)
  Future<void> loadMoreNews() async {
    if (_isLoadingMore || _nextPage == null) return;

    try {
      _isLoadingMore = true;
      notifyListeners();

      NewsResponse response;

      if (_currentQuery != null) {
        response = await _repository.searchNews(
          _currentQuery!,
          nextPage: _nextPage,
        );
      } else if (_currentCategory != null) {
        response = await _repository.fetchNewsByCategory(
          _currentCategory!,
          nextPage: _nextPage,
        );
      } else {
        response = await _repository.fetchBreakingNews(nextPage: _nextPage);
      }

      _articles.addAll(response.results);
      _nextPage = response.nextPage;
      _isLoadingMore = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  /// Search news
  Future<void> searchNews(String query, {bool refresh = false}) async {
    if (query.isEmpty) {
      clearSearch();
      return;
    }

    try {
      if (refresh) {
        _articles = [];
        _nextPage = null;
      }

      _isLoading = true;
      _error = null;
      _currentQuery = query;
      _currentCategory = null;
      notifyListeners();

      final response = await _repository.searchNews(query);
      _articles = response.results;
      _nextPage = response.nextPage;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Clear search and reset to default
  void clearSearch() {
    _currentQuery = null;
    _articles = [];
    _nextPage = null;
    _error = null;
    notifyListeners();
  }

  /// Toggle bookmark for an article
  Future<bool> toggleBookmark(NewsArticle article) async {
    try {
      final isBookmarked = await _repository.toggleBookmark(article);

      // Update article in lists
      _updateArticleInLists(article, isBookmarked);

      notifyListeners();
      return isBookmarked;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Update article bookmark status in all lists
  void _updateArticleInLists(NewsArticle article, bool isBookmarked) {
    final key = article.articleId ?? article.title;

    // Update in articles list
    final articleIndex = _articles.indexWhere(
      (a) => (a.articleId ?? a.title) == key,
    );
    if (articleIndex != -1) {
      _articles[articleIndex] = _articles[articleIndex].copyWith(
        isBookmarked: isBookmarked,
        bookmarkedAt: isBookmarked ? DateTime.now() : null,
      );
    }

    // Update in breaking news list
    final breakingIndex = _breakingNews.indexWhere(
      (a) => (a.articleId ?? a.title) == key,
    );
    if (breakingIndex != -1) {
      _breakingNews[breakingIndex] = _breakingNews[breakingIndex].copyWith(
        isBookmarked: isBookmarked,
        bookmarkedAt: isBookmarked ? DateTime.now() : null,
      );
    }
  }

  /// Refresh current view
  Future<void> refresh() async {
    if (_currentQuery != null) {
      await searchNews(_currentQuery!, refresh: true);
    } else if (_currentCategory != null) {
      await fetchNewsByCategory(_currentCategory!, refresh: true);
    } else {
      await fetchBreakingNews();
    }
  }

  /// Fetch news for a specific date (archive)
  /// date: The date to fetch news for (defaults to today if null)
  Future<void> fetchNewsByDate(DateTime? date) async {
    try {
      _isLoadingToday = true;
      _error = null;
      _selectedDate = date ?? DateTime.now();
      notifyListeners();

      // Format date as YYYY-MM-DD
      final fromDate = _formatDate(_selectedDate!);
      final toDate = fromDate; // Same date for single day

      final response = await _repository.fetchArchiveNews(
        fromDate: fromDate,
        toDate: toDate,
        language: 'en', // You can make this dynamic
      );

      _todayNews = response.results;
      _isLoadingToday = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoadingToday = false;
      notifyListeners();
    }
  }

  /// Format DateTime to YYYY-MM-DD string
  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _repository.dispose();
    super.dispose();
  }
}
