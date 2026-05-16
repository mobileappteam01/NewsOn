// ignore_for_file: depend_on_referenced_packages

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:newson/core/utils/shared_functions.dart';
import 'package:newson/l10n/app_localizations.dart';
import 'package:newson/screens/splash/splash_screen.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/api_constants.dart';
import 'data/services/storage_service.dart';
import 'data/services/api_service.dart';
import 'data/services/user_service.dart';
import 'data/services/fcm_service.dart';
import 'providers/news_provider.dart';
import 'providers/bookmark_provider.dart';
import 'providers/tts_provider.dart';
import 'providers/audio_player_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/language_provider.dart';
import 'providers/dynamic_language_provider.dart';
import 'providers/remote_config_provider.dart';
import 'providers/completed_news_provider.dart';
import 'data/services/dynamic_localization_service.dart';
import 'data/services/dynamic_icon_service.dart';
import 'data/services/audio_background_service.dart';
import 'data/services/background_music_service.dart';
import 'data/services/news_audio_cache_service.dart';
import 'data/services/ad_service.dart';
import 'core/services/network_service.dart';
import 'package:language_detector/language_detector.dart';

String newsAPIKey = '';
String elevenLabsAPIKey = '';
String elevenLabsVoiceId = '';
String baseURL = '';
String appIconUrl = ''; // Dynamic app icon URL from Firebase Realtime Database
final detector = LanguageDetector();

// Global reference to audio player provider for updating API key
AudioPlayerProvider? _globalAudioPlayerProvider;

// Global reference to news provider for network refresh
NewsProvider? _globalNewsProvider;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp();

  // Initialize local storage FIRST (required for cache operations)
  await StorageService.initialize();

  // Fetch all DB configs (API keys, URLs, App Icon) in parallel
  // This drastically reduces startup time compared to sequential fetches
  final networkService = NetworkService();
  final remoteConfigProvider = RemoteConfigProvider();

  await Future.wait([
    fetchAllDBData(),
    networkService.initialize(),
    UserService().initialize(),
    remoteConfigProvider.initialize(),
    MobileAds.instance.initialize(),
    AudioBackgroundService.init().catchError((e) {
      debugPrint("❌ Failed to initialize Audio Background Service: $e");
    }),
  ]);

  // Initialize Network Service for connectivity monitoring

  // Initialize User Service - Load saved user data and token
  await UserService().initialize();

  // Initialize Remote Config FIRST (required for API config)

  // Update app icon if fetched from Realtime Database
  if (appIconUrl.isNotEmpty) {
    remoteConfigProvider.updateAppIcon(appIconUrl);
    debugPrint('✅ App icon set in RemoteConfigProvider');

    // Apply dynamic launcher icon change (Android only)
    // Only change icon if we're not already using the default
    // This prevents duplicate app entries on the launcher
    try {
      final currentIcon = await DynamicIconService.getCurrentIcon();
      if (currentIcon != 'dynamic1') {
        // Switch to dynamic1 variant when icon is fetched
        // In production, you can download the icon and create variants
        await DynamicIconService.changeIcon('dynamic1');
        debugPrint('✅ Dynamic launcher icon applied');
      } else {
        debugPrint('ℹ️ Dynamic icon already active, skipping change');
      }
    } catch (e) {
      debugPrint('⚠️ Could not apply dynamic icon: $e');
      // This is expected on iOS or if the feature is not fully set up
    }
  }

  // Initialize Dynamic Localization Service and API Config
  // These depend on RemoteConfigProvider being initialized
  await Future.wait([
    ApiConstants.initialize(),
    DynamicLocalizationService().initialize(),
  ]);
  debugPrint("✅ Dynamic API and Localization Services initialized");

  // Initialize dependent services that don't block app start
  Future.wait([
    AdService().initialize().catchError((e) {
      debugPrint("❌ Failed to initialize Ad Service: $e");
    }),
    ApiService().initialize().catchError((e) {
      debugPrint("❌ Failed to initialize API Service: $e");
    }),
    FcmService().getToken().then((fcmToken) {
      if (fcmToken != null) {
        debugPrint("✅ FCM Token initialized: $fcmToken");
      }
    }).catchError((e) {
      debugPrint("❌ Failed to initialize FCM Service: $e");
    }),
  ]);

  // Pre-initialize background music (fetch URL from Firebase) so first article gets BG
  BackgroundMusicService().ensureInitialized().catchError((e) {
    debugPrint('⚠️ Background music pre-init failed: $e');
    return null;
  });

  // Prefetch audio for previously cached news lists (offline listen after one online session)
  unawaited(
    NewsAudioCacheService.instance.prefetchAllStoredNewsCaches().catchError((e) {
      debugPrint('⚠️ News audio cache prefetch at startup: $e');
    }),
  );

  // ... fcm logic moved to Future.wait ...

  // Setup background refresh when network comes online
  networkService.onOnline(() async {
    debugPrint('🔄 Network came online - refreshing data...');
    try {
      // Refresh Remote Config
      await remoteConfigProvider.forceRefresh();

      // Refresh API Config
      await ApiConstants.initialize();

      // Refresh all news if NewsProvider is available
      if (_globalNewsProvider != null) {
        await _globalNewsProvider!.refreshAllNews();
      }

      unawaited(
        NewsAudioCacheService.instance.prefetchAllStoredNewsCaches(),
      );
    } catch (e) {
      debugPrint('⚠️ Error refreshing data on network connect: $e');
    }
  });

  runApp(
    NewsOnApp(
      remoteConfigProvider: remoteConfigProvider,
      networkService: networkService,
    ),
  );
}

class NewsOnApp extends StatelessWidget {
  final RemoteConfigProvider remoteConfigProvider;
  final NetworkService networkService;

  const NewsOnApp({
    super.key,
    required this.remoteConfigProvider,
    required this.networkService,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: remoteConfigProvider),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
        // Dynamic Language Provider - Fetches languages from Firebase
        ChangeNotifierProvider(
          create: (_) {
            final provider = DynamicLanguageProvider();
            provider.initialize();
            return provider;
          },
        ),
        // NewsProvider depends on LanguageProvider for language-based API calls
        ChangeNotifierProxyProvider<LanguageProvider, NewsProvider>(
          create: (_) {
            final provider = NewsProvider();
            _globalNewsProvider = provider; // Store global reference
            return provider;
          },
          update: (_, languageProvider, previous) {
            previous ??= NewsProvider();
            previous.setLanguageProvider(languageProvider);
            _globalNewsProvider = previous; // Update global reference
            return previous;
          },
        ),
        ChangeNotifierProvider(create: (_) => BookmarkProvider()),
        ChangeNotifierProvider(create: (_) => CompletedNewsProvider()),
        ChangeNotifierProvider(create: (_) => TtsProvider()),
        // Audio Player Provider - Get API key from Firebase
        ChangeNotifierProvider(
          create: (_) {
            final provider = AudioPlayerProvider(
              elevenLabsApiKey:
                  elevenLabsAPIKey.isNotEmpty ? elevenLabsAPIKey : null,
            );
            // Store global reference to update when key is fetched
            _globalAudioPlayerProvider = provider;

            if (elevenLabsAPIKey.isNotEmpty) {
              debugPrint(
                '✅ AudioPlayerProvider initialized with ElevenLabs API key',
              );
            } else {
              debugPrint(
                '⚠️ AudioPlayerProvider initialized without API key - will update when fetched',
              );
            }
            return provider;
          },
        ),
      ],
      child: _CompletedNewsBridge(
        child: Consumer3<ThemeProvider, LanguageProvider, RemoteConfigProvider>(
          builder: (
            context,
            themeProvider,
            languageProvider,
            configProvider,
            child,
          ) {
            // Get the locale, but fall back to English for AppLocalizations if not supported
            final requestedLocale = languageProvider.locale;

            // Check if the locale is supported by AppLocalizations (ARB files)
            // Currently only 'en' and 'ta' have ARB files
            final arbSupportedLocales = ['en', 'ta'];
            final effectiveLocale =
                arbSupportedLocales.contains(requestedLocale.languageCode)
                    ? requestedLocale
                    : const Locale(
                        'en',
                      ); // Fallback to English for AppLocalizations

            return MaterialApp(
              title: configProvider.config.appName,
              debugShowCheckedModeBanner: false,
              theme: AppTheme.getLightTheme(configProvider.config),
              darkTheme: AppTheme.getDarkTheme(configProvider.config),
              themeMode: themeProvider.themeMode,

              // Localization configuration
              // Use effectiveLocale for Flutter's built-in localization (ARB files)
              // Dynamic translations are handled separately by DynamicLocalizationService
              locale: effectiveLocale,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              // Only include locales that have ARB file support
              supportedLocales: const [Locale('en'), Locale('ta')],

              // Resolve locale - fall back to English if not supported by ARB
              localeResolutionCallback: (locale, supportedLocales) {
                if (locale != null) {
                  for (final supportedLocale in supportedLocales) {
                    if (supportedLocale.languageCode == locale.languageCode) {
                      return supportedLocale;
                    }
                  }
                }
                return const Locale('en'); // Default fallback
              },

              home: const SplashScreen(),
              // home: CategorySelectionScreen(),
            );
          },
        ),
      ),
    );
  }
}

/// One-time setup: load completed news for current user and wire audio completion.
class _CompletedNewsBridge extends StatefulWidget {
  const _CompletedNewsBridge({required this.child});
  final Widget child;

  @override
  State<_CompletedNewsBridge> createState() => _CompletedNewsBridgeState();
}

class _CompletedNewsBridgeState extends State<_CompletedNewsBridge> {
  bool _didSetup = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didSetup) return;
    _didSetup = true;
    final completed = context.read<CompletedNewsProvider>();
    final audio = context.read<AudioPlayerProvider>();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      debugPrint('🔄 [CompletedNewsBridge] loading for current user...');
      await completed.loadForCurrentUser();
      if (!mounted) return;
      audio.onNewsCompleted = (newsId, category) {
        completed.markNewsCompleted(newsId, category);
      };
      debugPrint(
          '🔄 [CompletedNewsBridge] setup done userId=${completed.userId ?? "null"}');
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Fetch all DB configurations in parallel to optimize startup time
Future<void> fetchAllDBData() async {
  debugPrint("Fetching API keys and configurations...");

  final results = await Future.wait([
    fetchDBData('ipAddress'),
    fetchDBData('newsDataAPIKey'),
    fetchDBData('elevenLabsKey'),
    fetchDBData('elevenLabsVoiceId'),
    fetchDBData('appImages'),
  ]);

  if (results[0] != null) baseURL = results[0];
  if (results[1] != null) newsAPIKey = results[1];

  if (results[2] != null) {
    elevenLabsAPIKey = results[2];
    if (_globalAudioPlayerProvider != null) {
      _globalAudioPlayerProvider!.setApiKey(elevenLabsAPIKey);
      debugPrint('✅ ElevenLabs API key updated in AudioPlayerProvider');
    }
  }

  if (results[3] != null) {
    elevenLabsVoiceId = results[3];
    if (_globalAudioPlayerProvider != null) {
      _globalAudioPlayerProvider!.setVoiceId(elevenLabsVoiceId);
    }
  }

  if (results[4] != null) {
    appIconUrl = results[4].toString();
    debugPrint("✅ App Icon URL fetched: $appIconUrl");
  }
}
