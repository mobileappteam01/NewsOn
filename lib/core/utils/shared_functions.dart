// ignore_for_file: use_build_context_synchronously, depend_on_referenced_packages

import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:newson/data/models/remote_config_model.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../data/models/news_article.dart';
import '../../data/services/background_music_service.dart';
import '../../providers/remote_config_provider.dart';
import '../../providers/audio_player_provider.dart';
import '../../core/utils/localization_helper.dart';
import '../../data/services/storage_service.dart';
import 'package:firebase_database/firebase_database.dart';

showRefreshButton() {
  return Consumer<RemoteConfigProvider>(
    builder: (context, configProvider, child) {
      final config = configProvider.config;
      final primaryColor = config.primaryColorValue;

      return Positioned(
        top: 16,
        right: 16,
        child: FloatingActionButton.small(
          backgroundColor: primaryColor,
          onPressed: () async {
            await configProvider.forceRefresh();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('🔄 Config refreshed! Check console logs'),
                duration: Duration(seconds: 2),
              ),
            );
          },
          child: const Icon(Icons.refresh, color: Colors.white),
        ),
      );
    },
  );
}

giveHeight(int value) {
  return SizedBox(height: value.toDouble());
}

giveWidth(int value) {
  return SizedBox(width: value.toDouble());
}

Widget showImage(String? url, BoxFit fit, {double? height, double? width}) {
  // Handle empty or null URLs
  if (url == null || url.isEmpty || url.trim().isEmpty) {
    return Container(
      width: width ?? double.infinity,
      height: height ?? 250,
      color: Colors.grey.shade200,
      child: const Center(
        child: Icon(Icons.image_not_supported, color: Colors.grey, size: 48),
      ),
    );
  }

  return Consumer<RemoteConfigProvider>(
    builder: (context, configProvider, child) {
      // 🧊 Normal image (non-GIF)
      return CachedNetworkImage(
        imageUrl: url.trim(),
        width: width ?? MediaQuery.of(context).size.width,
        height: height ?? 250,
        fit: fit,
        placeholder:
            (context, url) => Shimmer.fromColors(
              baseColor: Colors.grey.shade300,
              highlightColor: Colors.grey.shade100,
              child: Container(
                width: width ?? MediaQuery.of(context).size.width,
                height: height ?? 250,
                color: Colors.grey.shade300,
              ),
            ),
        errorWidget:
            (context, url, error) => Container(
              width: width ?? MediaQuery.of(context).size.width,
              height: height ?? 250,
              color: Colors.grey.shade200,
              child: const Center(
                child: Icon(
                  Icons.image_not_supported,
                  color: Colors.grey,
                  size: 48,
                ),
              ),
            ),
      );
    },
  );
}

Future fetchDBCollection(String collectionName) async {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  try {
    QuerySnapshot snapshot = await firestore.collection(collectionName).get();

    // for (var doc in snapshot.docs) {
    //   debugPrint('News Title: ${doc['title']}');
    //   debugPrint('News Content: ${doc['content']}');
    // }
    debugPrint("theeee fetched data is : ${snapshot.docs}");
    final decodedDetails = snapshot.docs.map((doc) => doc.data());
    return decodedDetails.first;
  } catch (e) {
    debugPrint('Error fetching news: $e');
  }
}

showMatchVS(String teamA, String teamB, RemoteConfigModel config) {
  return Container(
    margin: EdgeInsets.symmetric(horizontal: 12),
    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    decoration: BoxDecoration(
      color: config.primaryColorValue,
      borderRadius: BorderRadius.circular(50),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          teamA,
          style: GoogleFonts.inriaSerif(
            color: Colors.white,
            fontWeight: FontWeight.w400,
            fontSize: 17,
          ),
        ),
        giveWidth(12),
        Container(
          height: 50,
          width: 50,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
          ),
          child: Center(
            child: Stack(
              children: [
                Text(
                  'V',
                  style: GoogleFonts.inriaSerif(
                    fontSize: 15,
                    color: Colors.black,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 8.0, left: 4),
                  child: Text(
                    '/',
                    style: GoogleFonts.inriaSerif(
                      fontSize: 15,
                      color: Colors.black,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 12.0, left: 8),
                  child: Text(
                    'S',
                    style: GoogleFonts.inriaSerif(
                      fontSize: 15,
                      color: Colors.black,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        giveWidth(12),
        Text(
          teamB,
          style: GoogleFonts.inriaSerif(
            color: Colors.white,
            fontWeight: FontWeight.w400,
            fontSize: 17,
          ),
        ),
      ],
    ),
  );
}

showShareButton(Function() onTapped, ThemeData theme) {
  return GestureDetector(
    onTap: () => onTapped(),
    child: Transform(
      alignment: Alignment.center,
      transform: Matrix4.rotationY(3.1416), // 180° flip horizontally
      child: Icon(
        Icons.reply_outlined,
        size: 24,
        color: theme.colorScheme.secondary,
      ),
    ),
  );
}

showSaveButton(bool isSaved, Function() onTapped, ThemeData theme) {
  final isDark = theme.brightness == Brightness.dark;
  return GestureDetector(
    onTap: () => onTapped(),
    child: Icon(
      isSaved ? Icons.bookmark : Icons.bookmark_border,
      color:
          isSaved
              ? (isDark
                  ? theme.primaryColor
                  : const Color(0xFFE31E24)) // Red when bookmarked
              : (isDark
                  ? Colors.grey[400]
                  : Colors.grey[600]), // Grey when not bookmarked
      size: 24,
    ),
  );
}

/// Shows a listen button that reacts to audio player state
/// [config] - Remote config for styling
/// [onListenTapped] - Callback when button is tapped (play action)
/// [article] - The article this button is for (used to check if this article is playing)
/// [context] - Optional BuildContext
showListenButton(
  RemoteConfigModel config,
  Function() onListenTapped, [
  BuildContext? context,
  NewsArticle? article,
]) {
  return Builder(
    builder: (ctx) {
      BackgroundMusicService _backgroundMusicService = BackgroundMusicService();
      final buildContext = context ?? ctx;
      return Consumer<AudioPlayerProvider>(
        builder: (context, audioProvider, child) {
          // Check if this specific article is currently playing or paused
          final currentArticle = audioProvider.currentArticle;
          final isThisArticlePlaying = article != null &&
              currentArticle != null &&
              _isSameArticle(article, currentArticle);
          
          final isPlaying = isThisArticlePlaying && audioProvider.isPlaying;
          final isPaused = isThisArticlePlaying && audioProvider.isPaused;
          final isLoading = isThisArticlePlaying && audioProvider.isLoading;
          
          return GestureDetector(
            onTap: () {
              if (isPlaying) {
                // If this article is playing, pause it
                audioProvider.pause();
                // _backgroundMusicService.pause();
              } else if (isPaused) {
                // If this article is paused, resume it
                audioProvider.resume();
                // _backgroundMusicService.resume();
              } else {
                // Otherwise, start playing this article
                onListenTapped();
                // _backgroundMusicService.start();
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: isPlaying || isPaused 
                    ? config.primaryColorValue 
                    : config.primaryColorValue,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isLoading)
                    const SizedBox(
                      width: 15,
                      height: 15,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  else if (isPlaying)
                    const Icon(
                      Icons.pause,
                      color: Colors.white,
                      size: 15,
                    )
                  else if (isPaused)
                    const Icon(
                      Icons.play_arrow,
                      color: Colors.white,
                      size: 15,
                    )
                  else
                    showImage(
                      config.listenIcon,
                      BoxFit.contain,
                      height: 15,
                      width: 15,
                    ),
                  giveWidth(12),
                  Flexible(
                    child: Text(
                      isPlaying 
                          ? 'Playing...' 
                          : isPaused 
                              ? 'Paused' 
                              : LocalizationHelper.listen(buildContext),
                      style: GoogleFonts.playfair(
                        color: Colors.white,
                        fontWeight: FontWeight.w400,
                        fontSize: 15,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

/// Helper function to check if two articles are the same
bool _isSameArticle(NewsArticle a, NewsArticle b) {
  // First try to match by articleId
  if (a.articleId != null && b.articleId != null && a.articleId!.isNotEmpty && b.articleId!.isNotEmpty) {
    return a.articleId == b.articleId;
  }
  // Fallback to title comparison
  return a.title == b.title;
}

Future<NewsArticle> getNewsDetail() async {
  return NewsArticle(
    title: "US to boycott G-20 Summit in South Africa this year.",
    imageUrl:
        'https://www.hindustantimes.com/ht-img/img/2025/11/07/550x309/donald_trump_us_boycott_g20_summit_south_africa_1762556620255_1762556620523.jpg',
    content:
        "Bihar election 2025 live: As Bihar heads for phase 2 polls on Nov 11, parties have intensified their campaigns. The first phase saw 64.6% turnout amid claims Bihar election 2025 live: As Bihar gears up for the second and final phase of the 2025 assembly elections on November 11, political campaigning has gained pace across the state. Out of 243 constituencies, 122 will go to the polls in what is shaping up to be a neck-and-neck contest between the Bharatiya Janata Party (BJP)–Janata Dal (United) led National Democratic Alliance (NDA), the Rashtriya Janata Dal (RJD)–Congress-led Mahagathbandhan.",
  );
}

appButton(Widget content, Function() onPressed) {
  RemoteConfigModel config = RemoteConfigModel();
  return GestureDetector(
    onTap: () => onPressed(),
    child: Container(
      decoration: BoxDecoration(
        color: config.primaryColorValue,
        borderRadius: BorderRadius.circular(25),
      ),
      child: content,
    ),
  );
}

closeButton(Widget content, Function() onPressed) {
  RemoteConfigModel config = RemoteConfigModel();
  return GestureDetector(
    onTap: () => onPressed(),
    child: Container(
      padding: EdgeInsets.symmetric(horizontal: 12),
      width: 100,
      decoration: BoxDecoration(
        color: config.primaryColorValue,
        borderRadius: BorderRadius.circular(25),
      ),
      child: content,
    ),
  );
}

commonappBar(imgURL, Function() backPressed) {
  return Row(
    children: [
      IconButton(
        onPressed: () {
          backPressed();
        },
        icon: Icon(Icons.arrow_back_ios),
      ),
      showImage(imgURL, BoxFit.contain, height: 60, width: 80),
    ],
  );
}

Future fetchDBData(String key) async {
  try {
    // Step 1: Try to load from cache first (for offline support)
    final cachedData = StorageService.getRealtimeDbCache(key);
    if (cachedData != null) {
      debugPrint("📦 Loaded $key from cache");
      // Return cached data immediately, then try to fetch fresh data in background
      _fetchDBDataInBackground(key);
      return cachedData;
    }
  } catch (e) {
    debugPrint("⚠️ Error loading $key from cache: $e");
    // Continue to try fetching from Firebase
  }

  // Step 2: Try to fetch from Firebase
  // Note: Firebase is already initialized in main.dart, but we check anyway
  try {
    // Firebase.initializeApp() is safe to call multiple times (checks if already initialized)
    try {
      await Firebase.initializeApp();
    } catch (e) {
      // Firebase already initialized, ignore error
      debugPrint("ℹ️ Firebase already initialized: $e");
    }
    final dbRef = FirebaseDatabase.instance.ref();
    final snapshot = await dbRef.child(key).get();
    if (snapshot.exists) {
      final data = snapshot.value;
      debugPrint("$key has dataaa : $data");

      // Cache the data for offline use
      try {
        await StorageService.saveRealtimeDbCache(key, data);
      } catch (e) {
        debugPrint("⚠️ Error saving $key to cache: $e");
      }

      return data;
    } else {
      debugPrint("$key has no dataaa");
      return null;
    }
  } catch (e) {
    debugPrint("❌ Error fetching $key from Firebase: $e");
    // Try to return cached data if available, even if stale
    try {
      final cachedData = StorageService.getRealtimeDbCache(key);
      if (cachedData != null) {
        debugPrint("📦 Using stale cached data for $key");
        return cachedData;
      }
    } catch (cacheError) {
      debugPrint("⚠️ Error loading cached data for $key: $cacheError");
    }
    return null;
  }
}

/// Fetch Realtime Database data in background (for refresh)
Future<void> _fetchDBDataInBackground(String key) async {
  try {
    // Firebase is already initialized in main.dart, but check anyway
    try {
      await Firebase.initializeApp();
    } catch (e) {
      // Firebase already initialized, ignore error
      debugPrint("ℹ️ Firebase already initialized in background: $e");
    }
    final dbRef = FirebaseDatabase.instance.ref();
    final snapshot = await dbRef.child(key).get();
    if (snapshot.exists) {
      final data = snapshot.value;
      // Update cache with fresh data
      await StorageService.saveRealtimeDbCache(key, data);
      debugPrint("🔄 Updated $key cache from Firebase");
    }
  } catch (e) {
    debugPrint("⚠️ Background fetch failed for $key: $e");
    // Silently fail - we already have cached data
  }
}

Widget showLogoutModalBottomSheet(BuildContext context) {
  final theme = Theme.of(context);
  return Stack(
    children: [
      SizedBox(
        height: 180,
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                LocalizationHelper.areYouSureYouWantToLogout(context),
                style: GoogleFonts.playfair(
                  fontSize: 20,
                  color: theme.colorScheme.secondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              giveHeight(12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (int i = 0; i < 2; i++)
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(
                          context,
                          i == 0,
                        ); // Return true for Yes, false for No
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 12,
                        ),
                        margin: const EdgeInsets.only(left: 8),
                        decoration: BoxDecoration(
                          color:
                              i == 0 ? const Color(0xff505050) : Colors.white,
                          border: Border.all(color: const Color(0xff505050)),
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: Center(
                          child: Text(
                            i == 0
                                ? LocalizationHelper.yes(context)
                                : LocalizationHelper.no(context),
                            style: GoogleFonts.inriaSerif(
                              fontSize: 15,
                              color: i == 0 ? Colors.white : Colors.black,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    ],
  );
}
