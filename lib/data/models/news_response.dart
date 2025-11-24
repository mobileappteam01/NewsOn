import 'package:flutter/material.dart';

import 'news_article.dart';

/// Response model for Newsdata.IO API
class NewsResponse {
  final String status;
  final int totalResults;
  final List<NewsArticle> results;
  final String? nextPage;

  NewsResponse({
    required this.status,
    required this.totalResults,
    required this.results,
    this.nextPage,
  });

  /// Factory constructor to create NewsResponse from JSON
  factory NewsResponse.fromJson(Map<String, dynamic> json) {
    debugPrint("Fetching news 4 : $json");
    return NewsResponse(
      status: json['status'] as String? ?? 'error',
      totalResults: json['totalResults'] as int? ?? 0,
      results:
          (json['results'] as List<dynamic>?)
              ?.map(
                (article) =>
                    NewsArticle.fromJson(article as Map<String, dynamic>),
              )
              .toList() ??
          [],
      nextPage: json['nextPage'] as String?,
    );
  }

  /// Convert NewsResponse to JSON
  Map<String, dynamic> toJson() {
    return {
      'status': status,
      'totalResults': totalResults,
      'results': results.map((article) => article.toJson()).toList(),
      'nextPage': nextPage,
    };
  }

  /// Check if there are more pages
  bool get hasNextPage => nextPage != null && nextPage!.isNotEmpty;
}
