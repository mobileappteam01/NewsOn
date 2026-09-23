import 'package:flutter/foundation.dart';

import '../../../data/services/api_service.dart';
import '../../../data/services/user_service.dart';
import '../domain/article_audio.dart';

/// Thin client for Phase 8 V2 audio endpoints.
class AudioApi {
  AudioApi({
    ApiService? apiService,
    UserService? userService,
  })  : _apiOrNull = apiService,
        _usersOrNull = userService;

  ApiService? _apiOrNull;
  UserService? _usersOrNull;

  ApiService get _api => _apiOrNull ??= ApiService();
  UserService get _users => _usersOrNull ??= UserService();

  String? get _token {
    final t = _users.getToken();
    if (t != null && t.isNotEmpty) return t;
    return null;
  }

  Future<ArticleAudio> fetchStatus({
    required String articleId,
    String? language,
  }) async {
    final id = articleId.trim();
    if (id.isEmpty) throw ArgumentError('articleId required');

    final query = <String, String>{};
    if (language != null && language.trim().isNotEmpty) {
      query['language'] = language.trim();
    }

    final response = await _api.getByPath(
      '/api/v2/audio/article/$id',
      queryParameters: query.isEmpty ? null : query,
      bearerToken: _token,
      useV2Host: true,
    );
    return _parse(id, response);
  }

  Future<ArticleAudio> requestGeneration({
    required String articleId,
    String? language,
  }) async {
    final id = articleId.trim();
    if (id.isEmpty) throw ArgumentError('articleId required');

    final body = <String, dynamic>{};
    if (language != null && language.trim().isNotEmpty) {
      body['language'] = language.trim();
    }

    final response = await _api.postByPath(
      '/api/v2/audio/article/$id/request',
      body: body.isEmpty ? null : body,
      bearerToken: _token,
      useV2Host: true,
    );
    return _parse(id, response);
  }

  ArticleAudio _parse(String articleId, ApiResponse response) {
    if (!response.success) {
      debugPrint('ℹ️ AudioApi soft failure: ${response.error}');
      throw AudioApiException(
        response.error ?? 'network_error',
        statusCode: response.statusCode,
      );
    }
    final raw = response.data;
    Map<String, dynamic>? map;
    if (raw is Map<String, dynamic>) {
      map = raw;
    } else if (raw is Map) {
      map = Map<String, dynamic>.from(raw);
    }
    if (map == null) throw AudioApiException('invalid_payload');

    final data = map['data'];
    if (data is Map<String, dynamic>) {
      return ArticleAudio.fromJson(articleId, data);
    }
    if (data is Map) {
      return ArticleAudio.fromJson(articleId, Map<String, dynamic>.from(data));
    }
    if (map.containsKey('status')) {
      return ArticleAudio.fromJson(articleId, map);
    }
    throw AudioApiException('invalid_payload');
  }
}

class AudioApiException implements Exception {
  AudioApiException(this.code, {this.statusCode});
  final String code;
  final int? statusCode;
  @override
  String toString() => code;
}
