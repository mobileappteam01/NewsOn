import 'package:hive/hive.dart';

part 'news_article.g.dart';

/// News Article Model for Newsdata.IO API
@HiveType(typeId: 0)
class NewsArticle {
  @HiveField(0)
  final String? articleId;
  
  @HiveField(1)
  final String title;
  
  @HiveField(2)
  final String? link;
  
  @HiveField(3)
  final List<String>? keywords;
  
  @HiveField(4)
  final List<String>? creator;
  
  @HiveField(5)
  final String? videoUrl;
  
  @HiveField(6)
  final String? description;
  
  @HiveField(7)
  final String? content;
  
  @HiveField(8)
  final String? pubDate;
  
  @HiveField(9)
  final String? imageUrl;
  
  @HiveField(10)
  final String? sourceId;
  
  @HiveField(11)
  final String? sourcePriority;
  
  @HiveField(12)
  final List<String>? country;
  
  @HiveField(13)
  final List<String>? category;
  
  @HiveField(14)
  final String? language;
  
  @HiveField(15)
  final bool isBookmarked;
  
  @HiveField(16)
  final DateTime? bookmarkedAt;

  NewsArticle({
    this.articleId,
    required this.title,
    this.link,
    this.keywords,
    this.creator,
    this.videoUrl,
    this.description,
    this.content,
    this.pubDate,
    this.imageUrl,
    this.sourceId,
    this.sourcePriority,
    this.country,
    this.category,
    this.language,
    this.isBookmarked = false,
    this.bookmarkedAt,
  });

  /// Factory constructor to create NewsArticle from JSON
  factory NewsArticle.fromJson(Map<String, dynamic> json) {
    return NewsArticle(
      articleId: json['article_id'] as String?,
      title: json['title'] as String? ?? 'No Title',
      link: json['link'] as String?,
      keywords: (json['keywords'] as List<dynamic>?)?.map((e) => e.toString()).toList(),
      creator: (json['creator'] as List<dynamic>?)?.map((e) => e.toString()).toList(),
      videoUrl: json['video_url'] as String?,
      description: json['description'] as String?,
      content: json['content'] as String?,
      pubDate: json['pubDate'] as String?,
      imageUrl: json['image_url'] as String?,
      sourceId: json['source_id'] as String?,
      sourcePriority: json['source_priority']?.toString(),
      country: (json['country'] as List<dynamic>?)?.map((e) => e.toString()).toList(),
      category: (json['category'] as List<dynamic>?)?.map((e) => e.toString()).toList(),
      language: json['language'] as String?,
      isBookmarked: false,
    );
  }

  /// Convert NewsArticle to JSON
  Map<String, dynamic> toJson() {
    return {
      'article_id': articleId,
      'title': title,
      'link': link,
      'keywords': keywords,
      'creator': creator,
      'video_url': videoUrl,
      'description': description,
      'content': content,
      'pubDate': pubDate,
      'image_url': imageUrl,
      'source_id': sourceId,
      'source_priority': sourcePriority,
      'country': country,
      'category': category,
      'language': language,
    };
  }

  /// Copy with method for immutability
  NewsArticle copyWith({
    String? articleId,
    String? title,
    String? link,
    List<String>? keywords,
    List<String>? creator,
    String? videoUrl,
    String? description,
    String? content,
    String? pubDate,
    String? imageUrl,
    String? sourceId,
    String? sourcePriority,
    List<String>? country,
    List<String>? category,
    String? language,
    bool? isBookmarked,
    DateTime? bookmarkedAt,
  }) {
    return NewsArticle(
      articleId: articleId ?? this.articleId,
      title: title ?? this.title,
      link: link ?? this.link,
      keywords: keywords ?? this.keywords,
      creator: creator ?? this.creator,
      videoUrl: videoUrl ?? this.videoUrl,
      description: description ?? this.description,
      content: content ?? this.content,
      pubDate: pubDate ?? this.pubDate,
      imageUrl: imageUrl ?? this.imageUrl,
      sourceId: sourceId ?? this.sourceId,
      sourcePriority: sourcePriority ?? this.sourcePriority,
      country: country ?? this.country,
      category: category ?? this.category,
      language: language ?? this.language,
      isBookmarked: isBookmarked ?? this.isBookmarked,
      bookmarkedAt: bookmarkedAt ?? this.bookmarkedAt,
    );
  }

  /// Get formatted publish date
  String get formattedDate {
    if (pubDate == null) return 'Unknown date';
    try {
      final date = DateTime.parse(pubDate!);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays > 7) {
        return '${date.day}/${date.month}/${date.year}';
      } else if (difference.inDays > 0) {
        return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return pubDate ?? 'Unknown date';
    }
  }

  /// Get author name
  String get authorName {
    if (creator != null && creator!.isNotEmpty) {
      return creator!.first;
    }
    return sourceId ?? 'Unknown';
  }

  /// Get reading time estimate
  String get readingTime {
    final text = content ?? description ?? '';
    final wordCount = text.split(' ').length;
    final minutes = (wordCount / 200).ceil(); // Average reading speed: 200 words/min
    return '$minutes min read';
  }
}
