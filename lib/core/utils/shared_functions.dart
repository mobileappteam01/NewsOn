// ignore_for_file: use_build_context_synchronously, depend_on_referenced_packages

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/remote_config_provider.dart';

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
