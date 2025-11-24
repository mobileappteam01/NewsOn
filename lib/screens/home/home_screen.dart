// ignore_for_file: deprecated_member_use, unused_local_variable, use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:newson/core/utils/localization_helper.dart';
import 'package:newson/data/models/remote_config_model.dart';
import 'package:provider/provider.dart';
import '../../providers/news_provider.dart';
import '../../providers/bookmark_provider.dart';
import '../../providers/remote_config_provider.dart';
import '../../data/services/api_service.dart';
import '../../data/services/user_service.dart';
import '../../data/services/profile_service.dart';
import '../../core/widgets/app_drawer.dart';
import '../../core/widgets/audio_mini_player.dart';
import '../../core/widgets/audio_loading_overlay.dart';
import '../home/tabs/news_feed_tab_new.dart';
import '../categories/categories_tab.dart';
import '../bookmarks/bookmarks_tab.dart';
import '../search/search_tab.dart';

class HomeScreen extends StatefulWidget {
  final List<String> selectedCategories;

  const HomeScreen({super.key, required this.selectedCategories});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  List newsList = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      // Initialize API Service - Ensures base URL and endpoints are loaded
      // This is a fallback in case initialization failed at app startup
      // The service checks if already initialized, so it's safe to call multiple times
      try {
        final apiService = ApiService();
        if (!apiService.isInitialized) {
          await apiService.initialize();
          debugPrint("✅ API Service initialized from Home Screen");
        } else {
          debugPrint("✅ API Service already initialized");
        }
      } catch (e) {
        debugPrint("⚠️ API Service initialization failed in Home Screen: $e");
        // Continue even if initialization fails - user can still use the app
      }

      // Initialize other providers
      context.read<NewsProvider>().fetchBreakingNews();
      context.read<NewsProvider>().fetchBreakingNews();
      context.read<NewsProvider>().fetchBreakingNews();
      context.read<BookmarkProvider>().loadBookmarks();
      context.read<RemoteConfigProvider>().initialize();

      // Update FCM Token when home page initializes
      _updateFCMToken();

      // Fetch user profile when home page initializes
      _fetchUserProfile();
    });
  }

  /// Update FCM Token on home page initialization
  Future<void> _updateFCMToken() async {
    try {
      final userService = UserService();
      if (!userService.isLoggedIn) {
        debugPrint('⚠️ User not logged in, skipping FCM token update');
        return;
      }

      final profileService = ProfileService();
      final response = await profileService.updateFCMToken();

      if (response.success) {
        debugPrint('✅ FCM Token updated successfully from Home Screen');
      } else {
        debugPrint('⚠️ FCM Token update failed: ${response.error}');
      }
    } catch (e) {
      debugPrint('❌ Error updating FCM Token from Home Screen: $e');
      // Don't show error to user - this is a background operation
    }
  }

  /// Fetch User Profile on home page initialization
  Future<void> _fetchUserProfile() async {
    try {
      final userService = UserService();
      if (!userService.isLoggedIn) {
        debugPrint('⚠️ User not logged in, skipping user profile fetch');
        return;
      }

      final profileService = ProfileService();
      final response = await profileService.getUserProfile();

      if (response.success) {
        debugPrint('✅ User profile fetched successfully from Home Screen');
      } else {
        debugPrint('⚠️ User profile fetch failed: ${response.error}');
      }
    } catch (e) {
      debugPrint('❌ Error fetching user profile from Home Screen: $e');
      // Don't show error to user - this is a background operation
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Consumer<RemoteConfigProvider>(
      builder: (context, configProvider, child) {
        final config = configProvider.config;

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
              // Main tabs
              IndexedStack(
                index: _currentIndex,
                children: [
                  NewsFeedTabNew(
                    selectedCategories: widget.selectedCategories,
                    newsList: newsList,
                  ),
                  const CategoriesTab(),

                  const BookmarksTab(),
                  const SearchTab(),
                ],
              ),

              // Audio Mini Player (Spotify-like)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: const AudioMiniPlayer(),
              ),

              // Audio Loading Overlay (shows when generating audio)
              const AudioLoadingOverlay(),

              // TTS Controller
              // if (ttsProvider.isPlaying || ttsProvider.isPaused)
              //   Positioned(
              //     left: 0,
              //     right: 0,
              //     bottom: 80,
              //     child: Container(
              //       margin: const EdgeInsets.all(16),
              //       padding: const EdgeInsets.all(12),
              //       decoration: BoxDecoration(
              //         color: theme.colorScheme.primary,
              //         borderRadius: BorderRadius.circular(12),
              //         boxShadow: [
              //           BoxShadow(
              //             color: Colors.black.withOpacity(0.2),
              //             blurRadius: 8,
              //             offset: const Offset(0, 2),
              //           ),
              //         ],
              //       ),
              //       child: Row(
              //         children: [
              //           Icon(
              //             ttsProvider.isPlaying
              //                 ? Icons.volume_up
              //                 : Icons.volume_off,
              //             color: Colors.white,
              //           ),
              //           const SizedBox(width: 12),
              //           Expanded(
              //             child: Column(
              //               crossAxisAlignment: CrossAxisAlignment.start,
              //               mainAxisSize: MainAxisSize.min,
              //               children: [
              //                 const Text(
              //                   'Now Playing',
              //                   style: TextStyle(
              //                     color: Colors.white70,
              //                     fontSize: 12,
              //                   ),
              //                 ),
              //                 Text(
              //                   ttsProvider.currentArticle?.title ?? '',
              //                   style: const TextStyle(
              //                     color: Colors.white,
              //                     fontWeight: FontWeight.bold,
              //                   ),
              //                   maxLines: 1,
              //                   overflow: TextOverflow.ellipsis,
              //                 ),
              //               ],
              //             ),
              //           ),
              //           IconButton(
              //             icon: Icon(
              //               ttsProvider.isPlaying
              //                   ? Icons.pause
              //                   : Icons.play_arrow,
              //               color: Colors.white,
              //             ),
              //             onPressed: ttsProvider.togglePlayPause,
              //           ),
              //           IconButton(
              //             icon: const Icon(Icons.close, color: Colors.white),
              //             onPressed: ttsProvider.stop,
              //           ),
              //         ],
              //       ),
              //     ),
              //   ),
            ],
          ),
          bottomNavigationBar: _buildBottomBar(theme, config),
        );
      },
    );
  }

  Widget _buildBottomBar(ThemeData theme, RemoteConfigModel config) {
    return Container(
      decoration: BoxDecoration(
        color:
            theme.brightness == Brightness.dark
                ? Colors.grey[900]
                : Colors.white,
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
                Icon(Icons.menu, color: theme.colorScheme.secondary),
                LocalizationHelper.menu(context),
                onTap: () => _scaffoldKey.currentState?.openDrawer(),
              ),
              Container(
                decoration: BoxDecoration(
                  color: config.secondaryColorValue.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    _buildBottomNavItem(
                      Icon(
                        Icons.calendar_today_outlined,
                        color:
                            _currentIndex == 0
                                ? config.primaryColorValue
                                : theme.colorScheme.secondary,
                      ),
                      LocalizationHelper.today(context),
                      onTap: () => setState(() => _currentIndex = 0),
                      isSelected: _currentIndex == 0,
                    ),
                    _buildBottomNavItem(
                      Image.network(config.headlineImg, height: 24),
                      LocalizationHelper.headlines(context),
                      onTap: () => setState(() => _currentIndex = 1),
                      isSelected: _currentIndex == 1,
                    ),
                    _buildBottomNavItem(
                      Icon(
                        Icons.bookmark_border,
                        color:
                            _currentIndex == 2
                                ? config.primaryColorValue
                                : theme.colorScheme.secondary,
                      ),
                      LocalizationHelper.forLater(context),
                      onTap: () => setState(() => _currentIndex = 2),
                      isSelected: _currentIndex == 2,
                    ),
                  ],
                ),
              ),
              _buildBottomNavItem(
                Icon(
                  Icons.search,
                  color:
                      _currentIndex == 3
                          ? config.primaryColorValue
                          : theme.colorScheme.secondary,
                ),
                LocalizationHelper.search(context),
                onTap: () => setState(() => _currentIndex = 3),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavItem(
    Widget icon,
    String label, {
    required VoidCallback onTap,
    bool isSelected = false,
  }) {
    const selectedColor = Color(0xFFE31E24);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
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
