// ignore_for_file: deprecated_member_use, unused_local_variable, use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:newson/core/utils/localization_helper.dart';
import 'package:newson/data/models/remote_config_model.dart';
import 'package:provider/provider.dart';
import '../../providers/news_provider.dart';
import '../../providers/bookmark_provider.dart';
import '../../providers/completed_news_provider.dart';
import '../../providers/remote_config_provider.dart';
import '../../providers/language_provider.dart';
import '../../providers/dynamic_language_provider.dart';
import '../../data/services/api_service.dart';
import '../../data/services/user_service.dart';
import '../../data/services/profile_service.dart';
import '../../data/services/app_update_service.dart';
import '../../core/widgets/app_drawer.dart';
import '../../core/widgets/audio_mini_player.dart';
import '../../core/widgets/audio_loading_overlay.dart';
import '../../core/widgets/app_update_dialog.dart';
import '../../data/services/deep_link_service.dart';
import '../../core/utils/auth_navigation_helper.dart';
import '../home/tabs/news_feed_tab_new.dart';
import '../../features/home/presentation/v2_home_feed_tab.dart';
import '../../features/home_v2/presentation/v2_reader_home.dart';
import '../../features/home_v2/presentation/widgets/v2_bottom_navigation.dart';
import '../../features/home_v2/presentation/widgets/v2_vintage_paper_background.dart';
import '../../core/config/v2_feature_flags.dart';
import '../../core/analytics/analytics_service.dart';
import '../../features/notifications/data/notification_service.dart';
import 'tabs/for_you_tab.dart';
import '../bookmarks/bookmarks_tab.dart';
import '../search/search_tab.dart';
import '../../features/search/presentation/v2_search_tab.dart';
import '../../features/for_you/presentation/v2_for_you_tab.dart';

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
      // (safe to call repeatedly; re-fetches endpoints if cache was empty)
      try {
        final apiService = ApiService();
        await apiService.initialize();
        debugPrint(
          '✅ API Service ready (endpoints: '
          '${apiService.isInitialized ? "ok" : "pending"})',
        );
      } catch (e) {
        debugPrint('⚠️ API Service initialization failed in Home Screen: $e');
        // Continue even if initialization fails - user can still use the app
      }

      // Initialize other providers
      await context.read<NewsProvider>().fetchBreakingNews();
      DeepLinkService.instance.processPendingLink(navigationReady: true);
      V2NotificationService.instance.processPendingOpen(navigationReady: true);
      context.read<BookmarkProvider>().loadBookmarks();
      context.read<CompletedNewsProvider>().loadForCurrentUser();
      context.read<RemoteConfigProvider>().initialize();

      // Update FCM Token when home page initializes
      _updateFCMToken();

      // Fetch user profile when home page initializes
      _fetchUserProfile();

      // Check for app updates
      _checkForAppUpdate();

      AnalyticsService.instance.ensureSessionStarted();
    });
  }

  /// Check for app updates and show dialog if available
  Future<void> _checkForAppUpdate() async {
    try {
      final appUpdateService = AppUpdateService();
      final updateInfo = await appUpdateService.checkForUpdate();

      if (updateInfo != null && mounted) {
        debugPrint('🆕 Showing app update dialog');
        await AppUpdateDialog.show(
          context,
          updateInfo: updateInfo,
          onUpdate: () async {
            await appUpdateService.openStoreLink();
          },
          onLater: () {
            debugPrint('📱 User chose to update later');
          },
        );
      }
    } catch (e) {
      debugPrint('❌ Error checking for app update: $e');
      // Don't show error to user - app update check is not critical
    }
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

      // Phase 7B — also register with V2 device registry when enabled.
      if (mounted) {
        final config = context.read<RemoteConfigProvider>().config;
        await V2NotificationService.instance.onUserAuthenticated(config);
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

    return Consumer3<RemoteConfigProvider, LanguageProvider,
        DynamicLanguageProvider>(
      builder: (context, configProvider, languageProvider,
          dynamicLanguageProvider, child) {
        final config = configProvider.config;
        // Consumer3 watches language providers so bottom nav labels refresh
        // for both ARB (ta/hi/en) and dynamic (ml/te/kn) languages.
        assert(languageProvider.locale.languageCode.isNotEmpty);
        assert(dynamicLanguageProvider.currentLanguageCode.isNotEmpty);

        return Scaffold(
          key: _scaffoldKey,
          backgroundColor: V2FeatureFlags.v2Chrome(config) ||
                  V2FeatureFlags.homeReader(config)
              ? V2VintagePaperBackground.stageBaseFor(theme.brightness)
              : theme.scaffoldBackgroundColor,
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
                  V2FeatureFlags.homeReader(config)
                      ? V2ReaderHome(
                          key: const ValueKey('v2_reader_home'),
                          onOpenForYouTab: () {
                            if (!ensureLoggedInForAccountFeature(context)) {
                              return;
                            }
                            setState(() => _currentIndex = 1);
                          },
                        )
                      : V2FeatureFlags.newsCuts(config)
                          ? V2HomeFeedTab(
                              key: const ValueKey('v2_news_feed_tab'),
                              onOpenForYouTab: () {
                                if (!ensureLoggedInForAccountFeature(
                                    context)) {
                                  return;
                                }
                                setState(() => _currentIndex = 1);
                              },
                            )
                          : NewsFeedTabNew(
                              key: const ValueKey('news_feed_tab'),
                              selectedCategories: widget.selectedCategories,
                              newsList: newsList,
                            ),
                  V2FeatureFlags.forYou(config)
                      ? const V2ForYouTab()
                      : const ForYouTab(),
                  const BookmarksTab(),
                  V2FeatureFlags.search(config)
                      ? const V2SearchTab()
                      : const SearchTab(),
                ],
              ),

              // Audio Mini Player (Spotify-like)
              const Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: AudioMiniPlayer(),
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
              //         color: theme.primaryColor,
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
          bottomNavigationBar: V2FeatureFlags.v2Chrome(config) ||
                  V2FeatureFlags.homeReader(config)
              ? _buildV2BottomBar()
              : _buildLegacyBottomBar(theme, config),
        );
      },
    );
  }

  /// V2: Home · For You · Bookmarks · Search (floating pill).
  ///
  /// IndexedStack: 0 Home · 1 For You · 2 Bookmarks · 3 Search —
  /// nav highlight matches stack index directly (Search is last).
  Widget _buildV2BottomBar() {
    return ColoredBox(
      color: Colors.transparent,
      child: V2FloatingBottomNav(
        currentIndex: _currentIndex,
        homeLabel: LocalizationHelper.home(context),
        forYouLabel: LocalizationHelper.forYou(context),
        bookmarksLabel: LocalizationHelper.bookmarks(context),
        searchLabel: LocalizationHelper.v2Search(context),
        onHome: () => setState(() => _currentIndex = 0),
        onForYou: () {
          if (!ensureLoggedInForAccountFeature(context)) return;
          setState(() => _currentIndex = 1);
        },
        onBookmarks: () {
          if (!ensureLoggedInForAccountFeature(context)) return;
          setState(() => _currentIndex = 2);
        },
        onSearch: () => setState(() => _currentIndex = 3),
      ),
    );
  }

  /// V1 chrome preserved when V2 reader/chrome flags are off.
  Widget _buildLegacyBottomBar(ThemeData theme, RemoteConfigModel config) {
    return Container(
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
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
              _legacyNavItem(
                Icon(Icons.menu, color: theme.colorScheme.secondary),
                LocalizationHelper.menu(context),
                onTap: () => _scaffoldKey.currentState?.openDrawer(),
              ),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: config.secondaryColorValue.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _legacyNavItem(
                          Icon(
                            Icons.calendar_today_outlined,
                            color: _currentIndex == 0
                                ? config.primaryColorValue
                                : theme.colorScheme.secondary,
                          ),
                          LocalizationHelper.today(context),
                          onTap: () => setState(() => _currentIndex = 0),
                          isSelected: _currentIndex == 0,
                        ),
                      ),
                      Expanded(
                        child: _legacyNavItem(
                          Icon(
                            Icons.auto_awesome_outlined,
                            color: _currentIndex == 1
                                ? config.primaryColorValue
                                : theme.colorScheme.secondary,
                          ),
                          LocalizationHelper.forYou(context),
                          onTap: () {
                            if (!ensureLoggedInForAccountFeature(context)) {
                              return;
                            }
                            setState(() => _currentIndex = 1);
                          },
                          isSelected: _currentIndex == 1,
                        ),
                      ),
                      Expanded(
                        child: _legacyNavItem(
                          Icon(
                            Icons.bookmark_border,
                            color: _currentIndex == 2
                                ? config.primaryColorValue
                                : theme.colorScheme.secondary,
                          ),
                          LocalizationHelper.forLater(context),
                          onTap: () {
                            if (!ensureLoggedInForAccountFeature(context)) {
                              return;
                            }
                            setState(() => _currentIndex = 2);
                          },
                          isSelected: _currentIndex == 2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              _legacyNavItem(
                Icon(
                  Icons.search,
                  color: _currentIndex == 3
                      ? config.primaryColorValue
                      : theme.colorScheme.secondary,
                ),
                LocalizationHelper.search(context),
                onTap: () => setState(() => _currentIndex = 3),
                isSelected: _currentIndex == 3,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _legacyNavItem(
    Widget icon,
    String label, {
    required VoidCallback onTap,
    bool isSelected = false,
  }) {
    const selectedColor = Color(0xFFE31E24);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
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
