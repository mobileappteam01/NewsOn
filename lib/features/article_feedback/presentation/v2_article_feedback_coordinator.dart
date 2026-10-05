import 'package:flutter/material.dart';

import '../../../core/utils/auth_navigation_helper.dart';
import '../../../core/utils/localization_helper.dart';
import '../../../data/models/news_article.dart';
import '../../../data/services/user_service.dart';
import '../../news/domain/news_summary.dart';
import '../data/v2_article_feedback_api.dart';
import '../domain/v2_article_feedback.dart';
import 'v2_article_feedback_sheets.dart';

typedef V2HideArticle = Future<V2HideResult> Function(NewsArticle article);

/// Overflow menu flows for a V2 Home card: Not Interested and Report.
/// Signed-out users get the account sign-in screen and no request is sent.
class V2ArticleFeedbackCoordinator {
  V2ArticleFeedbackCoordinator({
    V2ArticleFeedbackApi? api,
    bool Function()? isLoggedIn,
    void Function(BuildContext context)? promptSignIn,
  })  : api = api ?? V2ArticleFeedbackApi(),
        _isLoggedIn = isLoggedIn ?? (() => UserService().isLoggedIn),
        _promptSignIn = promptSignIn ?? navigateToLoginForAccountFeature;

  final V2ArticleFeedbackApi api;
  final bool Function() _isLoggedIn;
  final void Function(BuildContext context) _promptSignIn;

  final Set<String> _reported = <String>{};
  final Set<String> _reporting = <String>{};

  bool hasReported(String articleId) => _reported.contains(articleId.trim());

  Future<void> openMenu(
    BuildContext context,
    NewsArticle article, {
    required V2HideArticle hide,
  }) async {
    final action = await showV2ArticleOverflowSheet(context);
    if (action == null || !context.mounted) return;
    if (!_isLoggedIn()) {
      _promptSignIn(context);
      return;
    }
    switch (action) {
      case V2ArticleOverflowAction.notInterested:
        await _notInterested(context, article, hide);
      case V2ArticleOverflowAction.report:
        await _report(context, article);
    }
  }

  Future<void> _notInterested(
    BuildContext context,
    NewsArticle article,
    V2HideArticle hide,
  ) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final failedText = LocalizationHelper.v2FeedbackNotInterestedFailed(context);
    final result = await hide(article);
    if (result == V2HideResult.failed) _showSnack(messenger, failedText);
  }

  Future<void> _report(BuildContext context, NewsArticle article) async {
    final id = article.analyticsNewsId.trim();
    if (id.isEmpty || _reporting.contains(id)) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final submittedText = LocalizationHelper.v2FeedbackReportSubmitted(context);
    if (_reported.contains(id)) {
      _showSnack(messenger, submittedText);
      return;
    }
    await showV2ReportSheet(
      context,
      submit: (reason, comment) async {
        if (_reported.contains(id)) return;
        _reporting.add(id);
        try {
          await api.reportArticle(id, reason, comment);
          _reported.add(id);
          // Confirmed even if the sheet was closed while the request ran.
          _showSnack(messenger, submittedText);
        } finally {
          _reporting.remove(id);
        }
      },
    );
  }

  void _showSnack(ScaffoldMessengerState? messenger, String text) {
    if (messenger == null || !messenger.mounted) return;
    messenger.showSnackBar(SnackBar(content: Text(text)));
  }
}
