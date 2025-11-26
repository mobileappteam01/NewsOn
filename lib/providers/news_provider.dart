import 'package:flutter/foundation.dart';
import '../data/models/news_article.dart';
import '../data/models/news_response.dart';
import '../data/repositories/news_repository.dart';
import 'language_provider.dart';

/// Provider for managing news state
class NewsProvider with ChangeNotifier {
  final NewsRepository _repository;
  LanguageProvider? _languageProvider;
  String _currentLanguageCode = 'en'; // Default to English

  NewsProvider({NewsRepository? repository, LanguageProvider? languageProvider})
    : _repository = repository ?? NewsRepository(apiKey: ""),
      _languageProvider = languageProvider {
    // Listen to language changes if provider is available
    _languageProvider?.addListener(_onLanguageChanged);
    if (_languageProvider != null) {
      _currentLanguageCode = _languageProvider!.getApiLanguageCode();
      debugPrint('📰 NewsProvider initialized with language: $_currentLanguageCode');
    } else {
      debugPrint('⚠️ NewsProvider initialized without LanguageProvider - language will be set later');
    }
  }

  /// Set language provider and listen to changes
  void setLanguageProvider(LanguageProvider languageProvider) {
    _languageProvider?.removeListener(_onLanguageChanged);
    _languageProvider = languageProvider;
    _languageProvider?.addListener(_onLanguageChanged);
    _currentLanguageCode = languageProvider.getApiLanguageCode();
    debugPrint('📰 NewsProvider language set to: $_currentLanguageCode');
  }

  /// Called when language changes
  void _onLanguageChanged() {
    if (_languageProvider != null) {
      final newLanguageCode = _languageProvider!.getApiLanguageCode();
      if (newLanguageCode != _currentLanguageCode) {
        _currentLanguageCode = newLanguageCode;
        debugPrint('🔄 Language changed to: $_currentLanguageCode - Refreshing ALL news sections...');
        // Refresh ALL news sections with new language
        _refreshAllNewsSections();
      }
    }
  }

  /// Refresh all news sections when language changes
  Future<void> _refreshAllNewsSections() async {
    try {
      // Refresh breaking news (used in carousel and flash news)
      await fetchBreakingNews();
      
      // Refresh today's news if date is selected
      if (_selectedDate != null) {
        await fetchNewsByDate(_selectedDate);
      } else {
        // Refresh today's news with current date
        await fetchNewsByDate(DateTime.now());
      }
      
      // Refresh category/news articles if there's an active category or query
      if (_currentCategory != null) {
        await fetchNewsByCategory(_currentCategory!, refresh: true);
      } else if (_currentQuery != null) {
        await searchNews(_currentQuery!, refresh: true);
      }
      
      debugPrint('✅ All news sections refreshed with language: $_currentLanguageCode');
    } catch (e) {
      debugPrint('❌ Error refreshing all news sections: $e');
    }
  }

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
      _isLoading = true;
      _error = null;
      notifyListeners();

      // Update language code from provider if available
      if (_languageProvider != null) {
        _currentLanguageCode = _languageProvider!.getApiLanguageCode();
      }

      final response = await _repository.fetchBreakingNews(
        language: _currentLanguageCode,
      );

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

      // Update language code from provider if available
      if (_languageProvider != null) {
        _currentLanguageCode = _languageProvider!.getApiLanguageCode();
      }

      final response = await _repository.fetchNewsByCategory(
        category,
        language: _currentLanguageCode,
      );
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

      // Update language code from provider if available
      if (_languageProvider != null) {
        _currentLanguageCode = _languageProvider!.getApiLanguageCode();
      }

      if (_currentQuery != null) {
        response = await _repository.searchNews(
          _currentQuery!,
          language: _currentLanguageCode,
          nextPage: _nextPage,
        );
      } else if (_currentCategory != null) {
        response = await _repository.fetchNewsByCategory(
          _currentCategory!,
          language: _currentLanguageCode,
          nextPage: _nextPage,
        );
      } else {
        response = await _repository.fetchBreakingNews(
          language: _currentLanguageCode,
          nextPage: _nextPage,
        );
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

      // Update language code from provider if available
      if (_languageProvider != null) {
        _currentLanguageCode = _languageProvider!.getApiLanguageCode();
      }

      final response = await _repository.searchNews(
        query,
        language: _currentLanguageCode,
      );
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

      // Update language code from provider if available
      if (_languageProvider != null) {
        _currentLanguageCode = _languageProvider!.getApiLanguageCode();
      }

      final response = await _repository.fetchArchiveNews(
        fromDate: fromDate,
        toDate: toDate,
        language: _currentLanguageCode,
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
    _languageProvider?.removeListener(_onLanguageChanged);
    _repository.dispose();
    super.dispose();
  }
}
