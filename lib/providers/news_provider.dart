import 'package:flutter/foundation.dart';
import '../data/models/news_article.dart';
import '../data/models/news_response.dart';
import '../data/repositories/news_repository.dart';
import '../data/services/storage_service.dart';
import 'language_provider.dart';

/// Provider for managing news state
class NewsProvider with ChangeNotifier {
  final NewsRepository _repository;
  LanguageProvider? _languageProvider;
  String _currentLanguageCode = 'ta'; // Default to Tamil

  NewsProvider({NewsRepository? repository, LanguageProvider? languageProvider})
    : _repository = repository ?? NewsRepository(apiKey: ""),
      _languageProvider = languageProvider {
    // Listen to language changes if provider is available
    _languageProvider?.addListener(_onLanguageChanged);
    if (_languageProvider != null) {
      _currentLanguageCode = _languageProvider!.getApiLanguageCode();
      debugPrint(
        '📰 NewsProvider initialized with language: $_currentLanguageCode',
      );
    } else {
      debugPrint(
        '⚠️ NewsProvider initialized without LanguageProvider - language will be set later',
      );
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
        debugPrint(
          '🔄 Language changed to: $_currentLanguageCode - Refreshing ALL news sections...',
        );
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

      debugPrint(
        '✅ All news sections refreshed with language: $_currentLanguageCode',
      );
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

  // Get repository for direct access (needed for View All pages with pagination)
  NewsRepository get repository => _repository;

  /// Fetch breaking/top news
  /// [limit] - Number of items to fetch (default: 10 for home page, 50 for View All)
  /// [page] - Page number for pagination (default: 1)
  Future<void> fetchBreakingNews({int limit = 10, int page = 1}) async {
    try {
      _isLoading = true;
      _error = null;

      // Step 1: Load from cache first (for instant offline display)
      if (page == 1) {
        final cachedNews = StorageService.getBreakingNewsCache();
        if (cachedNews.isNotEmpty) {
          _breakingNews = cachedNews;
          _isLoading = false;
          notifyListeners(); // Show cached data immediately
          debugPrint("📦 Loaded ${cachedNews.length} breaking news from cache");
        }
      }

      // Update language code from provider if available
      if (_languageProvider != null) {
        _currentLanguageCode = _languageProvider!.getApiLanguageCode();
      }

      // Step 2: Try to fetch fresh data from API
      try {
        final response = await _repository.fetchBreakingNews(
          language: _currentLanguageCode,
          limit: limit,
          page: page,
        );

        if (response.results.isNotEmpty) {
          debugPrint("First article title: ${response.results.first.title}");
        }

        _breakingNews = response.results;
        _isLoading = false;
        debugPrint("✅ Breaking news fetched: ${_breakingNews.length} articles");
        notifyListeners();
      } catch (apiError) {
        // If API fails and we have cached data, keep using it
        if (_breakingNews.isNotEmpty) {
          debugPrint(
            "⚠️ API fetch failed, using cached breaking news: $apiError",
          );
          _isLoading = false;
          _error = null; // Don't show error if we have cached data
          notifyListeners();
        } else {
          // No cached data, show error
          rethrow;
        }
      }
    } catch (e, stackTrace) {
      debugPrint("❌ Error fetching breaking news: $e");
      debugPrint("Stack trace: $stackTrace");
      _error = e.toString();
      _isLoading = false;
      if (_breakingNews.isEmpty) {
        _breakingNews = [];
      }
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

      // Step 1: Load from cache first (for instant offline display)
      if (refresh || _articles.isEmpty) {
        final cachedArticles = StorageService.getArticlesCache();
        if (cachedArticles.isNotEmpty) {
          _articles = cachedArticles;
          _isLoading = false;
          notifyListeners(); // Show cached data immediately
          debugPrint("📦 Loaded ${cachedArticles.length} articles from cache");
        }
      }

      notifyListeners();

      // Update language code from provider if available
      if (_languageProvider != null) {
        _currentLanguageCode = _languageProvider!.getApiLanguageCode();
      }

      // Step 2: Try to fetch fresh data from API
      try {
        final response = await _repository.fetchNewsByCategory(
          category,
          language: _currentLanguageCode,
        );
        _articles = response.results;
        _nextPage = response.nextPage;
        _isLoading = false;
        debugPrint("✅ Category news fetched: ${_articles.length} articles");
        notifyListeners();
      } catch (apiError) {
        // If API fails and we have cached data, keep using it
        if (_articles.isNotEmpty) {
          debugPrint("⚠️ API fetch failed, using cached articles: $apiError");
          _isLoading = false;
          _error = null; // Don't show error if we have cached data
          notifyListeners();
        } else {
          // No cached data, show error
          rethrow;
        }
      }
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      if (_articles.isEmpty) {
        _articles = [];
      }
      notifyListeners();
    }
  }

  /// Load more news (pagination) - Updated to use page-based pagination
  /// This method is kept for backward compatibility but now uses page numbers
  Future<void> loadMoreNews() async {
    if (_isLoadingMore) return;

    try {
      _isLoadingMore = true;
      notifyListeners();

      // Calculate next page based on current articles length
      final currentPage = (_articles.length / 50).ceil() + 1;

      // Update language code from provider if available
      if (_languageProvider != null) {
        _currentLanguageCode = _languageProvider!.getApiLanguageCode();
      }

      NewsResponse response;

      if (_currentQuery != null) {
        response = await _repository.searchNews(
          _currentQuery!,
          language: _currentLanguageCode,
          limit: 50,
          page: currentPage,
        );
      } else if (_currentCategory != null) {
        response = await _repository.fetchNewsByCategory(
          _currentCategory!,
          language: _currentLanguageCode,
          limit: 50,
          page: currentPage,
        );
      } else {
        response = await _repository.fetchBreakingNews(
          language: _currentLanguageCode,
          limit: 50,
          page: currentPage,
        );
      }

      _articles.addAll(response.results);
      _nextPage = response.nextPage; // Keep for backward compatibility
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

      // Step 1: Load from cache first (for instant offline display)
      if (refresh || _articles.isEmpty) {
        final cachedArticles = StorageService.getArticlesCache();
        if (cachedArticles.isNotEmpty) {
          _articles = cachedArticles;
          _isLoading = false;
          notifyListeners(); // Show cached data immediately
          debugPrint(
            "📦 Loaded ${cachedArticles.length} search results from cache",
          );
        }
      }

      notifyListeners();

      // Update language code from provider if available
      if (_languageProvider != null) {
        _currentLanguageCode = _languageProvider!.getApiLanguageCode();
      }

      // Step 2: Try to fetch fresh data from API
      try {
        final response = await _repository.searchNews(
          query,
          language: _currentLanguageCode,
        );
        _articles = response.results;
        _nextPage = response.nextPage;
        _isLoading = false;
        debugPrint("✅ Search results fetched: ${_articles.length} articles");
        notifyListeners();
      } catch (apiError) {
        // If API fails and we have cached data, keep using it
        if (_articles.isNotEmpty) {
          debugPrint(
            "⚠️ API fetch failed, using cached search results: $apiError",
          );
          _isLoading = false;
          _error = null; // Don't show error if we have cached data
          notifyListeners();
        } else {
          // No cached data, show error
          rethrow;
        }
      }
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      if (_articles.isEmpty) {
        _articles = [];
      }
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
  /// Toggle bookmark - delegates to BookmarkProvider for API sync
  /// Note: This method should be called from UI, but UI should primarily use BookmarkProvider directly
  /// This is kept for backward compatibility
  Future<bool> toggleBookmark(NewsArticle article) async {
    try {
      // Use local storage for now (backward compatibility)
      // For full API sync, use BookmarkProvider.toggleBookmark from UI
      final isBookmarked = await _repository.toggleBookmark(article);

      // Update article in lists to reflect bookmark status
      _updateArticleInLists(article, isBookmarked);

      notifyListeners();
      return isBookmarked;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Update article bookmark status in lists (called by BookmarkProvider after API sync)
  void updateArticleBookmarkStatus(NewsArticle article, bool isBookmarked) {
    _updateArticleInLists(article, isBookmarked);
    notifyListeners();
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

  /// Refresh all news sections (called when network comes online)
  Future<void> refreshAllNews() async {
    try {
      debugPrint('🔄 Refreshing all news sections...');
      // Refresh breaking news
      await fetchBreakingNews();
      // Refresh today's news
      if (_selectedDate != null) {
        await fetchNewsByDate(_selectedDate);
      } else {
        await fetchNewsByDate(DateTime.now());
      }
      debugPrint('✅ All news sections refreshed');
    } catch (e) {
      debugPrint('⚠️ Error refreshing all news: $e');
    }
  }

  /// Fetch news for a specific date (archive)
  /// [date] - The date to fetch news for (defaults to today if null)
  /// [limit] - Number of items to fetch (default: 5 for home page, 50 for View All)
  /// [page] - Page number for pagination (default: 1)
  Future<void> fetchNewsByDate(
    DateTime? date, {
    int limit = 5,
    int page = 1,
  }) async {
    try {
      _isLoadingToday = true;
      _error = null;
      _selectedDate = date ?? DateTime.now();

      // Step 1: Load from cache first (for instant offline display)
      if (page == 1) {
        final cachedNews = StorageService.getTodayNewsCache();
        if (cachedNews.isNotEmpty) {
          _todayNews = cachedNews;
          _isLoadingToday = false;
          notifyListeners(); // Show cached data immediately
          debugPrint("📦 Loaded ${cachedNews.length} today news from cache");
        }
      }

      notifyListeners();

      // Format date as YYYY-MM-DD
      final dateString = _formatDate(_selectedDate!);

      // Update language code from provider if available
      if (_languageProvider != null) {
        _currentLanguageCode = _languageProvider!.getApiLanguageCode();
      }

      // Step 2: Try to fetch fresh data from API
      try {
        final response = await _repository.fetchTodayNews(
          date: dateString,
          language: _currentLanguageCode,
          limit: limit,
          page: page,
        );

        _todayNews = response.results;
        _isLoadingToday = false;
        debugPrint("✅ Today news fetched: ${_todayNews.length} articles");
        notifyListeners();
      } catch (apiError) {
        // If API fails and we have cached data, keep using it
        if (_todayNews.isNotEmpty) {
          debugPrint("⚠️ API fetch failed, using cached today news: $apiError");
          _isLoadingToday = false;
          _error = null; // Don't show error if we have cached data
          notifyListeners();
        } else {
          // No cached data, show error
          rethrow;
        }
      }
    } catch (e) {
      _error = e.toString();
      _isLoadingToday = false;
      if (_todayNews.isEmpty) {
        _todayNews = [];
      }
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
