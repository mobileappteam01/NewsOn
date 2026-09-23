import 'package:newson/core/services/speech_recognition_engine.dart';

/// Deterministic speech engine for VM unit tests — no native plugin.
class FakeSpeechRecognitionEngine implements SpeechRecognitionEngine {
  FakeSpeechRecognitionEngine({
    this.initializeSucceeds = true,
    this.availableLocales = const [
      SpeechLocaleInfo(localeId: 'en_US', name: 'English (US)'),
    ],
  });

  bool initializeSucceeds;
  List<SpeechLocaleInfo> availableLocales;

  bool initialized = false;
  bool listening = false;
  int initializeCalls = 0;
  int listenCalls = 0;
  int stopCalls = 0;
  int cancelCalls = 0;
  String? lastError;

  void Function(String words, bool isFinal)? _onResult;
  void Function(String status)? _onStatus;

  @override
  Future<bool> initialize({
    void Function(String errorMsg)? onError,
    void Function(String status)? onStatus,
  }) async {
    initializeCalls++;
    _onStatus = onStatus;
    if (!initializeSucceeds) {
      lastError = 'unavailable';
      onError?.call(lastError!);
      initialized = false;
      return false;
    }
    initialized = true;
    return true;
  }

  @override
  Future<void> listen({
    required void Function(String words, bool isFinal) onResult,
    required Duration listenFor,
    required Duration pauseFor,
    void Function(double level)? onSoundLevelChange,
  }) async {
    listenCalls++;
    listening = true;
    _onResult = onResult;
  }

  /// Simulate a recognition result (partial or final).
  void emitResult(String words, {bool isFinal = false}) {
    _onResult?.call(words, isFinal);
    if (isFinal) {
      listening = false;
      _onStatus?.call('done');
    }
  }

  /// Simulate an engine error.
  void emitError(String message) {
    lastError = message;
  }

  @override
  Future<void> stop() async {
    stopCalls++;
    listening = false;
  }

  @override
  Future<void> cancel() async {
    cancelCalls++;
    listening = false;
  }

  @override
  Future<List<SpeechLocaleInfo>> locales() async => availableLocales;

  @override
  bool get isAvailable => initialized && initializeSucceeds;
}
