import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/news_provider.dart';
import '../../providers/bookmark_provider.dart';
import '../../providers/tts_provider.dart';
import '../../core/widgets/app_drawer.dart';
import '../home/tabs/news_feed_tab_new.dart';
import '../categories/categories_tab.dart';
import '../bookmarks/bookmarks_tab.dart';
import '../search/search_tab.dart';

/// Main home screen with bottom navigation
class HomeScreen extends StatefulWidget {
  final List<String> selectedCategories;

  const HomeScreen({
    super.key,
    required this.selectedCategories,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  late List<Widget> _tabs;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _tabs = [
      NewsFeedTabNew(selectedCategories: widget.selectedCategories),
      const CategoriesTab(),
      const BookmarksTab(),
      const SearchTab(),
    ];

    // Load initial data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NewsProvider>().fetchBreakingNews();
      context.read<BookmarkProvider>().loadBookmarks();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ttsProvider = Provider.of<TtsProvider>(context);

    return Scaffold(
      key: _scaffoldKey,
      drawer: AppDrawer(
        onNavigate: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
      body: Stack(
        children: [
          // Main content
          IndexedStack(
            index: _currentIndex,
            children: _tabs,
          ),

          // TTS Control Bar (when playing)
          if (ttsProvider.isPlaying || ttsProvider.isPaused)
            Positioned(
              left: 0,
              right: 0,
              bottom: 80,
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(
                      ttsProvider.isPlaying ? Icons.volume_up : Icons.volume_off,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Now Playing',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            ttsProvider.currentArticle?.title ?? '',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        ttsProvider.isPlaying ? Icons.pause : Icons.play_arrow,
                        color: Colors.white,
                      ),
                      onPressed: () {
                        ttsProvider.togglePlayPause();
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () {
                        ttsProvider.stop();
                      },
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: theme.brightness == Brightness.dark ? Colors.grey[900] : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildBottomNavItem(
                  Icons.menu,
                  'Menu',
                  onTap: () {
                    _scaffoldKey.currentState?.openDrawer();
                  },
                ),
                _buildBottomNavItem(
                  Icons.home,
                  'Today',
                  onTap: () {
                    setState(() {
                      _currentIndex = 0;
                    });
                  },
                  isSelected: _currentIndex == 0,
                ),
                _buildBottomNavItem(
                  Icons.search,
                  'Search',
                  onTap: () {
                    setState(() {
                      _currentIndex = 3;
                    });
                  },
                  isSelected: _currentIndex == 3,
                ),
                _buildBottomNavItem(
                  Icons.bookmark_border,
                  'Saved',
                  onTap: () {
                    setState(() {
                      _currentIndex = 2;
                    });
                  },
                  isSelected: _currentIndex == 2,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavItem(
    IconData icon,
    String label, {
    required VoidCallback onTap,
    bool isSelected = false,
  }) {
    final selectedColor = const Color(0xFFE31E24);
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? selectedColor : Colors.grey[600],
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? selectedColor : Colors.grey[600],
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
