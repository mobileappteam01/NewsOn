import 'package:speech_to_text/speech_to_text.dart';

/// Locale name used by voice search (decoupled from speech_to_text types
/// for fakeable tests).
class SpeechLocaleInfo {
  const SpeechLocaleInfo({required this.localeId, required this.name});
  final String localeId;
  final String name;
}

/// Minimal speech recognition engine.
///
/// Production: [SpeechToTextEngine]
/// Tests: FakeSpeechRecognitionEngine (test/)
abstract class SpeechRecognitionEngine {
  Future<bool> initialize({
    void Function(String errorMsg)? onError,
    void Function(String status)? onStatus,
  });

  Future<void> listen({
    required void Function(String words, bool isFinal) onResult,
    required Duration listenFor,
    required Duration pauseFor,
    void Function(double level)? onSoundLevelChange,
  });

  Future<void> stop();
  Future<void> cancel();
  Future<List<SpeechLocaleInfo>> locales();
  bool get isAvailable;
}

/// Production wrapper around [SpeechToText].
class SpeechToTextEngine implements SpeechRecognitionEngine {
  SpeechToTextEngine({SpeechToText? speechToText})
      : _speech = speechToText ?? SpeechToText();

  final SpeechToText _speech;

  @override
  Future<bool> initialize({
    void Function(String errorMsg)? onError,
    void Function(String status)? onStatus,
  }) {
    return _speech.initialize(
      onError: (error) => onError?.call(error.errorMsg),
      onStatus: (status) => onStatus?.call(status),
    );
  }

  @override
  Future<void> listen({
    required void Function(String words, bool isFinal) onResult,
    required Duration listenFor,
    required Duration pauseFor,
    void Function(double level)? onSoundLevelChange,
  }) {
    return _speech.listen(
      onResult: (result) =>
          onResult(result.recognizedWords, result.finalResult),
      listenFor: listenFor,
      pauseFor: pauseFor,
      listenOptions: SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
        listenMode: ListenMode.dictation,
        autoPunctuation: true,
      ),
      onSoundLevelChange: onSoundLevelChange,
    );
  }

  @override
  Future<void> stop() => _speech.stop();

  @override
  Future<void> cancel() => _speech.cancel();

  @override
  Future<List<SpeechLocaleInfo>> locales() async {
    final list = await _speech.locales();
    return list
        .map((l) => SpeechLocaleInfo(localeId: l.localeId, name: l.name))
        .toList();
  }

  @override
  bool get isAvailable => _speech.isAvailable;
}
