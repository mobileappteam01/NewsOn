import 'dart:math';

/// Owns a stable [sessionId] for the current app session (Phase 1D contract).
///
/// Mobile generates the ID. Authenticated userId is derived by the backend from JWT
/// and must not be required in analytics payloads from the client.
class AnalyticsSession {
  AnalyticsSession._();
  static final AnalyticsSession instance = AnalyticsSession._();

  String? _sessionId;
  DateTime? _startedAt;

  String get sessionId {
    _sessionId ??= _createSessionId();
    _startedAt ??= DateTime.now().toUtc();
    return _sessionId!;
  }

  DateTime? get startedAt => _startedAt;

  /// Call once at meaningful app session start (e.g. after MaterialApp mounts).
  String startSession({bool forceNew = false}) {
    if (forceNew || _sessionId == null) {
      _sessionId = _createSessionId();
      _startedAt = DateTime.now().toUtc();
    }
    return _sessionId!;
  }

  /// Rotate only at actual session boundaries (logout / long background, etc.).
  void endSession() {
    _sessionId = null;
    _startedAt = null;
  }

  String _createSessionId() {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final rand = Random.secure().nextInt(1 << 32).toRadixString(16);
    return 'sess_${now}_$rand';
  }
}
