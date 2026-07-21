import 'dart:io';

import 'package:flutter/foundation.dart';

/// Detects DNS / VPN / Private-DNS ad blockers that make AdMob fail with
/// "Unable to obtain a JavascriptEngine" (hosts resolve to 127.0.0.1).
class AdNetworkDiagnostics {
  AdNetworkDiagnostics._();

  static bool? _adsBlocked;
  static bool _logged = false;

  static bool get isLikelyBlocked => _adsBlocked == true;

  /// Returns true if Google ad hosts appear DNS-sinkholed (AdGuard, etc.).
  static Future<bool> checkAdsReachable() async {
    if (_adsBlocked != null) return !_adsBlocked!;

    const hosts = [
      'googleads.g.doubleclick.net',
      'pagead2.googlesyndication.com',
    ];

    for (final host in hosts) {
      try {
        final addresses = await InternetAddress.lookup(host)
            .timeout(const Duration(seconds: 3));
        if (addresses.isEmpty) {
          _adsBlocked = true;
          _logOnce();
          return false;
        }
        final sinkholed = addresses.every(
          (a) => a.isLoopback || a.address == '0.0.0.0',
        );
        if (sinkholed) {
          _adsBlocked = true;
          _logOnce();
          return false;
        }
      } catch (_) {
        // Lookup failure alone is inconclusive (transient DNS).
      }
    }

    _adsBlocked = false;
    return true;
  }

  static Future<void> reportJavascriptEngineFailure() async {
    await checkAdsReachable();
    _logOnce();
  }

  static void _logOnce() {
    if (_logged) return;
    _logged = true;
    if (_adsBlocked == true) {
      debugPrint(
        '🚫 AdMob blocked on this device: Google ad domains resolve to '
        'localhost (typical of Private DNS → AdGuard / NextDNS / ad blockers).\n'
        '   Fix: Settings → Network & internet → Private DNS → Off '
        '(or Automatic). Also disable VPN / AdGuard.\n'
        '   Verified host: googleads.g.doubleclick.net → 127.0.0.1 means ads '
        'cannot load — this is NOT an app bug.',
      );
    } else {
      debugPrint(
        '⚠️ AdMob JavascriptEngine failure — if ads keep failing, check '
        'Private DNS / VPN / ad blockers on the device.',
      );
    }
  }
}
