import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

part 'news_article.g.dart';

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

  // -------------------------
  // NEW FIELDS BELOW
  // -------------------------

  @HiveField(17)
  final String? pubDateTZ;

  @HiveField(18)
  final String? sourceName;

  @HiveField(19)
  final String? sourceUrl;

  @HiveField(20)
  final String? sourceIcon;

  @HiveField(21)
  final String? sentiment;

  @HiveField(22)
  final String? sentimentStats;

  @HiveField(23)
  final String? aiTag;

  @HiveField(24)
  final String? aiRegion;

  @HiveField(25)
  final String? aiOrg;

  @HiveField(26)
  final String? aiSummary;

  @HiveField(27)
  final bool duplicate;

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
    this.pubDateTZ,
    this.sourceName,
    this.sourceUrl,
    this.sourceIcon,
    this.sentiment,
    this.sentimentStats,
    this.aiTag,
    this.aiRegion,
    this.aiOrg,
    this.aiSummary,
    this.duplicate = false,
  });

  /// Helper method to parse sentiment_stats which can be a String or Map
  static String? _parseSentimentStats(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    if (value is Map) {
      // Convert map to JSON string representation
      try {
        return value.toString();
      } catch (e) {
        return null;
      }
    }
    return value.toString();
  }

  /// Helper method to parse fields that can be a String or List
  static String? _parseStringOrList(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    if (value is List) {
      // Convert list to comma-separated string
      return value.map((e) => e.toString()).join(', ');
    }
    return value.toString();
  }

  factory NewsArticle.fromJson(Map<String, dynamic> json) {
    DateTime? bookmarked;
    // Support ISO string or epoch (int) if provided
    if (json.containsKey('bookmarkedAt') && json['bookmarkedAt'] != null) {
      final val = json['bookmarkedAt'];
      if (val is String) {
        try {
          bookmarked = DateTime.tryParse(val);
        } catch (_) {
          bookmarked = null;
        }
      } else if (val is int) {
        // assume epoch millis
        bookmarked = DateTime.fromMillisecondsSinceEpoch(val);
      }
    }

    return NewsArticle(
      articleId: json['article_id'] as String?,
      title: (json['title'] as String?) ?? 'No Title',
      link: json['link'] as String?,
      keywords: (json['keywords'] as List?)?.map((e) => e.toString()).toList(),
      creator: (json['creator'] as List?)?.map((e) => e.toString()).toList(),
      videoUrl: json['video_url'] as String?,
      description: json['description'] as String?,
      content: json['content'] as String?,
      pubDate: json['pubDate'] as String?,
      imageUrl: json['image_url'] as String?,
      sourceId: json['source_id'] as String?,
      sourcePriority: json['source_priority']?.toString(),
      country: (json['country'] as List?)?.map((e) => e.toString()).toList(),
      category: (json['category'] as List?)?.map((e) => e.toString()).toList(),
      language: json['language'] as String?,
      isBookmarked:
          json['isBookmarked'] == true ||
          json['is_bookmarked'] == true ||
          false,
      bookmarkedAt: bookmarked,
      pubDateTZ: json['pubDateTZ'] as String?,
      sourceName: json['source_name'] as String?,
      sourceUrl: json['source_url'] as String?,
      sourceIcon: json['source_icon'] as String?,
      sentiment: json['sentiment'] as String?,
      sentimentStats: _parseSentimentStats(json['sentiment_stats']),
      aiTag: _parseStringOrList(json['ai_tag']),
      aiRegion: _parseStringOrList(json['ai_region']),
      aiOrg: _parseStringOrList(json['ai_org']),
      aiSummary: json['ai_summary'] as String?,
      duplicate: json['duplicate'] == true,
    );
  }

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
      'isBookmarked': isBookmarked,
      // bookmarkedAt as ISO string to be safe
      'bookmarkedAt': bookmarkedAt?.toIso8601String(),
      'pubDateTZ': pubDateTZ,
      'source_name': sourceName,
      'source_url': sourceUrl,
      'source_icon': sourceIcon,
      'sentiment': sentiment,
      'sentiment_stats': sentimentStats,
      'ai_tag': aiTag,
      'ai_region': aiRegion,
      'ai_org': aiOrg,
      'ai_summary': aiSummary,
      'duplicate': duplicate,
    };
  }

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
    String? pubDateTZ,
    String? sourceName,
    String? sourceUrl,
    String? sourceIcon,
    String? sentiment,
    String? sentimentStats,
    String? aiTag,
    String? aiRegion,
    String? aiOrg,
    String? aiSummary,
    bool? duplicate,
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
      pubDateTZ: pubDateTZ ?? this.pubDateTZ,
      sourceName: sourceName ?? this.sourceName,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      sourceIcon: sourceIcon ?? this.sourceIcon,
      sentiment: sentiment ?? this.sentiment,
      sentimentStats: sentimentStats ?? this.sentimentStats,
      aiTag: aiTag ?? this.aiTag,
      aiRegion: aiRegion ?? this.aiRegion,
      aiOrg: aiOrg ?? this.aiOrg,
      aiSummary: aiSummary ?? this.aiSummary,
      duplicate: duplicate ?? this.duplicate,
    );
  }

  /// formattedDate, authorName, readingTime helpers can be re-added here if needed
}
