import 'package:flutter/material.dart';
import 'package:newson/core/utils/shared_functions.dart';
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
import 'providers/theme_provider.dart';
import 'providers/language_provider.dart';
import 'providers/remote_config_provider.dart';

String newsAPIKey = '';
String baseURL = '';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp();

  await fetchIPAddressAndURLS();
  debugPrint(
    "📝 News API key from .env: ${newsAPIKey.isNotEmpty ? 'Loaded' : 'Not found'}",
  );

  // Initialize local storage
  await StorageService.initialize();

  // Initialize User Service - Load saved user data and token
  await UserService().initialize();

  // Initialize Remote Config FIRST (required for API config)
  final remoteConfigProvider = RemoteConfigProvider();
  await remoteConfigProvider.initialize();

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
        ChangeNotifierProvider(create: (_) => NewsProvider()),
        ChangeNotifierProvider(create: (_) => BookmarkProvider()),
        ChangeNotifierProvider(create: (_) => TtsProvider()),
      ],
      child: Consumer2<ThemeProvider, RemoteConfigProvider>(
        builder: (context, themeProvider, configProvider, child) {
          return MaterialApp(
            title: configProvider.config.appName,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.getLightTheme(configProvider.config),
            darkTheme: AppTheme.getDarkTheme(configProvider.config),
            themeMode: themeProvider.themeMode,
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
  await fetchDBData('newsDataAPIKey').then((val) {
    if (val != null) {
      debugPrint("IP Address fetched: $val");
      newsAPIKey = val;
    }
  });
}
