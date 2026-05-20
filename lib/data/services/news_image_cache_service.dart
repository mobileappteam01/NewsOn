import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../models/news_article.dart';
import '../models/remote_config_model.dart';

/// Prefetches remote images so Firebase / news thumbnails work offline after first load.
class NewsImageCacheService {
  NewsImageCacheService._();
  static final NewsImageCacheService instance = NewsImageCacheService._();

  static final CacheManager _cache = DefaultCacheManager();

  Future<void> prefetchUrl(String? url) async {
    final trimmed = url?.trim();
    if (trimmed == null || trimmed.isEmpty) return;
    if (!trimmed.startsWith('http')) return;

    try {
      await _cache.downloadFile(trimmed);
    } catch (e) {
      debugPrint('⚠️ Image prefetch failed: $trimmed — $e');
    }
  }

  Future<void> prefetchUrls(Iterable<String?> urls) async {
    final seen = <String>{};
    for (final url in urls) {
      final trimmed = url?.trim();
      if (trimmed == null || trimmed.isEmpty || !trimmed.startsWith('http')) {
        continue;
      }
      if (!seen.add(trimmed)) continue;
      unawaited(prefetchUrl(trimmed));
    }
  }

  Future<void> prefetchArticles(Iterable<NewsArticle> articles) async {
    await prefetchUrls(
      articles.expand(
        (a) => [a.imageUrl, a.sourceIcon],
      ),
    );
  }

  Future<void> prefetchRemoteConfig(RemoteConfigModel config) async {
    await prefetchUrls([
      config.appIcon,
      config.splashAnimatedGif,
      config.languageImg,
      config.getAppNameLogoForTheme(Brightness.light),
      config.getAppNameLogoForTheme(Brightness.dark),
    ]);
  }

  /// Warm [CachedNetworkImage] disk cache for a single URL (e.g. breaking carousel).
  Widget cachedImage({
    required String url,
    BoxFit fit = BoxFit.cover,
    double? width,
    double? height,
    Widget? placeholder,
    Widget? errorWidget,
  }) {
    return CachedNetworkImage(
      imageUrl: url,
      cacheManager: _cache,
      fit: fit,
      width: width,
      height: height,
      placeholder: (_, __) =>
          placeholder ??
          Container(
            color: const Color(0xFFE0E0E0),
            child: const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
      errorWidget: (_, __, ___) =>
          errorWidget ??
          Container(
            color: const Color(0xFFE0E0E0),
            child: const Center(
              child: Icon(Icons.image_not_supported, color: Colors.grey),
            ),
          ),
    );
  }
}
