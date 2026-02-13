import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/news_provider.dart';
import '../../providers/bookmark_provider.dart';
import '../../providers/language_provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/localization_helper.dart';
import '../../core/widgets/loading_shimmer.dart';
import '../../core/widgets/audio_mini_player.dart';
import '../../data/models/remote_config_model.dart';
import '../../providers/remote_config_provider.dart';
import '../../widgets/news_grid_views.dart';
import '../../providers/audio_player_provider.dart';
import '../home/tabs/news_feed_tab_new.dart';
import '../news_detail/news_detail_screen.dart';
import '../../core/services/voice_search_service.dart';

/// Search tab - Search for news articles
class SearchTab extends StatefulWidget {
  const SearchTab({super.key});

  @override
  State<SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends State<SearchTab>
    with AutomaticKeepAliveClientMixin {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<String> _recentSearches = [];
  Timer? _debounceTimer;

  // Voice search
  final VoiceSearchService _voiceSearchService = VoiceSearchService();
  bool _isVoiceSearchInitialized = false;
  bool _isListening = false;
  String _voiceSearchText = '';
  String _voiceSearchError = '';
  VoiceSearchLanguage? _currentVoiceLanguage;

  @override
  void initState() {
    super.initState();
    // Listen to scroll for pagination
    _scrollController.addListener(_onScroll);
    // Initialize voice search
    _initializeVoiceSearch();
    // Listen for language changes
    context.read<LanguageProvider>().addListener(_onLanguageChanged);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    _voiceSearchService.dispose();
    context.read<LanguageProvider>().removeListener(_onLanguageChanged);
    super.dispose();
  }

  /// Handle language changes
  void _onLanguageChanged() {
    final languageProvider = context.read<LanguageProvider>();
    final currentLocale = languageProvider.locale;

    // Update voice search language based on app language
    final voiceLanguage = _getVoiceSearchLanguage(currentLocale);
    if (voiceLanguage != _currentVoiceLanguage) {
      _updateVoiceSearchLanguage(voiceLanguage);
    }
  }

  /// Convert app locale to voice search language
  VoiceSearchLanguage _getVoiceSearchLanguage(Locale appLocale) {
    // Always use English for voice search
    return VoiceSearchLanguage.english;
  }

  /// Update voice search language
  Future<void> _updateVoiceSearchLanguage(VoiceSearchLanguage language) async {
    print("🌐 Updating voice search language to: ${language.displayName}");

    if (_isVoiceSearchInitialized) {
      final success = await _voiceSearchService.setLanguage(language);
      if (success) {
        _currentVoiceLanguage = language;
        print("✅ Voice search language updated to: ${language.displayName}");
      } else {
        print(
            "❌ Failed to update voice search language to: ${language.displayName}");
      }
    } else {
      _currentVoiceLanguage = language;
      print(
          "📝 Voice search language set (will be applied on initialization): ${language.displayName}");
    }
  }

  /// Initialize voice search service with current app language
  Future<void> _initializeVoiceSearch() async {
    try {
      // Get current app language
      final languageProvider = context.read<LanguageProvider>();
      final currentLocale = languageProvider.locale;
      final voiceLanguage = _getVoiceSearchLanguage(currentLocale);

      print(
          "🌐 Initializing voice search with language: ${voiceLanguage.displayName}");

      // Initialize voice search with current language
      final success =
          await _voiceSearchService.initialize(language: voiceLanguage);

      if (success) {
        _currentVoiceLanguage = voiceLanguage;
        print(
            "✅ Voice search initialized successfully in ${voiceLanguage.displayName}");
      } else {
        print(
            "❌ Voice search initialization failed: ${_voiceSearchService.errorText}");
      }

      setState(() {
        _isVoiceSearchInitialized = success;
        if (!success) {
          _voiceSearchError = _voiceSearchService.errorText;
        }
      });
    } catch (e) {
      setState(() {
        _voiceSearchError = 'Voice search initialization failed: $e';
      });
      print("❌ Voice search initialization error: $e");
    }
  }

  /// Start voice search with enhanced behavior and multilingual support
  Future<void> _startVoiceSearch() async {
    if (!_isVoiceSearchInitialized) {
      await _initializeVoiceSearch();
      if (!_isVoiceSearchInitialized) return;
    }

    if (_isListening) {
      await _stopVoiceSearch();
      return;
    }

    setState(() {
      _isListening = true;
      _voiceSearchText = '';
      _voiceSearchError = '';
    });

    // Ensure voice search language matches current app language
    final languageProvider = context.read<LanguageProvider>();
    final currentLocale = languageProvider.locale;
    final currentVoiceLanguage = _getVoiceSearchLanguage(currentLocale);

    if (_currentVoiceLanguage != currentVoiceLanguage) {
      await _updateVoiceSearchLanguage(currentVoiceLanguage);
    }

    print(
        "🎤 Starting voice search in ${currentVoiceLanguage.displayName} language");

    // Enhanced voice search with better parameters
    final success = await _voiceSearchService.startListening(
      language: currentVoiceLanguage,
      silenceTimeout: const Duration(seconds: 4), // 4 seconds silence timeout
      maxListeningDuration:
          const Duration(seconds: 25), // 25 seconds max duration
      onResult: (result) {
        print(
            "🎤 Voice result received in ${currentVoiceLanguage.displayName}: '$result'");
        setState(() {
          _voiceSearchText = result;
        });

        // Show real-time feedback for longer speech
        if (result.length > 10) {
          print(
              "🎤 Captured in ${currentVoiceLanguage.displayName}: '$result'");
        }
      },
      onError: (error) {
        print(
            "❌ Voice search error in ${currentVoiceLanguage.displayName}: $error");
        setState(() {
          _voiceSearchError = _getErrorMessage(error, currentVoiceLanguage);
          _isListening = false;
        });
      },
      onListeningStart: () {
        print(
            "🎤 Voice search started in ${currentVoiceLanguage.displayName} - listening for speech...");
        setState(() {
          _isListening = true;
        });
      },
      onListeningEnd: () {
        print(
            "🔇 Voice search ended in ${currentVoiceLanguage.displayName} - processing: '$_voiceSearchText'");
        setState(() {
          _isListening = false;
        });

        // Process the recognized text
        _processVoiceSearchResult(currentVoiceLanguage);
      },
    );

    if (!success) {
      setState(() {
        _isListening = false;
        _voiceSearchError = _getErrorMessage(_voiceSearchService.errorText, currentVoiceLanguage);
      });
    }
  }

  /// Process voice search result with simplified handling
  void _processVoiceSearchResult(VoiceSearchLanguage language) {
    final recognizedText = _voiceSearchText.trim();

    if (recognizedText.isEmpty) {
      print("❌ No speech detected");
      setState(() {
        _voiceSearchError = "No speech detected. Please try again.";
        _voiceSearchText = '';
      });
      return;
    }

    // Filter out common speech recognition errors
    if (_isLikelySpeechError(recognizedText)) {
      print("❌ Likely speech error: '$recognizedText'");
      setState(() {
        _voiceSearchError = "Speech not clear. Please try again.";
        _voiceSearchText = '';
      });
      return;
    }

    // Clean and normalize the recognized text
    final cleanedText = _cleanRecognizedText(recognizedText);
    print("🔧 Text cleaned: '$cleanedText'");

    // Update search field with cleaned text
    setState(() {
      _searchController.text = cleanedText;
    });
    print("📝 Search controller updated to: '${_searchController.text}'");

    // Execute search with cleaned text
    _performSearch(cleanedText, immediate: true);

    // Clear voice search state
    setState(() {
      _voiceSearchText = '';
      _voiceSearchError = '';
    });

    print("✅ Voice search completed successfully");
  }

  /// Check if recognized text is likely a speech recognition error
  bool _isLikelySpeechError(String text) {
    final lowerText = text.toLowerCase();

    // Common speech recognition artifacts
    final errorPatterns = [
      'um',
      'uh',
      'er',
      'ah',
      'mm',
      'hmm',
      'the the',
      'and and',
      'but but',
      '...',
      '???',
      '???',
      'unknown',
      'unrecognized',
      'error',
    ];

    // Check for very short or repetitive patterns
    if (text.length < 2) return true;
    if (errorPatterns.any((pattern) => lowerText.contains(pattern)))
      return true;

    // Check for too many repeated characters
    final repeatedPattern = RegExp(r'(.)\1{3,}');
    if (repeatedPattern.hasMatch(text)) return true;

    return false;
  }

  /// Clean and normalize recognized text
  String _cleanRecognizedText(String text) {
    String cleaned = text.trim();

    // Remove leading articles for better search results
    if (cleaned.toLowerCase().startsWith('the ')) {
      cleaned = cleaned.substring(4);
    } else if (cleaned.toLowerCase().startsWith('a ')) {
      cleaned = cleaned.substring(2);
    } else if (cleaned.toLowerCase().startsWith('an ')) {
      cleaned = cleaned.substring(3);
    }

    // Remove extra spaces and normalize
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();

    // Capitalize first letter for better display
    if (cleaned.isNotEmpty) {
      cleaned = cleaned[0].toUpperCase() + cleaned.substring(1);
    }

    return cleaned;
  }

  /// Get user-friendly error message with language context
  String _getErrorMessage(String error, VoiceSearchLanguage language) {
    final lowerError = error.toLowerCase();

    if (lowerError.contains('no speech')) {
      return "No speech detected. Please speak clearly in ${language.displayName}.";
    } else if (lowerError.contains('network') ||
        lowerError.contains('connection')) {
      return "Network error. Please check your connection.";
    } else if (lowerError.contains('permission')) {
      return "Microphone permission required.";
    } else if (lowerError.contains('timeout')) {
      return "Listening timeout. Please try again.";
    } else {
      return "Voice search error in ${language.displayName}. Please try again.";
    }
  }

  /// Stop voice search
  Future<void> _stopVoiceSearch() async {
    await _voiceSearchService.stopListening();
    setState(() {
      _isListening = false;
    });
  }

  /// Cancel voice search
  Future<void> _cancelVoiceSearch() async {
    await _voiceSearchService.cancelListening();
    setState(() {
      _isListening = false;
      _voiceSearchText = '';
      _voiceSearchError = '';
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
      // Load more when 80% scrolled
      final newsProvider = context.read<NewsProvider>();
      if (newsProvider.hasNextPage && !newsProvider.isLoadingMore) {
        newsProvider.loadMoreNews();
      }
    }
  }

  void _performSearch(String query, {bool immediate = false}) {
    print("_performSearch called with query: '$query', immediate: $immediate");
    final trimmedQuery = query.trim();

    if (trimmedQuery.isEmpty) {
      print("Query is empty, clearing search");
      context.read<NewsProvider>().clearSearch();
      return;
    }

    // Cancel previous timer
    _debounceTimer?.cancel();

    if (immediate) {
      print("Executing immediate search for: '$trimmedQuery'");
      _executeSearch(trimmedQuery);
    } else {
      print("Debouncing search for: '$trimmedQuery'");
      // Debounce search - wait 500ms after user stops typing
      _debounceTimer = Timer(const Duration(milliseconds: 500), () {
        _executeSearch(trimmedQuery);
      });
    }
  }

  void _executeSearch(String query) {
    print("Executing search for query: '$query'");

    // Add to recent searches
    if (!_recentSearches.contains(query)) {
      setState(() {
        _recentSearches.insert(0, query);
        if (_recentSearches.length > 10) {
          _recentSearches.removeLast();
        }
      });
    }

    // Perform search
    print("Calling NewsProvider.searchNews with query: '$query'");
    context.read<NewsProvider>().searchNews(query, refresh: true);
    print("Search initiated successfully");

    // Clear voice search text after executing search
    setState(() {
      _voiceSearchText = '';
      _voiceSearchError = '';
    });
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final newsProvider = context.watch<NewsProvider>();
    final remoteConfig = context.read<RemoteConfigProvider>().config;

    return Scaffold(
      appBar: AppBar(
        title: Text(LocalizationHelper.search(context)),
        elevation: 0,
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Search bar
              Container(
                padding: const EdgeInsets.all(AppConstants.defaultPadding),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Search input field
                    TextField(
                      controller: _searchController,
                      autofocus: false,
                      decoration: InputDecoration(
                        hintText: 'Search news...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Voice search button
                            if (_isVoiceSearchInitialized)
                              IconButton(
                                icon: _isListening
                                    ? Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.stop,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                      )
                                    : Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: remoteConfig.primaryColorValue,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.mic,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                      ),
                                onPressed: _startVoiceSearch,
                              ),
                            // Clear button
                            if (_searchController.text.isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                  context.read<NewsProvider>().clearSearch();
                                  setState(() {});
                                },
                              ),
                          ],
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppConstants.borderRadius,
                          ),
                        ),
                        filled: true,
                        fillColor: theme.colorScheme.surface,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      onSubmitted: (value) =>
                          _performSearch(value, immediate: true),
                      onChanged: (value) {
                        setState(() {});
                        if (value.trim().isNotEmpty) {
                          _performSearch(value);
                        } else {
                          context.read<NewsProvider>().clearSearch();
                        }
                      },
                    ),

                    // Voice search status with enhanced feedback
                    if (_isListening ||
                        _voiceSearchText.isNotEmpty ||
                        _voiceSearchError.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _isListening
                              ? Colors.red.withOpacity(0.1)
                              : _voiceSearchError.isNotEmpty
                                  ? Colors.red.withOpacity(0.1)
                                  : remoteConfig.primaryColorValue
                                      .withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _isListening
                                ? Colors.red
                                : _voiceSearchError.isNotEmpty
                                    ? Colors.red
                                    : remoteConfig.primaryColorValue,
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                // Animated microphone icon
                                if (_isListening)
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 500),
                                    child: Icon(
                                      Icons.mic,
                                      size: 16,
                                      color: Colors.red,
                                    ),
                                  )
                                else
                                  Icon(
                                    _voiceSearchError.isNotEmpty
                                        ? Icons.error_outline
                                        : Icons.check_circle_outline,
                                    size: 16,
                                    color: _voiceSearchError.isNotEmpty
                                        ? Colors.red
                                        : remoteConfig.primaryColorValue,
                                  ),
                                const SizedBox(width: 8),
                                Text(
                                  _isListening
                                      ? 'Listening... Speak clearly'
                                      : _voiceSearchError.isNotEmpty
                                          ? 'Voice Search Issue'
                                          : 'Voice Search Complete',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: _isListening
                                        ? Colors.red
                                        : _voiceSearchError.isNotEmpty
                                            ? Colors.red
                                            : remoteConfig.primaryColorValue,
                                  ),
                                ),
                                const Spacer(),
                                if (_isListening)
                                  GestureDetector(
                                    onTap: _cancelVoiceSearch,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.red.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Icon(
                                        Icons.close,
                                        size: 14,
                                        color: Colors.red,
                                      ),
                                    ),
                                  ),
                              ],
                            ),

                            // Real-time voice text display
                            if (_voiceSearchText.isNotEmpty)
                              Container(
                                margin: const EdgeInsets.only(top: 8),
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surface,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: remoteConfig.primaryColorValue
                                        .withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Recognized:',
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        color: theme.textTheme.bodySmall?.color
                                            ?.withOpacity(0.7),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _voiceSearchText,
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: theme.textTheme.bodyLarge?.color,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                            // Error message display
                            if (_voiceSearchError.isNotEmpty)
                              Container(
                                margin: const EdgeInsets.only(top: 8),
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: Colors.red.withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.info_outline,
                                      size: 14,
                                      color: Colors.red,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        _voiceSearchError,
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          color: Colors.red,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                            // Listening tips
                            if (_isListening)
                              Container(
                                margin: const EdgeInsets.only(top: 8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Tips for best results:',
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: theme.textTheme.bodySmall?.color
                                            ?.withOpacity(0.7),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    ...[
                                      '• Speak clearly and naturally',
                                      '• Avoid background noise',
                                      '• Pause briefly between phrases',
                                      '• Say complete search terms',
                                    ].map((tip) => Padding(
                                          padding:
                                              const EdgeInsets.only(top: 2),
                                          child: Text(
                                            tip,
                                            style: GoogleFonts.inter(
                                              fontSize: 9,
                                              color: theme
                                                  .textTheme.bodySmall?.color
                                                  ?.withOpacity(0.6),
                                            ),
                                          ),
                                        )),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

              // Content area
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    if (newsProvider.currentQuery != null) {
                      await newsProvider.searchNews(
                        newsProvider.currentQuery!,
                        refresh: true,
                      );
                    }
                  },
                  child: newsProvider.currentQuery == null
                      ? _buildRecentSearches(theme, remoteConfig)
                      : newsProvider.isLoading && newsProvider.articles.isEmpty
                          ? const LoadingShimmer()
                          : newsProvider.error != null
                              ? _buildError(theme, newsProvider, remoteConfig)
                              : newsProvider.articles.isEmpty
                                  ? _buildNoResults(theme, remoteConfig)
                                  : _buildSearchResults(
                                      newsProvider,
                                      theme,
                                      remoteConfig,
                                    ),
                ),
              ),
            ],
          ),
          // Audio Mini Player (Spotify-like)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: const AudioMiniPlayer(),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentSearches(ThemeData theme, RemoteConfigModel config) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_recentSearches.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.all(AppConstants.defaultPadding),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Searches',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _recentSearches.clear();
                    });
                  },
                  child: Text(
                    'Clear',
                    style: TextStyle(color: config.primaryColorValue),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _recentSearches.length,
              itemBuilder: (context, index) {
                final query = _recentSearches[index];
                return ListTile(
                  leading: Icon(Icons.history, color: config.primaryColorValue),
                  title: Text(query),
                  trailing: IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () {
                      setState(() {
                        _recentSearches.removeAt(index);
                      });
                    },
                  ),
                  onTap: () {
                    _searchController.text = query;
                    _performSearch(query, immediate: true);
                  },
                );
              },
            ),
          ),
        ] else
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.search,
                    size: 64,
                    color: theme.primaryColor.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    LocalizationHelper.search(context),
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Enter keywords to find articles',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                  if (_isVoiceSearchInitialized) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Or try voice search using the microphone',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: config.primaryColorValue,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildError(
    ThemeData theme,
    NewsProvider newsProvider,
    RemoteConfigModel config,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(
              'Error',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              newsProvider.error ?? 'An error occurred',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                if (newsProvider.currentQuery != null) {
                  newsProvider.searchNews(
                    newsProvider.currentQuery!,
                    refresh: true,
                  );
                }
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: config.primaryColorValue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoResults(ThemeData theme, RemoteConfigModel config) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: theme.colorScheme.onSurface.withOpacity(0.4),
            ),
            const SizedBox(height: 16),
            Text(
              'No results found',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try different keywords or check your spelling',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults(
    NewsProvider newsProvider,
    ThemeData theme,
    RemoteConfigModel config,
  ) {
    return Column(
      children: [
        // Results header with count
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.defaultPadding,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(
              bottom: BorderSide(
                color: theme.colorScheme.onSurface.withOpacity(0.1),
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${newsProvider.articles.length} ${newsProvider.articles.length == 1 ? 'result' : 'results'}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
              if (newsProvider.currentQuery != null)
                Text(
                  'Search: "${newsProvider.currentQuery}"',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: config.primaryColorValue,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
        ),

        // Results list
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            itemCount: newsProvider.articles.length +
                (newsProvider.isLoadingMore ? 1 : 0),
            itemBuilder: (context, index) {
              // Show loading indicator at the end when loading more
              if (index == newsProvider.articles.length) {
                return const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final article = newsProvider.articles[index];
              return NewsGridView(
                key: ValueKey('today_${article.articleId ?? index}'),
                type: 'listview',
                newsDetails: article,
                onListenTapped: () async {
                  try {
                    final newsProvider = context.read<NewsProvider>();
                    final searchResults = newsProvider.articles;

                    // Find the index of current article in search results
                    final startIndex = searchResults.indexWhere(
                      (a) =>
                          (a.articleId ?? a.title) ==
                          (article.articleId ?? article.title),
                    );

                    if (startIndex >= 0 && startIndex < searchResults.length) {
                      // Set playlist with all search results and start from clicked article
                      await context
                          .read<AudioPlayerProvider>()
                          .setPlaylistAndPlay(
                            searchResults,
                            startIndex,
                            playTitle: true,
                          );
                    } else {
                      // Fallback: play single article
                      await context
                          .read<AudioPlayerProvider>()
                          .playArticleFromUrl(article, playTitle: true);
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error playing audio: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                onSaveTapped: () async {
                  try {
                    final bookmarkProvider = context.read<BookmarkProvider>();
                    final newStatus = await bookmarkProvider.toggleBookmark(
                      article,
                    );

                    // Update article status in NewsProvider lists
                    final newsProvider = context.read<NewsProvider>();
                    newsProvider.updateArticleBookmarkStatus(
                      article,
                      newStatus,
                    );

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            newStatus
                                ? 'Added to bookmarks'
                                : 'Removed from bookmarks',
                          ),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error: ${e.toString()}'),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  }
                },
                onNewsTapped: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => NewsDetailScreen(article: article),
                    ),
                  );
                },
                onShareTapped: () {
                  showModalBottomSheet(
                    context: context,
                    builder: (c) {
                      return showShareModalBottomSheet(context);
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
