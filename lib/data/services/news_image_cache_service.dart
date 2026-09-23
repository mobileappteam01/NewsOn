import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../models/news_article.dart';
import '../models/remote_config_model.dart';

/// Prefetches remote images so feed thumbs warm disk cache after first load.
///
/// Background prefetch is intentionally conservative (bounded concurrency,
/// small caps at call sites) so visible [CachedNetworkImage] requests keep
/// network priority. Prefetch is best-effort and never required for online UI.
class NewsImageCacheService {
  NewsImageCacheService._();
  static final NewsImageCacheService instance = NewsImageCacheService._();

  static final CacheManager _cache = DefaultCacheManager();

  /// Max simultaneous background prefetch downloads.
  static const int _maxConcurrentPrefetch = 3;

  final Set<String> _inFlight = <String>{};
  final List<String> _queue = <String>[];
  int _active = 0;

  /// Enqueues a single URL for best-effort background download (bounded).
  Future<void> prefetchUrl(String? url) async {
    final trimmed = _normalize(url);
    if (trimmed == null) return;
    _enqueue(trimmed);
  }

  /// Enqueues unique http(s) URLs onto the bounded prefetch queue.
  Future<void> prefetchUrls(Iterable<String?> urls) async {
    final seen = <String>{};
    for (final url in urls) {
      final trimmed = _normalize(url);
      if (trimmed == null) continue;
      if (!seen.add(trimmed)) continue;
      _enqueue(trimmed);
    }
  }

  /// Prefetch article **hero** images only (not [NewsArticle.sourceIcon]).
  ///
  /// [maxArticles] limits how many articles from the start of [articles] are
  /// considered (near-visible warm). Omit for remote-config-style full lists
  /// that are already tiny.
  Future<void> prefetchArticles(
    Iterable<NewsArticle> articles, {
    int? maxArticles,
  }) async {
    final list = maxArticles == null
        ? articles
        : articles.take(maxArticles);
    await prefetchUrls(list.map((a) => a.imageUrl));
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

  String? _normalize(String? url) {
    final trimmed = url?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    if (!trimmed.startsWith('http')) return null;
    return trimmed;
  }

  void _enqueue(String url) {
    if (_inFlight.contains(url)) return;
    if (_queue.contains(url)) return;
    _queue.add(url);
    _pump();
  }

  void _pump() {
    while (_active < _maxConcurrentPrefetch && _queue.isNotEmpty) {
      final url = _queue.removeAt(0);
      if (_inFlight.contains(url)) continue;
      _inFlight.add(url);
      _active++;
      unawaited(_runPrefetch(url));
    }
  }

  Future<void> _runPrefetch(String url) async {
    try {
      // Skip if already on disk — do not compete with visible loads.
      final cached = await _cache.getFileFromCache(url);
      if (cached != null) {
        try {
          if (await cached.file.exists()) {
            return;
          }
        } catch (_) {
          // Fall through to download if existence check fails.
        }
      }

      await _cache.downloadFile(url);
    } catch (e) {
      debugPrint('⚠️ Image prefetch failed: $url — $e');
    } finally {
      _inFlight.remove(url);
      _active--;
      _pump();
    }
  }

  /// Builds a [CachedNetworkImage] that still uses [_cache] for disk, and
  /// optionally decodes at [memCacheWidth]/[memCacheHeight] (device pixels)
  /// so list thumbnails do not keep full-resolution bitmaps in memory.
  Widget cachedImage({
    required String url,
    BoxFit fit = BoxFit.cover,
    double? width,
    double? height,
    int? memCacheWidth,
    int? memCacheHeight,
    Widget? placeholder,
    Widget? errorWidget,
  }) {
    return CachedNetworkImage(
      imageUrl: url,
      cacheManager: _cache,
      fit: fit,
      width: width,
      height: height,
      memCacheWidth: memCacheWidth,
      memCacheHeight: memCacheHeight,
      // Keep appearance snappy once the decode finishes.
      fadeInDuration: const Duration(milliseconds: 120),
      fadeOutDuration: Duration.zero,
      placeholder: (_, __) =>
          placeholder ??
          Container(
            width: width,
            height: height,
            color: const Color(0xFFE0E0E0),
          ),
      errorWidget: (_, __, ___) =>
          errorWidget ??
          Container(
            color: Colors.grey.shade100,
            alignment: Alignment.center,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Image.asset(
                'assets/images/newson.png',
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => Icon(
                  Icons.image_not_supported,
                  color: Colors.grey.shade400,
                ),
              ),
            ),
          ),
    );
  }
}
