import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Holds successfully loaded [BannerAd]s so feed slots can re-show the last
/// good creative after scroll-away / brief rebuilds — without inventing fake ads.
///
/// Caps memory (WebViews) via LRU eviction of **detached** entries only.
class LiveBannerAdCache {
  LiveBannerAdCache._();
  static final LiveBannerAdCache instance = LiveBannerAdCache._();

  /// Soft cap: enough for a typical session without stacking dozens of WebViews.
  static const int maxEntries = 6;

  final LinkedHashMap<String, LiveBannerAdEntry> _entries = LinkedHashMap();
  final Set<String> _attached = <String>{};

  /// Re-attach a previously loaded creative for [id], if still cached.
  LiveBannerAdEntry? adopt(String id) {
    final entry = _entries.remove(id);
    if (entry == null) return null;
    _entries[id] = entry; // refresh LRU
    _attached.add(id);
    return entry;
  }

  /// Register a freshly loaded creative. Replaces any prior entry for [id].
  void store(String id, BannerAd ad, AdSize size) {
    final previous = _entries.remove(id);
    if (previous != null && !identical(previous.ad, ad)) {
      // Old creative for this slot is obsolete.
      _safeDispose(previous.ad);
    }
    _entries[id] = LiveBannerAdEntry(ad: ad, size: size);
    _attached.add(id);
    _evictIfNeeded();
  }

  /// Widget still owns the [AdWidget]; keep the entry cached for later adopt.
  void detach(String id) {
    _attached.remove(id);
  }

  /// Drop and dispose — e.g. slot identity changed or ads disabled.
  void release(String id) {
    _attached.remove(id);
    final entry = _entries.remove(id);
    if (entry != null) _safeDispose(entry.ad);
  }

  void _evictIfNeeded() {
    while (_entries.length > maxEntries) {
      String? victim;
      for (final key in _entries.keys) {
        if (!_attached.contains(key)) {
          victim = key;
          break;
        }
      }
      // Never dispose an ad that is currently on-screen.
      if (victim == null) break;
      final entry = _entries.remove(victim);
      if (entry != null) {
        debugPrint('♻️ LiveBannerAdCache evicted $victim');
        _safeDispose(entry.ad);
      }
    }
  }

  void _safeDispose(BannerAd ad) {
    try {
      ad.dispose();
    } catch (_) {}
  }
}

class LiveBannerAdEntry {
  const LiveBannerAdEntry({required this.ad, required this.size});

  final BannerAd ad;
  final AdSize size;
}
