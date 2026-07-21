// ignore_for_file: depend_on_referenced_packages

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:newson/core/utils/shared_functions.dart';
import 'package:newson/l10n/app_localizations.dart';
import 'package:newson/screens/splash/splash_screen.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/api_constants.dart';
import 'core/bootstrap/app_bootstrap.dart';
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
import 'providers/region_provider.dart';
import 'providers/completed_news_provider.dart';
import 'providers/for_you_provider.dart';
import 'data/services/dynamic_localization_service.dart';
import 'data/services/dynamic_icon_service.dart';
import 'data/services/audio_background_service.dart';
import 'data/services/background_music_service.dart';
import 'data/services/news_audio_cache_service.dart';
import 'data/services/news_image_cache_service.dart';
import 'data/services/deep_link_service.dart';
import 'core/navigation/app_navigator.dart';
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

Future<void> _warmOfflineMediaCaches() async {
  try {
    await NewsImageCacheService.instance.prefetchArticles(
      StorageService.getBreakingNewsCache(),
    );
    await NewsImageCacheService.instance.prefetchArticles(
      StorageService.getTodayNewsCache(),
    );
    final cachedConfig = StorageService.getRemoteConfigCache();
    if (cachedConfig != null) {
      await NewsImageCacheService.instance.prefetchRemoteConfig(cachedConfig);
    }
  } catch (e) {
    debugPrint('⚠️ Offline media warm-up: $e');
  }
}

Future<T?> _withTimeout<T>(
  Future<T> future, {
  Duration timeout = const Duration(seconds: 8),
  String? label,
}) async {
  try {
    return await future.timeout(timeout);
  } catch (e) {
    debugPrint('⚠️ ${label ?? 'startup task'} timed out / failed: $e');
    return null;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppBootstrap.markStarted();

  // Minimal blocking work only — paint first Flutter frame ASAP.
  await Firebase.initializeApp();
  await StorageService.initialize();

  // Capture share / cold-start deep link early (local, no network).
  unawaited(DeepLinkService.instance.initialize());

  final networkService = NetworkService();
  final remoteConfigProvider = RemoteConfigProvider();

  // Instant UI config from local cache / defaults (does not wait on network).
  unawaited(remoteConfigProvider.initialize());

  // Load token / user from disk before UI so splash routing is correct.
  await UserService().initialize();

  runApp(
    NewsOnApp(
      remoteConfigProvider: remoteConfigProvider,
      networkService: networkService,
    ),
  );

  // Heavy / network work AFTER first frame so users never stare at a blank window.
  unawaited(_bootstrapAfterFirstFrame(
    remoteConfigProvider: remoteConfigProvider,
    networkService: networkService,
  ));
}

Future<void> _bootstrapAfterFirstFrame({
  required RemoteConfigProvider remoteConfigProvider,
  required NetworkService networkService,
}) async {
  try {
    // Yield so runApp can schedule the first frame.
    await Future<void>.delayed(Duration.zero);

    unawaited(_warmOfflineMediaCaches());

    await Future.wait([
      _withTimeout(fetchAllDBData(), label: 'fetchAllDBData'),
      _withTimeout(networkService.initialize(), label: 'NetworkService'),
      _withTimeout(
        remoteConfigProvider.initialize(),
        timeout: const Duration(seconds: 12),
        label: 'RemoteConfig',
      ),
      _withTimeout(
        AudioBackgroundService.init().then<void>((_) {}).catchError((e) {
          debugPrint('❌ Audio Background Service: $e');
        }),
        timeout: const Duration(seconds: 6),
        label: 'AudioBackground',
      ),
    ]);

    // MobileAds is initialized inside AdService — do not race/timeout it here
    // (that caused "Unable to obtain a JavascriptEngine" on inline ads).

    if (baseURL.isNotEmpty) {
      ApiService().applyKnownBaseUrl(baseURL);
    }

    if (appIconUrl.isNotEmpty) {
      remoteConfigProvider.updateAppIcon(appIconUrl);
      unawaited(_applyDynamicIcon());
    }

    await Future.wait([
      _withTimeout(ApiConstants.initialize(), label: 'ApiConstants'),
      _withTimeout(
        DynamicLocalizationService().initialize(),
        label: 'DynamicLocalization',
      ),
      _withTimeout(ApiService().initialize(), label: 'ApiService'),
    ]);

    unawaited(
      AdService().initialize().then((_) async {
        await AdService().ensureMobileAdsReady();
      }).catchError((e) {
        debugPrint('❌ Ad Service: $e');
      }),
    );

    unawaited(
      FcmService().getToken().then((fcmToken) {
        if (fcmToken != null) {
          debugPrint('✅ FCM Token initialized: $fcmToken');
        }
      }).catchError((e) {
        debugPrint('❌ FCM Service: $e');
      }),
    );

    if (remoteConfigProvider.isVoiceFeaturesEnabled) {
      unawaited(
        BackgroundMusicService().ensureInitialized().catchError((e) {
          debugPrint('⚠️ Background music pre-init failed: $e');
          return null;
        }),
      );
      unawaited(
        NewsAudioCacheService.instance
            .prefetchAllStoredNewsCaches()
            .catchError((e) {
          debugPrint('⚠️ News audio cache prefetch at startup: $e');
        }),
      );
    }

    networkService.onOnline(() async {
      debugPrint('🔄 Network came online - refreshing data...');
      try {
        await remoteConfigProvider.forceRefresh();
        await ApiConstants.initialize();
        if (_globalNewsProvider != null) {
          await _globalNewsProvider!.refreshAllNews();
        }
        unawaited(NewsAudioCacheService.instance.prefetchAllStoredNewsCaches());
        DeepLinkService.instance.processPendingLink();
      } catch (e) {
        debugPrint('⚠️ Error refreshing data on network connect: $e');
      }
    });
  } catch (e) {
    debugPrint('⚠️ Bootstrap error: $e');
  } finally {
    AppBootstrap.markReady();
    DeepLinkService.instance.processPendingLink();
    debugPrint('✅ App bootstrap ready');
  }
}

Future<void> _applyDynamicIcon() async {
  try {
    final currentIcon = await DynamicIconService.getCurrentIcon();
    if (currentIcon != 'dynamic1') {
      await DynamicIconService.changeIcon('dynamic1');
      debugPrint('✅ Dynamic launcher icon applied');
    }
  } catch (e) {
    debugPrint('⚠️ Could not apply dynamic icon: $e');
  }
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
        ChangeNotifierProvider(
          create: (_) {
            final provider = DynamicLanguageProvider();
            provider.initialize();
            return provider;
          },
        ),
        ChangeNotifierProxyProvider<LanguageProvider, NewsProvider>(
          create: (_) {
            final provider = NewsProvider();
            _globalNewsProvider = provider;
            return provider;
          },
          update: (_, languageProvider, previous) {
            previous ??= NewsProvider();
            previous.setLanguageProvider(languageProvider);
            _globalNewsProvider = previous;
            return previous;
          },
        ),
        ChangeNotifierProvider(create: (_) => RegionProvider()),
        ChangeNotifierProvider(create: (_) => BookmarkProvider()),
        ChangeNotifierProvider(create: (_) => ForYouProvider()),
        ChangeNotifierProvider(create: (_) => CompletedNewsProvider()),
        ChangeNotifierProvider(create: (_) => TtsProvider()),
        ChangeNotifierProvider(
          create: (_) {
            final provider = AudioPlayerProvider(
              elevenLabsApiKey:
                  elevenLabsAPIKey.isNotEmpty ? elevenLabsAPIKey : null,
            );
            _globalAudioPlayerProvider = provider;
            return provider;
          },
        ),
      ],
      child: _DeepLinkBridge(
        child: _VoiceFeaturesBridge(
          child: _CompletedNewsBridge(
            child: Consumer3<ThemeProvider, LanguageProvider,
                RemoteConfigProvider>(
              builder: (
                context,
                themeProvider,
                languageProvider,
                configProvider,
                child,
              ) {
                final requestedLocale = languageProvider.locale;

                final isArbSupported = AppLocalizations.supportedLocales.any(
                  (l) => l.languageCode == requestedLocale.languageCode,
                );
                final effectiveLocale =
                    isArbSupported ? requestedLocale : const Locale('en');

                return MaterialApp(
                  navigatorKey: appNavigatorKey,
                  title: configProvider.config.appName,
                  debugShowCheckedModeBanner: false,
                  theme: AppTheme.getLightTheme(configProvider.config),
                  darkTheme: AppTheme.getDarkTheme(configProvider.config),
                  themeMode: themeProvider.themeMode,
                  locale: effectiveLocale,
                  localizationsDelegates: const [
                    AppLocalizations.delegate,
                    GlobalMaterialLocalizations.delegate,
                    GlobalWidgetsLocalizations.delegate,
                    GlobalCupertinoLocalizations.delegate,
                  ],
                  supportedLocales: AppLocalizations.supportedLocales,
                  localeResolutionCallback: (locale, supportedLocales) {
                    if (locale != null) {
                      for (final supportedLocale in supportedLocales) {
                        if (supportedLocale.languageCode ==
                            locale.languageCode) {
                          return supportedLocale;
                        }
                      }
                    }
                    return const Locale('en');
                  },
                  home: const SplashScreen(),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Stops active playback when Remote Config disables voice/audio features.
class _VoiceFeaturesBridge extends StatefulWidget {
  const _VoiceFeaturesBridge({required this.child});
  final Widget child;

  @override
  State<_VoiceFeaturesBridge> createState() => _VoiceFeaturesBridgeState();
}

class _VoiceFeaturesBridgeState extends State<_VoiceFeaturesBridge> {
  RemoteConfigProvider? _remoteConfigProvider;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = context.read<RemoteConfigProvider>();
    if (_remoteConfigProvider != provider) {
      _remoteConfigProvider?.removeListener(_onRemoteConfigChanged);
      _remoteConfigProvider = provider;
      provider.addListener(_onRemoteConfigChanged);
    }
    _enforceVoiceFeaturesGate();
  }

  @override
  void dispose() {
    _remoteConfigProvider?.removeListener(_onRemoteConfigChanged);
    super.dispose();
  }

  void _onRemoteConfigChanged() => _enforceVoiceFeaturesGate();

  void _enforceVoiceFeaturesGate() {
    if (!mounted) return;
    if (context.read<RemoteConfigProvider>().isVoiceFeaturesEnabled) return;

    final audio = context.read<AudioPlayerProvider>();
    if (audio.hasCurrentArticle || audio.isPlaying || audio.isPaused) {
      unawaited(audio.stop());
    }
    unawaited(BackgroundMusicService().stop());
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Processes pending share / deep links after bootstrap + first paint.
class _DeepLinkBridge extends StatefulWidget {
  const _DeepLinkBridge({required this.child});
  final Widget child;

  @override
  State<_DeepLinkBridge> createState() => _DeepLinkBridgeState();
}

class _DeepLinkBridgeState extends State<_DeepLinkBridge> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Wait until configs/API are ready — avoid false "could not load" on cold start.
      await AppBootstrap.waitForReady();
      if (!mounted) return;
      DeepLinkService.instance.processPendingLink();
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
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
  debugPrint('Fetching API keys and configurations...');

  final results = await Future.wait([
    fetchDBData('ipAddress'),
    fetchDBData('newsDataAPIKey'),
    fetchDBData('elevenLabsKey'),
    fetchDBData('elevenLabsVoiceId'),
    fetchDBData('appImages'),
  ]);

  if (results[0] != null) {
    baseURL = results[0].toString();
    ApiService().applyKnownBaseUrl(baseURL);
  }
  if (results[1] != null) newsAPIKey = results[1].toString();

  if (results[2] != null) {
    elevenLabsAPIKey = results[2].toString();
    if (_globalAudioPlayerProvider != null) {
      _globalAudioPlayerProvider!.setApiKey(elevenLabsAPIKey);
      debugPrint('✅ ElevenLabs API key updated in AudioPlayerProvider');
    }
  }

  if (results[3] != null) {
    elevenLabsVoiceId = results[3].toString();
    if (_globalAudioPlayerProvider != null) {
      _globalAudioPlayerProvider!.setVoiceId(elevenLabsVoiceId);
    }
  }

  if (results[4] != null) {
    appIconUrl = results[4].toString();
    debugPrint('✅ App Icon URL fetched: $appIconUrl');
  }
}
