import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:newson/data/services/api_service.dart';

class PostCall {
  PostCall(
    this.path,
    this.body,
    this.bearerToken,
    this.useV2Host,
    this.baseUrlOverride,
  );

  final String path;
  final Map<String, dynamic>? body;
  final String? bearerToken;
  final bool useV2Host;
  final String? baseUrlOverride;
}

/// Records POSTs; any other ApiService member fails the test.
class FakeApiService implements ApiService {
  final List<PostCall> posts = [];
  ApiResponse response = ok();

  /// When set, the next POST waits for it before answering.
  Completer<void>? gate;

  static ApiResponse ok() =>
      ApiResponse(success: true, data: const {}, error: null, statusCode: 200);

  static ApiResponse failure([int status = 500]) => ApiResponse(
        success: false,
        data: null,
        error: 'HTTP $status',
        statusCode: status,
      );

  @override
  Future<ApiResponse> postByPath(
    String relativeOrAbsolutePath, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    String? bearerToken,
    bool useV2Host = false,
    String? baseUrlOverride,
  }) async {
    posts.add(PostCall(
      relativeOrAbsolutePath,
      body,
      bearerToken,
      useV2Host,
      baseUrlOverride,
    ));
    final hold = gate;
    if (hold != null) {
      gate = null;
      await hold.future;
    }
    return response;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      fail('Unexpected ApiService call: ${invocation.memberName}');
}
