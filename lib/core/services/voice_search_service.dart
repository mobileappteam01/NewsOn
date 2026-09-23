import 'package:flutter/foundation.dart';

import 'speech_recognition_engine.dart';

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
  static final VoiceSearchService _instance =
      VoiceSearchService._(SpeechToTextEngine());

  factory VoiceSearchService() => _testOverride ?? _instance;

  VoiceSearchService._(this._engine);

  /// Test/DI constructor — does not replace the production singleton.
  @visibleForTesting
  factory VoiceSearchService.withEngine(SpeechRecognitionEngine engine) {
    return VoiceSearchService._(engine);
  }

  static VoiceSearchService? _testOverride;

  /// Override the singleton for tests. Pass null to restore production.
  @visibleForTesting
  static void debugOverrideInstance(VoiceSearchService? instance) {
    _testOverride = instance;
  }

  final SpeechRecognitionEngine _engine;
  bool _isInitialized = false;
  bool _isListening = false;
  String _lastWords = '';
  String _errorText = '';
  VoiceSearchLanguage _currentLanguage = VoiceSearchLanguage.english;

  bool get isInitialized => _isInitialized;
  bool get isListening => _isListening;
  String get lastWords => _lastWords;
  String get errorText => _errorText;
  VoiceSearchLanguage get currentLanguage => _currentLanguage;

  /// Initialize speech recognition
  Future<bool> initialize({VoiceSearchLanguage? language}) async {
    try {
      if (language != null) {
        _currentLanguage = language;
      }

      _isInitialized = await _engine.initialize(
        onError: (errorMsg) {
          _errorText = errorMsg;
          debugPrint('Speech recognition error: $errorMsg');
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

      final locales = await _engine.locales();
      final targetLocale = locales.firstWhere(
        (locale) => locale.localeId == language.localeId,
        orElse: () => locales.firstWhere(
          (locale) =>
              locale.localeId.startsWith(language.localeId.split('_')[0]),
          orElse: () => locales.isNotEmpty
              ? locales.first
              : SpeechLocaleInfo(
                  localeId: language.localeId,
                  name: language.displayName,
                ),
        ),
      );

      if (targetLocale.localeId != language.localeId) {
        debugPrint(
          'Warning: Exact locale ${language.localeId} not found, using ${targetLocale.localeId}',
        );
      }

      _currentLanguage = language;
      debugPrint(
        'Voice search language set to: ${language.displayName} (${targetLocale.localeId})',
      );
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
      final locales = await _engine.locales();
      final availableLanguages = <VoiceSearchLanguage>[];

      for (final language in VoiceSearchLanguage.values) {
        final hasLocale = locales.any(
          (locale) =>
              locale.localeId == language.localeId ||
              locale.localeId.startsWith(language.localeId.split('_')[0]),
        );

        if (hasLocale) {
          availableLanguages.add(language);
        }
      }

      debugPrint(
        'Available voice search languages: ${availableLanguages.map((l) => l.displayName).join(', ')}',
      );
      return availableLanguages;
    } catch (e) {
      debugPrint('Failed to get available languages: $e');
      return [VoiceSearchLanguage.english];
    }
  }

  /// Start listening for voice input with language enforcement
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

      final silenceTimeoutMs = silenceTimeout?.inSeconds ?? 4;
      final maxDurationMs = maxListeningDuration?.inSeconds ?? 25;

      debugPrint(
        '🎤 Starting voice search in ${_currentLanguage.displayName} language',
      );
      debugPrint('🔒 Language enforcement: ${_currentLanguage.localeId}');

      await _engine.listen(
        onResult: (words, isFinal) {
          _lastWords = words;
          onResult?.call(_lastWords);
          debugPrint(
            'Speech result in ${_currentLanguage.displayName}: $words (final: $isFinal)',
          );

          if (isFinal) {
            _isListening = false;
            onListeningEnd?.call();
            debugPrint(
              'Speech recognition ended with final result in ${_currentLanguage.displayName}',
            );
          }
        },
        listenFor: Duration(seconds: maxDurationMs),
        pauseFor: Duration(seconds: silenceTimeoutMs),
        onSoundLevelChange: (level) {
          debugPrint('🔊 Sound level: $level');
        },
      );

      onListeningStart?.call();
      debugPrint(
        '🎤 Started enhanced listening for speech in ${_currentLanguage.displayName}',
      );
      debugPrint(
        '⏱️ Silence timeout: ${silenceTimeoutMs}s, Max duration: ${maxDurationMs}s',
      );

      Future.delayed(Duration(seconds: maxDurationMs + 5), () {
        if (_isListening) {
          _isListening = false;
          onListeningEnd?.call();
          debugPrint(
            '⏰ Speech recognition ended due to maximum timeout in ${_currentLanguage.displayName}',
          );
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

  Future<void> stopListening() async {
    if (!_isListening) return;

    try {
      await _engine.stop();
      _isListening = false;
      debugPrint('Stopped listening for speech');
    } catch (e) {
      debugPrint('Failed to stop listening: $e');
    }
  }

  Future<void> cancelListening() async {
    if (!_isListening) return;

    try {
      await _engine.cancel();
      _isListening = false;
      debugPrint('Cancelled speech recognition');
    } catch (e) {
      debugPrint('Failed to cancel listening: $e');
    }
  }

  bool get isAvailable => _engine.isAvailable;

  Future<List<SpeechLocaleInfo>> getAvailableLocales() async {
    if (!_isInitialized) {
      await initialize();
    }
    return _engine.locales();
  }

  void clearError() {
    _errorText = '';
  }

  void clearLastWords() {
    _lastWords = '';
  }

  void dispose() {
    if (_isListening) {
      cancelListening();
    }
    _engine.stop();
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
  VoiceSearchState({VoiceSearchService? service})
      : _service = service ?? VoiceSearchService();

  final VoiceSearchService _service;

  VoiceSearchStatus _status = VoiceSearchStatus.idle;
  String _currentText = '';
  String _errorText = '';
  double _confidenceLevel = 0.0;

  VoiceSearchStatus get status => _status;
  String get currentText => _currentText;
  String get errorText => _errorText;
  double get confidenceLevel => _confidenceLevel;
  bool get isListening => _service.isListening;
  bool get isInitialized => _service.isInitialized;

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

    return _service.startListening(
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

  Future<void> stopListening() async {
    if (_status != VoiceSearchStatus.listening) return;

    await _service.stopListening();
    _status = VoiceSearchStatus.done;
    notifyListeners();
  }

  Future<void> cancelListening() async {
    await _service.cancelListening();
    _status = VoiceSearchStatus.idle;
    _currentText = '';
    _errorText = '';
    notifyListeners();
  }

  void clearText() {
    _currentText = '';
    notifyListeners();
  }

  void clearError() {
    _errorText = '';
    if (_status == VoiceSearchStatus.error) {
      _status = VoiceSearchStatus.ready;
    }
    notifyListeners();
  }

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
