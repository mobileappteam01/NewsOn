import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/theme/app_theme.dart';
import 'data/services/storage_service.dart';
import 'providers/news_provider.dart';
import 'providers/bookmark_provider.dart';
import 'providers/tts_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/language_provider.dart';
import 'providers/remote_config_provider.dart';
import 'screens/splash/splash_screen.dart';


    final GoogleSignIn googleSignIn = GoogleSignIn.instance;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp();
  
  // Initialize local storage
  await StorageService.initialize();
  
  // Initialize Remote Config
  final remoteConfigProvider = RemoteConfigProvider();
  await remoteConfigProvider.initialize();
  
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
          );
        },
      ),
    );
  }
}
