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
import '../../providers/remote_config_provider.dart';
import '../../core/utils/localization_helper.dart';
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

Widget showImage(String url, BoxFit fit, {double? height, double? width}) {
  return Consumer<RemoteConfigProvider>(
    builder: (context, configProvider, child) {
      final parsedURL = configProvider.config.noResultsFound!;

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
            (context, url, error) => Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    parsedURL,
                    width: width ?? MediaQuery.of(context).size.width,
                    height: height ?? 250,
                    fit: fit,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  "No Results Found",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ],
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
  return GestureDetector(
    onTap: () => onTapped(),
    child: Icon(
      isSaved ? Icons.bookmark : Icons.bookmark_border,
      color: theme.colorScheme.secondary,
    ),
  );
}

showListenButton(
  RemoteConfigModel config,
  Function() onListenTapped, [
  BuildContext? context,
]) {
  return Builder(
    builder: (ctx) {
      final buildContext = context ?? ctx;
      return GestureDetector(
        onTap: () => onListenTapped(), // ✅ FIXED
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: config.primaryColorValue,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              showImage(
                config.listenIcon,
                BoxFit.contain,
                height: 15,
                width: 15,
              ),
              giveWidth(12),
              Flexible(
                child: Text(
                  LocalizationHelper.listen(buildContext),
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
  await Firebase.initializeApp();
  final dbRef = FirebaseDatabase.instance.ref();
  final snapshot = await dbRef.child(key).get();
  if (snapshot.exists) {
    debugPrint("$key has dataaa : ${snapshot.value}");
    return snapshot.value;
  } else {
    debugPrint("$key has no dataaa");
    return null;
  }
}

Widget showLogoutModalBottomSheet(BuildContext context) {
  final RemoteConfigModel config = RemoteConfigModel();
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
                'Are you sure you want to logout?',
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
                            i == 0 ? "Yes" : "No",
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
