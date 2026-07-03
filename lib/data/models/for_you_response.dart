import 'news_article.dart';

/// Pagination metadata from For You API.
class ForYouPagination {
  final int total;
  final int page;
  final int limit;
  final int totalPages;
  final bool hasNextPage;
  final bool hasPrevPage;

  ForYouPagination({
    required this.total,
    required this.page,
    required this.limit,
    required this.totalPages,
    this.hasNextPage = false,
    this.hasPrevPage = false,
  });

  factory ForYouPagination.fromJson(Map<String, dynamic> json) {
    final page = json['page'] as int? ?? 1;
    final totalPages = json['totalPages'] as int? ?? 1;
    return ForYouPagination(
      total: json['total'] as int? ?? 0,
      page: page,
      limit: json['limit'] as int? ?? 10,
      totalPages: totalPages,
      hasNextPage: json['hasNextPage'] as bool? ?? page < totalPages,
      hasPrevPage: json['hasPrevPage'] as bool? ?? page > 1,
    );
  }

  bool get hasMore => hasNextPage || page < totalPages;
}

/// Parsed For You feed response.
class ForYouResponse {
  final String message;
  final ForYouPagination pagination;
  final List<NewsArticle> articles;

  ForYouResponse({
    required this.message,
    required this.pagination,
    required this.articles,
  });
}
