import '../../../data/models/news_article.dart';
import '../domain/publisher_model.dart';

enum PublisherLoadStatus { idle, loading, refreshing, loadingMore, ready, error }

class PublisherState {
  const PublisherState({
    this.publisher,
    this.articles = const [],
    this.status = PublisherLoadStatus.idle,
    this.errorCode,
    this.errorMessage,
    this.page = 1,
    this.hasMore = false,
    this.fromDedicatedEndpoint = false,
  });

  final PublisherModel? publisher;
  final List<NewsArticle> articles;
  final PublisherLoadStatus status;
  final String? errorCode;
  final String? errorMessage;
  final int page;
  final bool hasMore;
  final bool fromDedicatedEndpoint;

  bool get isLoadingHeader =>
      status == PublisherLoadStatus.loading && publisher == null;

  bool get isLoadingList =>
      status == PublisherLoadStatus.loading && articles.isEmpty;

  PublisherState copyWith({
    PublisherModel? publisher,
    List<NewsArticle>? articles,
    PublisherLoadStatus? status,
    String? errorCode,
    String? errorMessage,
    bool clearError = false,
    int? page,
    bool? hasMore,
    bool? fromDedicatedEndpoint,
  }) {
    return PublisherState(
      publisher: publisher ?? this.publisher,
      articles: articles ?? this.articles,
      status: status ?? this.status,
      errorCode: clearError ? null : (errorCode ?? this.errorCode),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      fromDedicatedEndpoint:
          fromDedicatedEndpoint ?? this.fromDedicatedEndpoint,
    );
  }
}
