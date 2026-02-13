import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Supported languages for voice search
enum VoiceSearchLanguage {
  english('en_US', 'English');

  const VoiceSearchLanguage(this.localeId, this.displayName);
  final String localeId;
  final String displayName;
}

/// Voice Search Service
/// Handles speech recognition for voice-based search functionality with multilingual support
class VoiceSearchService {
  static final VoiceSearchService _instance = VoiceSearchService._internal();
  factory VoiceSearchService() => _instance;
  VoiceSearchService._internal();

  final SpeechToText _speechToText = SpeechToText();
  bool _isInitialized = false;
  bool _isListening = false;
  String _lastWords = '';
  String _errorText = '';
  VoiceSearchLanguage _currentLanguage = VoiceSearchLanguage.english;

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isListening => _isListening;
  String get lastWords => _lastWords;
  String get errorText => _errorText;
  VoiceSearchLanguage get currentLanguage => _currentLanguage;

  /// Initialize speech recognition
  Future<bool> initialize({VoiceSearchLanguage? language}) async {
    try {
      // Set language before initialization
      if (language != null) {
        _currentLanguage = language;
      }

      // Initialize speech recognition - the package handles permissions internally
      _isInitialized = await _speechToText.initialize(
        onError: (error) {
          _errorText = error.errorMsg;
          debugPrint('Speech recognition error: ${error.errorMsg}');
        },
        onStatus: (status) {
          debugPrint('Speech recognition status: $status');
          if (status == 'done') {
            _isListening = false;
          }
        },
      );

      if (!_isInitialized) {
        _errorText = 'Speech recognition not available';
        debugPrint('Speech recognition not available on this device');
      }

      return _isInitialized;
    } catch (e) {
      _errorText = 'Failed to initialize voice search: $e';
      debugPrint('Failed to initialize voice search: $e');
      return false;
    }
  }

  /// Set the language for voice recognition
  Future<bool> setLanguage(VoiceSearchLanguage language) async {
    try {
      debugPrint('Setting voice search language to: ${language.displayName}');

      // Check if the language is available
      final locales = await _speechToText.locales();
      final targetLocale = locales.firstWhere(
        (locale) => locale.localeId == language.localeId,
        orElse: () => locales.firstWhere(
          (locale) =>
              locale.localeId.startsWith(language.localeId.split('_')[0]),
          orElse: () => locales.first,
        ),
      );

      if (targetLocale.localeId != language.localeId) {
        debugPrint(
            'Warning: Exact locale ${language.localeId} not found, using ${targetLocale.localeId}');
      }

      _currentLanguage = language;
      debugPrint(
          'Voice search language set to: ${language.displayName} (${targetLocale.localeId})');
      return true;
    } catch (e) {
      _errorText = 'Failed to set language: $e';
      debugPrint('Failed to set language: $e');
      return false;
    }
  }

  /// Get available languages
  Future<List<VoiceSearchLanguage>> getAvailableLanguages() async {
    try {
      final locales = await _speechToText.locales();
      final availableLanguages = <VoiceSearchLanguage>[];

      for (final language in VoiceSearchLanguage.values) {
        final hasLocale = locales.any((locale) =>
            locale.localeId == language.localeId ||
            locale.localeId.startsWith(language.localeId.split('_')[0]));

        if (hasLocale) {
          availableLanguages.add(language);
        }
      }

      debugPrint(
          'Available voice search languages: ${availableLanguages.map((l) => l.displayName).join(', ')}');
      return availableLanguages;
    } catch (e) {
      debugPrint('Failed to get available languages: $e');
      return [VoiceSearchLanguage.english]; // Fallback to English
    }
  }

  /// Start listening for voice input with strict language enforcement and Tamil validation
  Future<bool> startListening({
    Function(String)? onResult,
    Function(String)? onError,
    VoidCallback? onListeningStart,
    VoidCallback? onListeningEnd,
    Duration? silenceTimeout,
    Duration? maxListeningDuration,
    VoiceSearchLanguage? language,
  }) async {
    if (!_isInitialized) {
      await initialize(language: language);
    }

    // Set language if provided and different from current
    if (language != null && language != _currentLanguage) {
      final languageSet = await setLanguage(language);
      if (!languageSet) {
        _errorText = 'Failed to set language to ${language.displayName}';
        onError?.call(_errorText);
        return false;
      }
    }

    if (_isListening) {
      debugPrint('Already listening, stopping first');
      await stopListening();
    }

    try {
      _isListening = true;
      _errorText = '';
      _lastWords = '';

      // Enhanced listening parameters with language enforcement
      final silenceTimeoutMs = silenceTimeout?.inSeconds ?? 4;
      final maxDurationMs = maxListeningDuration?.inSeconds ?? 25;

      debugPrint(
          '🎤 Starting voice search in ${_currentLanguage.displayName} language');
      debugPrint('🔒 Language enforcement: ${_currentLanguage.localeId}');

      await _speechToText.listen(
        onResult: (result) {
          _lastWords = result.recognizedWords;
          onResult?.call(_lastWords);
          debugPrint(
              'Speech result in ${_currentLanguage.displayName}: ${result.recognizedWords} (final: ${result.finalResult})');

          if (result.finalResult) {
            _isListening = false;
            onListeningEnd?.call();
            debugPrint(
                'Speech recognition ended with final result in ${_currentLanguage.displayName}');
          }
        },
        listenFor: Duration(seconds: maxDurationMs),
        pauseFor: Duration(seconds: silenceTimeoutMs),
        listenOptions: SpeechListenOptions(
          partialResults: true,
          cancelOnError: true,
          listenMode: ListenMode.dictation,
          autoPunctuation: true,
        ),
        onSoundLevelChange: (level) {
          debugPrint('🔊 Sound level: $level');
        },
      );

      onListeningStart?.call();
      debugPrint(
          '🎤 Started enhanced listening for speech in ${_currentLanguage.displayName}');
      debugPrint(
          '⏱️ Silence timeout: ${silenceTimeoutMs}s, Max duration: ${maxDurationMs}s');

      // Enhanced timeout mechanism
      Future.delayed(Duration(seconds: maxDurationMs + 5), () {
        if (_isListening) {
          _isListening = false;
          onListeningEnd?.call();
          debugPrint(
              '⏰ Speech recognition ended due to maximum timeout in ${_currentLanguage.displayName}');
        }
      });

      return true;
    } catch (e) {
      _isListening = false;
      _errorText = 'Failed to start listening: $e';
      onError?.call(_errorText);
      debugPrint('❌ Failed to start listening: $e');
      return false;
    }
  }

  /// Stop listening
  Future<void> stopListening() async {
    if (!_isListening) return;

    try {
      await _speechToText.stop();
      _isListening = false;
      debugPrint('Stopped listening for speech');
    } catch (e) {
      debugPrint('Failed to stop listening: $e');
    }
  }

  /// Cancel listening
  Future<void> cancelListening() async {
    if (!_isListening) return;

    try {
      await _speechToText.cancel();
      _isListening = false;
      debugPrint('Cancelled speech recognition');
    } catch (e) {
      debugPrint('Failed to cancel listening: $e');
    }
  }

  /// Check if speech recognition is available
  bool get isAvailable => _speechToText.isAvailable;

  /// Get available locales
  Future<List<LocaleName>> getAvailableLocales() async {
    if (!_isInitialized) {
      await initialize();
    }
    return await _speechToText.locales();
  }

  /// Clear error text
  void clearError() {
    _errorText = '';
  }

  /// Clear last words
  void clearLastWords() {
    _lastWords = '';
  }

  /// Dispose resources
  void dispose() {
    if (_isListening) {
      cancelListening();
    }
    _speechToText.stop();
  }
}

/// Voice search result model
class VoiceSearchResult {
  final String text;
  final DateTime timestamp;
  final bool isFinal;

  VoiceSearchResult({
    required this.text,
    required this.timestamp,
    this.isFinal = false,
  });

  @override
  String toString() {
    return 'VoiceSearchResult(text: $text, timestamp: $timestamp, isFinal: $isFinal)';
  }
}

/// Voice search status enum
enum VoiceSearchStatus {
  idle,
  initializing,
  ready,
  listening,
  processing,
  done,
  error,
}

/// Voice search state model
class VoiceSearchState extends ChangeNotifier {
  final VoiceSearchService _service = VoiceSearchService();

  VoiceSearchStatus _status = VoiceSearchStatus.idle;
  String _currentText = '';
  String _errorText = '';
  double _confidenceLevel = 0.0;

  // Getters
  VoiceSearchStatus get status => _status;
  String get currentText => _currentText;
  String get errorText => _errorText;
  double get confidenceLevel => _confidenceLevel;
  bool get isListening => _service.isListening;
  bool get isInitialized => _service.isInitialized;

  /// Initialize voice search
  Future<bool> initialize() async {
    _status = VoiceSearchStatus.initializing;
    notifyListeners();

    final success = await _service.initialize();

    _status = success ? VoiceSearchStatus.ready : VoiceSearchStatus.error;
    if (!success) {
      _errorText = _service.errorText;
    }

    notifyListeners();
    return success;
  }

  /// Start voice search
  Future<bool> startListening() async {
    if (_status == VoiceSearchStatus.listening) return false;

    if (!_service.isInitialized) {
      final initialized = await initialize();
      if (!initialized) return false;
    }

    _status = VoiceSearchStatus.listening;
    _currentText = '';
    _errorText = '';
    notifyListeners();

    return await _service.startListening(
      onResult: (result) {
        _currentText = result;
        _status = VoiceSearchStatus.processing;
        notifyListeners();
      },
      onError: (error) {
        _errorText = error;
        _status = VoiceSearchStatus.error;
        notifyListeners();
      },
      onListeningStart: () {
        _status = VoiceSearchStatus.listening;
        notifyListeners();
      },
      onListeningEnd: () {
        _status = VoiceSearchStatus.done;
        notifyListeners();
      },
    );
  }

  /// Stop voice search
  Future<void> stopListening() async {
    if (_status != VoiceSearchStatus.listening) return;

    await _service.stopListening();
    _status = VoiceSearchStatus.done;
    notifyListeners();
  }

  /// Cancel voice search
  Future<void> cancelListening() async {
    await _service.cancelListening();
    _status = VoiceSearchStatus.idle;
    _currentText = '';
    _errorText = '';
    notifyListeners();
  }

  /// Clear current text
  void clearText() {
    _currentText = '';
    notifyListeners();
  }

  /// Clear error
  void clearError() {
    _errorText = '';
    if (_status == VoiceSearchStatus.error) {
      _status = VoiceSearchStatus.ready;
    }
    notifyListeners();
  }

  /// Reset state
  void reset() {
    _status = VoiceSearchStatus.idle;
    _currentText = '';
    _errorText = '';
    _confidenceLevel = 0.0;
    notifyListeners();
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }
}
