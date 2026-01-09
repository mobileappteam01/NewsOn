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

/// View All screen for Breaking News with pagination
class BreakingNewsViewAllScreen extends StatefulWidget {
  const BreakingNewsViewAllScreen({super.key});

  @override
  State<BreakingNewsViewAllScreen> createState() => _BreakingNewsViewAllScreenState();
}

class _BreakingNewsViewAllScreenState extends State<BreakingNewsViewAllScreen> {
  final ScrollController _scrollController = ScrollController();
  int _currentPage = 1;
  bool _isLoadingMore = false;
  bool _hasMorePages = true;
  final int _limit = 50;
  List<NewsArticle> _allBreakingNews = [];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // Fetch first page with limit 50
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadBreakingNews(page: 1, isRefresh: false);
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

  Future<void> _loadBreakingNews({required int page, bool isRefresh = false}) async {
    final newsProvider = context.read<NewsProvider>();
    final languageProvider = context.read<LanguageProvider>();
    final language = languageProvider.getApiLanguageCode();

    try {
      if (page == 1 || isRefresh) {
        // First page or refresh - show loading and clear previous data
        setState(() {
          _isLoadingMore = true;
          if (isRefresh) {
            _allBreakingNews = [];
            _currentPage = 1;
            _hasMorePages = true;
          }
        });
      } else {
        setState(() {
          _isLoadingMore = true;
        });
      }

      // Fetch from repository directly with page and limit
      final response = await newsProvider.repository.fetchBreakingNews(
        language: language,
        limit: _limit,
        page: page,
      );

      setState(() {
        if (page == 1 || isRefresh) {
          _allBreakingNews = response.results;
        } else {
          _allBreakingNews.addAll(response.results);
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
    await _loadBreakingNews(page: _currentPage + 1);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final newsProvider = context.watch<NewsProvider>();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Breaking News'),
        backgroundColor: theme.scaffoldBackgroundColor,
      ),
      body: Stack(
        children: [
          _isLoadingMore && _allBreakingNews.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _allBreakingNews.isEmpty
              ? Center(
                  child: Text(
                    'No breaking news available',
                    style: TextStyle(color: theme.colorScheme.secondary),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => _loadBreakingNews(page: 1, isRefresh: true),
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _allBreakingNews.length + (_isLoadingMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _allBreakingNews.length) {
                        return const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }

                      final article = _allBreakingNews[index];
                      return NewsGridView(
                        key: ValueKey('breaking_${article.articleId ?? index}'),
                        type: 'listview',
                        newsDetails: article,
                        onListenTapped: () async {
                          try {
                            // Find the index of current article in the list
                            final startIndex = _allBreakingNews.indexWhere(
                              (a) => (a.articleId ?? a.title) == (article.articleId ?? article.title),
                            );
                            
                            if (startIndex >= 0 && startIndex < _allBreakingNews.length) {
                              // Set playlist with all breaking news and start from clicked article
                              await context.read<AudioPlayerProvider>().setPlaylistAndPlay(
                                _allBreakingNews,
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

