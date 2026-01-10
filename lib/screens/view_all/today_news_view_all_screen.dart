import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/news_provider.dart';
import '../../providers/bookmark_provider.dart';
import '../../providers/language_provider.dart';
import '../../widgets/news_grid_views.dart';
import '../../data/models/news_article.dart';
import '../news_detail/news_detail_screen.dart';
import '../../providers/audio_player_provider.dart';
import '../../core/widgets/audio_mini_player.dart';
import '../../screens/home/tabs/news_feed_tab_new.dart' as news_feed;

/// View All screen for Today's News with pagination
class TodayNewsViewAllScreen extends StatefulWidget {
  final DateTime? selectedDate;

  const TodayNewsViewAllScreen({super.key, this.selectedDate});

  @override
  State<TodayNewsViewAllScreen> createState() => _TodayNewsViewAllScreenState();
}

class _TodayNewsViewAllScreenState extends State<TodayNewsViewAllScreen> {
  final ScrollController _scrollController = ScrollController();
  int _currentPage = 1;
  bool _isLoadingMore = false;
  bool _hasMorePages = true;
  final int _limit = 50;
  List<NewsArticle> _allTodayNews = [];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // Fetch first page with limit 50
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTodayNews(page: 1);
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.9) {
      if (!_isLoadingMore && _hasMorePages) {
        _loadMoreNews();
      }
    }
  }

  Future<void> _loadTodayNews({required int page, bool isRefresh = false}) async {
    final newsProvider = context.read<NewsProvider>();
    final languageProvider = context.read<LanguageProvider>();
    final language = languageProvider.getApiLanguageCode();
    final date = widget.selectedDate ?? DateTime.now();
    final dateString = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    try {
      if (page == 1 || isRefresh) {
        // First page or refresh - show loading and clear previous data
        setState(() {
          _isLoadingMore = true;
          if (isRefresh) {
            _allTodayNews = [];
            _currentPage = 1;
            _hasMorePages = true;
          }
        });
      } else {
        setState(() {
          _isLoadingMore = true;
        });
      }

      // Fetch using repository directly for pagination
      final response = await newsProvider.repository.fetchTodayNews(
        date: dateString,
        language: language,
        limit: _limit,
        page: page,
      );

      setState(() {
        if (page == 1 || isRefresh) {
          _allTodayNews = response.results;
        } else {
          _allTodayNews.addAll(response.results);
        }
        _currentPage = page;
        _hasMorePages = response.results.length == _limit; // If we got full page, might have more
        _isLoadingMore = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingMore = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading news: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadMoreNews() async {
    if (_isLoadingMore || !_hasMorePages) return;
    await _loadTodayNews(page: _currentPage + 1);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final newsProvider = context.watch<NewsProvider>();
    final date = widget.selectedDate ?? DateTime.now();
    final dateString = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('News for $dateString'),
        backgroundColor: theme.scaffoldBackgroundColor,
      ),
      body: Stack(
        children: [
          _isLoadingMore && _allTodayNews.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _allTodayNews.isEmpty
              ? Center(
                  child: Text(
                    'No news available for this date',
                    style: TextStyle(color: theme.colorScheme.secondary),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => _loadTodayNews(page: 1, isRefresh: true),
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _allTodayNews.length + (_isLoadingMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _allTodayNews.length) {
                        return const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }

                      final article = _allTodayNews[index];
                      return NewsGridView(
                        key: ValueKey('today_${article.articleId ?? index}'),
                        type: 'listview',
                        newsDetails: article,
                        onListenTapped: () async {
                          try {
                            // Find the index of current article in the list
                            final startIndex = _allTodayNews.indexWhere(
                              (a) => (a.articleId ?? a.title) == (article.articleId ?? article.title),
                            );
                            
                            if (startIndex >= 0 && startIndex < _allTodayNews.length) {
                              // Set playlist with all today's news and start from clicked article
                              await context.read<AudioPlayerProvider>().setPlaylistAndPlay(
                                _allTodayNews,
                                startIndex,
                                playTitle: true,
                              );
                            } else {
                              // Fallback: play single article
                              await context.read<AudioPlayerProvider>().playArticleFromUrl(article, playTitle: true);
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
                            final newStatus = await bookmarkProvider.toggleBookmark(article);
                            
                            // Update article status in NewsProvider lists
                            newsProvider.updateArticleBookmarkStatus(article, newStatus);

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
                              return news_feed.showShareModalBottomSheet(context);
                            },
                          );
                        },
                      );
                    },
                  ),
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
}

