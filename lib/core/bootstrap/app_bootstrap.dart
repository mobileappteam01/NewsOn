import 'dart:async';

/// Gates cold-start work so UI can paint first, and deep links wait until
/// configs / API are ready.
class AppBootstrap {
  AppBootstrap._();

  static final Completer<void> _completer = Completer<void>();
  static bool _started = false;

  static bool get isReady => _completer.isCompleted;

  static Future<void> get whenReady => _completer.future;

  /// Wait until ready, or [timeout] — never throw when timed out.
  static Future<bool> waitForReady({
    Duration timeout = const Duration(seconds: 12),
  }) async {
    if (isReady) return true;
    try {
      await whenReady.timeout(timeout);
      return true;
    } catch (_) {
      return isReady;
    }
  }

  static void markStarted() {
    _started = true;
  }

  static bool get hasStarted => _started;

  static void markReady() {
    if (!_completer.isCompleted) {
      _completer.complete();
    }
  }
}
