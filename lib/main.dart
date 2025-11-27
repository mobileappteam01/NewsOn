// ignore_for_file: depend_on_referenced_packages

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
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
import 'providers/remote_config_provider.dart';
import 'data/services/dynamic_icon_service.dart';
import 'package:language_detector/language_detector.dart';

String newsAPIKey = '';
String elevenLabsAPIKey = '';
String elevenLabsVoiceId = '';
String baseURL = '';
String appIconUrl = ''; // Dynamic app icon URL from Firebase Realtime Database
final detector = LanguageDetector();

// Global reference to audio player provider for updating API key
AudioPlayerProvider? _globalAudioPlayerProvider;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp();

  // Fetch all API keys and app icon FIRST before initializing providers
  await fetchIPAddressAndURLS();
  await fetchAppIcon(); // Fetch dynamic app icon from Realtime Database
  // Wait a bit more to ensure ElevenLabs API key is fetched and provider is updated
  await Future.delayed(
    const Duration(milliseconds: 1000),
  ); // Give time for async fetch to complete

  // Initialize local storage
  await StorageService.initialize();

  // Initialize User Service - Load saved user data and token
  await UserService().initialize();

  // Initialize Remote Config FIRST (required for API config)
  final remoteConfigProvider = RemoteConfigProvider();
  await remoteConfigProvider.initialize();

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

  // Initialize Dynamic API Configuration from Remote Config
  // This loads all API endpoints, parameters, and settings dynamically
  await ApiConstants.initialize();
  debugPrint("✅ Dynamic API Configuration initialized");

  // Optional: Use Realtime Database for real-time API config updates
  // Uncomment the line below if you want real-time updates from Firebase Realtime Database
  // await ApiConstants.initializeFromRealtimeDatabase();

  // Initialize API Service - Fetch base URL and all endpoints at startup
  try {
    await ApiService().initialize();
    debugPrint("✅ API Service initialized - Base URL and endpoints loaded");
  } catch (e) {
    debugPrint("❌ Failed to initialize API Service: $e");
    // Continue app launch even if API service initialization fails
    // The app can still work, but API calls will fail until initialized
  }

  // Initialize FCM Service - Request permissions and get token ready
  // Note: This may fail on emulators without Google Play Services
  // The app will continue to work without FCM token
  try {
    final fcmToken = await FcmService().getToken();
    if (fcmToken != null) {
      debugPrint("✅ FCM Token initialized: $fcmToken");
    } else {
      debugPrint(
        "⚠️ FCM Token not available. "
        "This is normal on emulators without Google Play Services. "
        "The app will continue without push notifications.",
      );
    }
  } catch (e) {
    debugPrint("❌ Failed to initialize FCM Service: $e");
    debugPrint(
      "ℹ️ App will continue without FCM. "
      "This is expected on some devices/emulators.",
    );
    // Continue app launch even if FCM initialization fails
  }

  runApp(NewsOnApp(remoteConfigProvider: remoteConfigProvider));
}

class NewsOnApp extends StatelessWidget {
  final RemoteConfigProvider remoteConfigProvider;

  const NewsOnApp({super.key, required this.remoteConfigProvider});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: remoteConfigProvider),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
        // NewsProvider depends on LanguageProvider for language-based API calls
        ChangeNotifierProxyProvider<LanguageProvider, NewsProvider>(
          create: (_) => NewsProvider(),
          update: (_, languageProvider, previous) {
            previous ??= NewsProvider();
            previous.setLanguageProvider(languageProvider);
            return previous;
          },
        ),
        ChangeNotifierProvider(create: (_) => BookmarkProvider()),
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
      child: Consumer3<ThemeProvider, LanguageProvider, RemoteConfigProvider>(
        builder: (
          context,
          themeProvider,
          languageProvider,
          configProvider,
          child,
        ) {
          return MaterialApp(
            title: configProvider.config.appName,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.getLightTheme(configProvider.config),
            darkTheme: AppTheme.getDarkTheme(configProvider.config),
            themeMode: themeProvider.themeMode,

            // Localization configuration
            locale: languageProvider.locale,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: languageProvider.supportedLocales,

            home: const SplashScreen(),
            // home: CategorySelectionScreen(),
          );
        },
      ),
    );
  }
}

fetchIPAddressAndURLS() async {
  debugPrint("Fetching IP address and URLs...");

  await fetchDBData('ipAddress').then((val) async {
    if (val != null) {
      debugPrint("IP Address fetched: $val");
      baseURL = val;
      await fetchNewsDataAPIKey();
    }
  });
}

fetchNewsDataAPIKey() async {
  await fetchDBData('newsDataAPIKey').then((val) async {
    if (val != null) {
      debugPrint("IP Address fetched: $val");
      newsAPIKey = val;
      await fetchElevenLabsAPIKey();
    }
  });
}

fetchElevenLabsAPIKey() async {
  await fetchDBData('elevenLabsKey').then((val) async {
    if (val != null) {
      debugPrint("Eleven Labs API Key fetched: $val");
      elevenLabsAPIKey = val;
      await fetchElevenLabsVoiceId();

      // Update the provider if it's already been created
      if (_globalAudioPlayerProvider != null) {
        _globalAudioPlayerProvider!.setApiKey(elevenLabsAPIKey);
        debugPrint('✅ ElevenLabs API key updated in AudioPlayerProvider');
      } else {
        debugPrint(
          '⚠️ AudioPlayerProvider not yet created, key will be set on creation',
        );
      }
    } else {
      debugPrint('⚠️ ElevenLabs API key not found in database');
    }
  });
}

fetchElevenLabsVoiceId() async {
  await fetchDBData('elevenLabsVoiceId').then((val) {
    if (val != null) {
      debugPrint("Eleven Labs Voice ID fetched: $val");
      elevenLabsVoiceId = val;
      if (_globalAudioPlayerProvider != null) {
        _globalAudioPlayerProvider!.setVoiceId(elevenLabsVoiceId);
      } else {
        debugPrint(
          '⚠️ AudioPlayerProvider not yet created, key will be set on creation',
        );
      }
    }
  });
}

/// Fetch dynamic app icon from Firebase Realtime Database
fetchAppIcon() async {
  await fetchDBData('appImages').then((val) {
    if (val != null) {
      debugPrint("✅ App Icon URL fetched: $val");
      appIconUrl = val.toString();
    } else {
      debugPrint('⚠️ App Icon URL not found in database');
    }
  });
}
