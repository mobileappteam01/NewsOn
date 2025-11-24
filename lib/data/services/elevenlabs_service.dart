import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// ElevenLabs Text-to-Speech Service
/// Converts text to speech using ElevenLabs API and returns audio stream/URL
class ElevenLabsService {
  final Dio _dio = Dio();
  String? _apiKey;
  final String _baseUrl = 'https://api.elevenlabs.io/v1';

  // Default voice ID (you can make this configurable)
  String _defaultVoiceId = '21m00Tcm4TlvDq8ikWAM'; // Rachel - default voice

  ElevenLabsService({String? apiKey}) {
    _apiKey = apiKey;
    _setupDio();
  }

  void _setupDio() {
    _dio.options.baseUrl = _baseUrl;
    _dio.options.connectTimeout = const Duration(seconds: 30);
    _dio.options.receiveTimeout = const Duration(seconds: 60);
    _dio.options.headers = {
      'Content-Type': 'application/json',
      'Accept': 'audio/mpeg',
    };
  }

  /// Set API key
  void setApiKey(String apiKey) {
    _apiKey = apiKey;
  }

  /// Set voice ID
  void setVoiceId(String voiceId) {
    _defaultVoiceId = voiceId;
  }

  /// Convert text to speech and return audio URL or stream
  /// Returns the audio data as Uint8List for direct playback
  Future<Uint8List> textToSpeech({
    required String text,
    String? voiceId,
    double stability = 0.5,
    double similarityBoost = 0.75,
    double style = 0.0,
    bool useSpeakerBoost = true,
  }) async {
    if (_apiKey == null || _apiKey!.isEmpty) {
      throw Exception(
        'ElevenLabs API key is not set. Please configure your API key in main.dart',
      );
    }

    if (text.isEmpty) {
      throw Exception('Text to convert is empty');
    }

    try {
      final voice = voiceId ?? _defaultVoiceId;

      debugPrint(
        '🔊 Calling ElevenLabs API with voice: $voice, text length: ${text.length}',
      );

      // Build endpoint with output_format query parameter (official API format)
      final endpoint = '/text-to-speech/$voice?output_format=mp3_44100_128';

      // Request body matching official API format
      final requestBody = <String, dynamic>{
        'text': text,
        'model_id': 'eleven_multilingual_v2',
      };

      // Add voice_settings only if custom values are provided (optional in official API)
      if (stability != 0.5 ||
          similarityBoost != 0.75 ||
          style != 0.0 ||
          !useSpeakerBoost) {
        requestBody['voice_settings'] = <String, dynamic>{
          'stability': stability,
          'similarity_boost': similarityBoost,
          'style': style,
          'use_speaker_boost': useSpeakerBoost,
        };
      }

      final response = await _dio.post(
        endpoint,
        data: requestBody,
        options: Options(
          headers: {
            'xi-api-key': _apiKey!,
            'Content-Type': 'application/json',
            'Accept': 'audio/mpeg',
          },
          responseType: ResponseType.bytes,
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        return Uint8List.fromList(response.data);
      } else {
        throw Exception('Failed to generate speech: ${response.statusCode}');
      }
    } on DioException catch (e) {
      debugPrint('❌ ElevenLabs API Error: ${e.type}');
      debugPrint('Status Code: ${e.response?.statusCode}');
      debugPrint('Response: ${e.response?.data}');

      if (e.response != null) {
        final errorData = e.response?.data;
        String errorMessage = 'Failed to generate speech';

        if (errorData is Map) {
          // Try different error message formats from ElevenLabs API
          errorMessage =
              errorData['detail']?['message'] ??
              errorData['detail']?.toString() ??
              errorData['message'] ??
              errorData['error']?.toString() ??
              errorMessage;
        } else if (errorData is String) {
          errorMessage = errorData;
        }

        // Add status code info
        final statusCode = e.response?.statusCode;
        if (statusCode == 401) {
          errorMessage =
              'Invalid API key. Please check your ElevenLabs API key.';
        } else if (statusCode == 429) {
          errorMessage = 'API rate limit exceeded. Please try again later.';
        } else if (statusCode == 400) {
          errorMessage = 'Invalid request: $errorMessage';
        } else if (statusCode != null) {
          errorMessage = 'API Error ($statusCode): $errorMessage';
        }

        throw Exception(errorMessage);
      } else {
        // Network or connection error
        final errorMsg = e.message ?? 'Unknown network error';
        if (e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout) {
          throw Exception(
            'Connection timeout. Please check your internet connection.',
          );
        } else if (e.type == DioExceptionType.connectionError) {
          throw Exception('No internet connection. Please check your network.');
        } else {
          throw Exception('Network error: $errorMsg');
        }
      }
    } catch (e) {
      debugPrint('❌ Unexpected error in ElevenLabs service: $e');
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Error generating speech: $e');
    }
  }

  /// Get available voices
  Future<List<ElevenLabsVoice>> getVoices() async {
    if (_apiKey == null || _apiKey!.isEmpty) {
      throw Exception('ElevenLabs API key is not set');
    }

    try {
      final response = await _dio.get(
        '/voices',
        options: Options(headers: {'xi-api-key': _apiKey!}),
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        final voices = data['voices'] as List?;

        if (voices != null) {
          return voices
              .map((v) => ElevenLabsVoice.fromJson(v as Map<String, dynamic>))
              .toList();
        }
      }

      return [];
    } catch (e) {
      debugPrint('Error fetching voices: $e');
      return [];
    }
  }

  /// Get user's subscription info
  Future<Map<String, dynamic>?> getUserInfo() async {
    if (_apiKey == null || _apiKey!.isEmpty) {
      throw Exception('ElevenLabs API key is not set');
    }

    try {
      final response = await _dio.get(
        '/user',
        options: Options(headers: {'xi-api-key': _apiKey!}),
      );

      if (response.statusCode == 200) {
        return response.data as Map<String, dynamic>;
      }

      return null;
    } catch (e) {
      debugPrint('Error fetching user info: $e');
      return null;
    }
  }
}

/// ElevenLabs Voice Model
class ElevenLabsVoice {
  final String voiceId;
  final String name;
  final String category;
  final String description;
  final Map<String, dynamic>? settings;

  ElevenLabsVoice({
    required this.voiceId,
    required this.name,
    required this.category,
    required this.description,
    this.settings,
  });

  factory ElevenLabsVoice.fromJson(Map<String, dynamic> json) {
    return ElevenLabsVoice(
      voiceId: json['voice_id'] as String,
      name: json['name'] as String,
      category: json['category'] as String? ?? 'premade',
      description: json['description'] as String? ?? '',
      settings: json['settings'] as Map<String, dynamic>?,
    );
  }
}
