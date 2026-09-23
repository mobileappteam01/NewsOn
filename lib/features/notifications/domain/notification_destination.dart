/// Allowlisted internal destinations — never arbitrary URLs.
sealed class NotificationDestination {
  const NotificationDestination();
}

class ArticleDestination extends NotificationDestination {
  const ArticleDestination({
    required this.articleId,
    this.fromCut = false,
  });
  final String articleId;
  final bool fromCut;
}

class CategoryDestination extends NotificationDestination {
  const CategoryDestination(this.categoryId);
  final String categoryId;
}

class PublisherDestination extends NotificationDestination {
  const PublisherDestination(this.publisherId);
  final String publisherId;
}

class HomeDestination extends NotificationDestination {
  const HomeDestination();
}

class InboxDestination extends NotificationDestination {
  const InboxDestination();
}
