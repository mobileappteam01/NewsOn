import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/connectivity_helper.dart';
import '../models/news_article.dart';
import 'storage_service.dart';

/// Persists news MP3 files under app documents so playback works offline.
/// URLs are hashed for filenames; duplicate URLs share one file.
class NewsAudioCacheService {
  NewsAudioCacheService._();
  static final NewsAudioCacheService instance = NewsAudioCacheService._();

  Directory? _dir;

  Future<Directory> _ensureDir() async {
    if (_dir != null) return _dir!;
    final doc = await getApplicationDocumentsDirectory();
    _dir = Directory(p.join(doc.path, 'news_audio_cache'));
    if (!await _dir!.exists()) {
      await _dir!.create(recursive: true);
    }
    return _dir!;
  }

  String _filenameForUrl(String url) {
    final digest = sha256.convert(utf8.encode(url.trim())).toString();
    return '$digest.mp3';
  }

  Future<File> _fileForUrl(String url) async {
    final dir = await _ensureDir();
    return File(p.join(dir.path, _filenameForUrl(url)));
  }

  /// Same URL list as [AudioPlayerProvider.playArticleFromUrl] — keeps prefetch aligned with playback.
  static List<String> playbackUrlsForArticle(
    NewsArticle article, {
    required bool playTitle,
    String? readingMode,
  }) {
    final urls = <String>[];

    if (playTitle) {
      final mode = readingMode ?? StorageService.getNewsReadingMode();

      if (mode == AppConstants.readingModeTitleOnly) {
        final u = article.titleAudioUrl;
        if (u != null && u.isNotEmpty) urls.add(u);
      } else if (mode == AppConstants.readingModeDescriptionOnly) {
        final d = article.descriptionAudioUrl;
        if (d != null && d.isNotEmpty) {
          urls.add(d);
        } else {
          final t = article.titleAudioUrl;
          if (t != null && t.isNotEmpty) urls.add(t);
        }
      } else if (mode == AppConstants.readingModeFullNews) {
        final c = article.contentAudioUrl;
        final d = article.descriptionAudioUrl;
        final t = article.titleAudioUrl;
        if (c != null && c.isNotEmpty) {
          urls.add(c);
        } else if (d != null && d.isNotEmpty) {
          urls.add(d);
        } else if (t != null && t.isNotEmpty) {
          urls.add(t);
        }
      } else {
        final t = article.titleAudioUrl;
        if (t != null && t.isNotEmpty) urls.add(t);
      }
    } else {
      var u = article.contentAudioUrl;
      if (u == null || u.isEmpty) u = article.descriptionAudioUrl;
      if (u != null && u.isNotEmpty) urls.add(u);
    }

    return urls.map((u) => u.trim()).where((u) => u.isNotEmpty).toList();
  }

  /// True when every URL required for playback is already on disk.
  Future<bool> isArticleAudioCachedOffline(
    NewsArticle article, {
    required bool playTitle,
    String? readingMode,
  }) async {
    final urls = playbackUrlsForArticle(
      article,
      playTitle: playTitle,
      readingMode: readingMode,
    );
    if (urls.isEmpty) return false;
    for (final url in urls) {
      if (await getCachedPath(url) == null) return false;
    }
    return true;
  }

  /// Non-null path when a valid cached file exists.
  Future<String?> getCachedPath(String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return null;
    final file = await _fileForUrl(trimmed);
    if (await file.exists()) {
      final len = await file.length();
      if (len > 0) return file.path;
      try {
        await file.delete();
      } catch (_) {}
    }
    return null;
  }

  /// Download [url] and save when online. Returns path on success.
  Future<String?> downloadAndCache(String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return null;

    final existing = await getCachedPath(trimmed);
    if (existing != null) return existing;

    if (!await ConnectivityHelper.hasConnection()) return null;

    try {
      final response = await http
          .get(Uri.parse(trimmed))
          .timeout(const Duration(seconds: 180));

      if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
        debugPrint(
          '⚠️ NewsAudioCache: HTTP ${response.statusCode} for ${trimmed.length > 80 ? trimmed.substring(0, 80) : trimmed}...',
        );
        return null;
      }

      final file = await _fileForUrl(trimmed);
      final temp = File('${file.path}.part');
      await temp.writeAsBytes(response.bodyBytes, flush: true);
      if (await temp.length() == 0) {
        try {
          await temp.delete();
        } catch (_) {}
        return null;
      }
      if (await file.exists()) {
        try {
          await file.delete();
        } catch (_) {}
      }
      await temp.rename(file.path);
      debugPrint(
        '📦 NewsAudioCache: saved ${(await file.length() ~/ 1024)} KB',
      );
      return file.path;
    } catch (e) {
      debugPrint('❌ NewsAudioCache download failed: $e');
      return null;
    }
  }

  /// Cached path, or download when online.
  Future<String?> resolveLocalPath(String url) async {
    final cached = await getCachedPath(url);
    if (cached != null) return cached;
    return downloadAndCache(url);
  }

  /// Cached file, download when online, or remote stream for just_audio.
  Future<AudioSource> resolvePlaybackSource(String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Empty audio URL');
    }

    final cachedPath = await getCachedPath(trimmed);
    if (cachedPath != null) {
      debugPrint('🎵 Playing news audio from offline cache');
      return AudioSource.uri(Uri.file(cachedPath));
    }

    if (!await ConnectivityHelper.hasConnection()) {
      throw Exception(
        'Audio is not available offline yet. While online, open the news '
        'feed and tap Listen once so audio can download for offline listening.',
      );
    }

    final downloaded = await downloadAndCache(trimmed);
    if (downloaded != null) {
      return AudioSource.uri(Uri.file(downloaded));
    }

    debugPrint('🎵 Streaming news audio (cache download skipped/failed)');
    return LockCachingAudioSource(Uri.parse(trimmed));
  }

  /// Distinct audio URLs from articles using the user reading mode (for prefetch).
  static List<String> collectAudioUrlsForReadingMode(
    List<NewsArticle> articles, {
    String? readingMode,
    int maxUrls = 60,
  }) {
    final mode = readingMode ?? StorageService.getNewsReadingMode();
    final out = <String>[];
    final seen = <String>{};

    for (final article in articles) {
      for (final url in playbackUrlsForArticle(
        article,
        playTitle: true,
        readingMode: mode,
      )) {
        if (seen.add(url) && url.isNotEmpty) {
          out.add(url);
          if (out.length >= maxUrls) return out;
        }
      }
    }
    return out;
  }

  /// Legacy: all URL types (title + description + content). Prefer [collectAudioUrlsForReadingMode].
  static List<String> collectAudioUrls(
    List<NewsArticle> articles, {
    int maxUrls = 48,
  }) {
    final out = <String>[];
    final seen = <String>{};
    for (final a in articles) {
      for (final u in [
        a.titleAudioUrl,
        a.descriptionAudioUrl,
        a.contentAudioUrl,
      ]) {
        if (u == null || u.trim().isEmpty) continue;
        final t = u.trim();
        if (seen.add(t)) {
          out.add(t);
          if (out.length >= maxUrls) return out;
        }
      }
    }
    return out;
  }

  /// Prefetch audio for articles the user is likely to play (respects reading mode).
  Future<void> prefetchArticles(
    List<NewsArticle> articles, {
    int maxUrls = 50,
    String? readingMode,
  }) async {
    if (articles.isEmpty) return;
    if (!await ConnectivityHelper.hasConnection()) return;

    final urls = collectAudioUrlsForReadingMode(
      articles,
      readingMode: readingMode,
      maxUrls: maxUrls,
    );
    if (urls.isEmpty) return;

    debugPrint(
      '📥 NewsAudioCache: prefetch ${urls.length} URL(s) (reading mode: ${readingMode ?? StorageService.getNewsReadingMode()})…',
    );

    for (final url in urls) {
      if (!await ConnectivityHelper.hasConnection()) break;
      try {
        await downloadAndCache(url);
      } catch (e) {
        debugPrint('⚠️ NewsAudioCache prefetch skip: $e');
      }
    }
  }

  /// Prefetch playlist URLs (detail mode = content/description per article).
  Future<void> prefetchPlaylist(
    List<NewsArticle> articles, {
    required bool playTitle,
    int maxUrls = 50,
  }) async {
    if (articles.isEmpty) return;
    if (!await ConnectivityHelper.hasConnection()) return;

    final seen = <String>{};
    final urls = <String>[];
    for (final a in articles) {
      for (final u in playbackUrlsForArticle(a, playTitle: playTitle)) {
        if (seen.add(u)) {
          urls.add(u);
          if (urls.length >= maxUrls) break;
        }
      }
      if (urls.length >= maxUrls) break;
    }

    for (final url in urls) {
      if (!await ConnectivityHelper.hasConnection()) break;
      await downloadAndCache(url);
    }
  }

  /// After news JSON is cached, prefetch audio from all known offline lists.
  Future<void> prefetchAllStoredNewsCaches({int maxUrls = 80}) async {
    if (!await ConnectivityHelper.hasConnection()) return;

    final byKey = <String, NewsArticle>{};
    void addAll(List<NewsArticle> list) {
      for (final a in list) {
        final key = a.articleId ?? a.title;
        byKey[key] = a;
      }
    }

    addAll(StorageService.getBreakingNewsCache());
    addAll(StorageService.getTodayNewsCache());
    addAll(StorageService.getArticlesCache());
    addAll(StorageService.getBookmarkListCache());

    if (byKey.isEmpty) return;

    debugPrint(
      '📥 NewsAudioCache: prefetch from stored news caches (${byKey.length} articles)…',
    );
    await prefetchArticles(byKey.values.toList(), maxUrls: maxUrls);
  }
}
