import 'package:flutter/foundation.dart';
import '../data/models/news_article.dart';
import '../data/services/tts_service.dart';

/// Provider for managing Text-to-Speech functionality
class TtsProvider with ChangeNotifier {
  final TtsService _ttsService = TtsService();

  bool _isPlaying = false;
  bool _isPaused = false;
  NewsArticle? _currentArticle;
  double _speechRate = 0.5;
  double _pitch = 1.0;
  double _volume = 1.0;

  TtsProvider() {
    _initializeTts();
  }

  // Getters
  bool get isPlaying => _isPlaying;
  bool get isPaused => _isPaused;
  NewsArticle? get currentArticle => _currentArticle;
  double get speechRate => _speechRate;
  double get pitch => _pitch;
  double get volume => _volume;

  /// Initialize TTS service with callbacks
  void _initializeTts() {
    _ttsService.onStart = () {
      _isPlaying = true;
      _isPaused = false;
      notifyListeners();
    };

    _ttsService.onComplete = () {
      _isPlaying = false;
      _isPaused = false;
      _currentArticle = null;
      notifyListeners();
    };

    _ttsService.onPause = () {
      _isPaused = true;
      _isPlaying = false;
      notifyListeners();
    };

    _ttsService.onContinue = () {
      _isPaused = false;
      _isPlaying = true;
      notifyListeners();
    };

    _ttsService.onError = (error) {
      _isPlaying = false;
      _isPaused = false;
      debugPrint('TTS Error: $error');
      notifyListeners();
    };
  }

  /// Play/Read news article
  Future<void> playArticle(NewsArticle article) async {
    try {
      _currentArticle = article;
      
      // Prepare text to speak
      final textToSpeak = _prepareTextForSpeech(article);
      
      await _ttsService.speak(textToSpeak);
    } catch (e) {
      debugPrint('Error playing article: $e');
      _isPlaying = false;
      _currentArticle = null;
      notifyListeners();
    }
  }

  /// Prepare article text for speech
  String _prepareTextForSpeech(NewsArticle article) {
    final buffer = StringBuffer();
    
    // Add title
    buffer.write(article.title);
    buffer.write('. ');
    
    // Add author if available
    if (article.creator != null && article.creator!.isNotEmpty) {
      buffer.write('By ${article.creator!.first}. ');
    }
    
    // Add description or content
    if (article.content != null && article.content!.isNotEmpty) {
      buffer.write(article.content);
    } else if (article.description != null && article.description!.isNotEmpty) {
      buffer.write(article.description);
    }
    
    return buffer.toString();
  }

  /// Pause speech
  Future<void> pause() async {
    await _ttsService.pause();
  }

  /// Stop speech
  Future<void> stop() async {
    await _ttsService.stop();
    _isPlaying = false;
    _isPaused = false;
    _currentArticle = null;
    notifyListeners();
  }

  /// Resume speech (for articles that support it)
  Future<void> resume() async {
    if (_currentArticle != null && _isPaused) {
      await playArticle(_currentArticle!);
    }
  }

  /// Set speech rate
  Future<void> setSpeechRate(double rate) async {
    _speechRate = rate;
    await _ttsService.setSpeechRate(rate);
    notifyListeners();
  }

  /// Set pitch
  Future<void> setPitch(double pitch) async {
    _pitch = pitch;
    await _ttsService.setPitch(pitch);
    notifyListeners();
  }

  /// Set volume
  Future<void> setVolume(double volume) async {
    _volume = volume;
    await _ttsService.setVolume(volume);
    notifyListeners();
  }

  /// Toggle play/pause
  Future<void> togglePlayPause() async {
    if (_isPlaying) {
      await pause();
    } else if (_isPaused && _currentArticle != null) {
      await resume();
    }
  }

  /// Check if specific article is currently playing
  bool isArticlePlaying(NewsArticle article) {
    if (_currentArticle == null) return false;
    final currentKey = _currentArticle!.articleId ?? _currentArticle!.title;
    final articleKey = article.articleId ?? article.title;
    return currentKey == articleKey && _isPlaying;
  }

  @override
  void dispose() {
    _ttsService.dispose();
    super.dispose();
  }
}
