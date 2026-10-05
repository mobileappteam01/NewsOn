import 'package:flutter/foundation.dart';

import '../../../data/services/api_service.dart';
import '../../../data/services/user_service.dart';
import '../domain/v2_article_feedback.dart';

enum V2ArticleFeedbackFailure { unauthenticated, invalid, request }

class V2ArticleFeedbackException implements Exception {
  V2ArticleFeedbackException(this.message, {required this.kind, this.statusCode});

  final String message;
  final V2ArticleFeedbackFailure kind;
  final int? statusCode;

  @override
  String toString() => message;
}

/// Article feedback on the V2 host (`/api/v2/articles/...`). Both routes
/// require a signed-in user; no request is sent without a token.
class V2ArticleFeedbackApi {
  V2ArticleFeedbackApi({
    ApiService? apiService,
    String? Function()? readToken,
  })  : _apiOrNull = apiService,
        _readToken = readToken ?? _sessionToken;

  ApiService? _apiOrNull;
  final String? Function() _readToken;

  ApiService get _api => _apiOrNull ??= ApiService();

  static String? _sessionToken() {
    final users = UserService();
    return users.isLoggedIn ? users.getToken() : null;
  }

  static String notInterestedPath(String articleId) =>
      '/api/v2/articles/${Uri.encodeComponent(articleId.trim())}/not-interested';

  static String reportPath(String articleId) =>
      '/api/v2/articles/${Uri.encodeComponent(articleId.trim())}/report';

  /// `POST /api/v2/articles/:articleId/not-interested`.
  Future<void> markNotInterested(String articleId) async {
    final id = _requireId(articleId);
    final token = _requireToken();
    final response = await _api.postByPath(
      notInterestedPath(id),
      bearerToken: token,
      useV2Host: true,
    );
    if (!response.success) {
      debugPrint(
        '[V2Feedback] not-interested failed status=${response.statusCode}',
      );
      throw V2ArticleFeedbackException(
        response.error ?? 'Failed to hide article',
        kind: V2ArticleFeedbackFailure.request,
        statusCode: response.statusCode,
      );
    }
  }

  /// `POST /api/v2/articles/:articleId/report` with `{reason, comment}`.
  Future<void> reportArticle(
    String articleId,
    V2ReportReason reason,
    String? comment,
  ) async {
    final id = _requireId(articleId);
    final text = V2ReportForm.normalizeComment(comment ?? '');
    if (!V2ReportForm.isCommentValid(reason, text)) {
      throw V2ArticleFeedbackException(
        'Invalid report comment',
        kind: V2ArticleFeedbackFailure.invalid,
      );
    }
    final token = _requireToken();
    final response = await _api.postByPath(
      reportPath(id),
      body: {'reason': reason.id, 'comment': text},
      bearerToken: token,
      useV2Host: true,
    );
    if (!response.success) {
      debugPrint('[V2Feedback] report failed status=${response.statusCode}');
      throw V2ArticleFeedbackException(
        response.error ?? 'Failed to submit report',
        kind: V2ArticleFeedbackFailure.request,
        statusCode: response.statusCode,
      );
    }
  }

  String _requireId(String articleId) {
    final id = articleId.trim();
    if (id.isEmpty) {
      throw V2ArticleFeedbackException(
        'Missing article id',
        kind: V2ArticleFeedbackFailure.invalid,
      );
    }
    return id;
  }

  String _requireToken() {
    final token = _readToken();
    if (token == null || token.isEmpty) {
      throw V2ArticleFeedbackException(
        'User not authenticated. Please sign in.',
        kind: V2ArticleFeedbackFailure.unauthenticated,
      );
    }
    return token;
  }
}
