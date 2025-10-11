import 'package:flutter_tts/flutter_tts.dart';
import '../../core/constants/app_constants.dart';

/// Text-to-Speech Service for reading news articles
class TtsService {
  final FlutterTts _flutterTts = FlutterTts();
  bool _isInitialized = false;
  bool _isPlaying = false;
  String? _currentText;

  // Callbacks
  Function()? onStart;
  Function()? onComplete;
  Function()? onPause;
  Function()? onContinue;
  Function(String)? onError;

  TtsService() {
    _initialize();
  }

  /// Initialize TTS with default settings
  Future<void> _initialize() async {
    try {
      // Set default language
      await _flutterTts.setLanguage('en-US');

      // Set speech rate (0.0 to 1.0)
      await _flutterTts.setSpeechRate(AppConstants.defaultTtsRate);

      // Set volume (0.0 to 1.0)
      await _flutterTts.setVolume(AppConstants.defaultTtsVolume);

      // Set pitch (0.5 to 2.0)
      await _flutterTts.setPitch(AppConstants.defaultTtsPitch);

      // Set up handlers
      _flutterTts.setStartHandler(() {
        _isPlaying = true;
        onStart?.call();
      });

      _flutterTts.setCompletionHandler(() {
        _isPlaying = false;
        _currentText = null;
        onComplete?.call();
      });

      _flutterTts.setErrorHandler((msg) {
        _isPlaying = false;
        onError?.call(msg);
      });

      _flutterTts.setPauseHandler(() {
        _isPlaying = false;
        onPause?.call();
      });

      _flutterTts.setContinueHandler(() {
        _isPlaying = true;
        onContinue?.call();
      });

      _isInitialized = true;
    } catch (e) {
      onError?.call('Failed to initialize TTS: $e');
    }
  }

  /// Speak the given text
  Future<void> speak(String text) async {
    if (!_isInitialized) {
      await _initialize();
    }

    try {
      _currentText = text;
      await _flutterTts.speak(text);
    } catch (e) {
      onError?.call('Failed to speak: $e');
    }
  }

  /// Pause speaking
  Future<void> pause() async {
    try {
      await _flutterTts.pause();
      _isPlaying = false;
    } catch (e) {
      onError?.call('Failed to pause: $e');
    }
  }

  /// Stop speaking
  Future<void> stop() async {
    try {
      await _flutterTts.stop();
      _isPlaying = false;
      _currentText = null;
    } catch (e) {
      onError?.call('Failed to stop: $e');
    }
  }

  /// Set speech rate (0.0 to 1.0)
  Future<void> setSpeechRate(double rate) async {
    try {
      await _flutterTts.setSpeechRate(rate);
    } catch (e) {
      onError?.call('Failed to set speech rate: $e');
    }
  }

  /// Set volume (0.0 to 1.0)
  Future<void> setVolume(double volume) async {
    try {
      await _flutterTts.setVolume(volume);
    } catch (e) {
      onError?.call('Failed to set volume: $e');
    }
  }

  /// Set pitch (0.5 to 2.0)
  Future<void> setPitch(double pitch) async {
    try {
      await _flutterTts.setPitch(pitch);
    } catch (e) {
      onError?.call('Failed to set pitch: $e');
    }
  }

  /// Set language
  Future<void> setLanguage(String language) async {
    try {
      await _flutterTts.setLanguage(language);
    } catch (e) {
      onError?.call('Failed to set language: $e');
    }
  }

  /// Get available languages
  Future<List<String>> getLanguages() async {
    try {
      final languages = await _flutterTts.getLanguages;
      return List<String>.from(languages);
    } catch (e) {
      onError?.call('Failed to get languages: $e');
      return [];
    }
  }

  /// Get available voices
  Future<List<Map>> getVoices() async {
    try {
      final voices = await _flutterTts.getVoices;
      return List<Map>.from(voices);
    } catch (e) {
      onError?.call('Failed to get voices: $e');
      return [];
    }
  }

  /// Check if TTS is currently speaking
  bool get isPlaying => _isPlaying;

  /// Get current text being spoken
  String? get currentText => _currentText;

  /// Dispose resources
  void dispose() {
    _flutterTts.stop();
  }
}
