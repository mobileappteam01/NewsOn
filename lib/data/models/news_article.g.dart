// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'news_article.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class NewsArticleAdapter extends TypeAdapter<NewsArticle> {
  @override
  final int typeId = 0;

  @override
  NewsArticle read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return NewsArticle(
      articleId: fields[0] as String?,
      title: fields[1] as String,
      link: fields[2] as String?,
      keywords: (fields[3] as List?)?.cast<String>(),
      creator: (fields[4] as List?)?.cast<String>(),
      videoUrl: fields[5] as String?,
      description: fields[6] as String?,
      content: fields[7] as String?,
      pubDate: fields[8] as String?,
      imageUrl: fields[9] as String?,
      sourceId: fields[10] as String?,
      sourcePriority: fields[11] as String?,
      country: (fields[12] as List?)?.cast<String>(),
      category: (fields[13] as List?)?.cast<String>(),
      language: fields[14] as String?,
      isBookmarked: fields[15] as bool,
      bookmarkedAt: fields[16] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, NewsArticle obj) {
    writer
      ..writeByte(17)
      ..writeByte(0)
      ..write(obj.articleId)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.link)
      ..writeByte(3)
      ..write(obj.keywords)
      ..writeByte(4)
      ..write(obj.creator)
      ..writeByte(5)
      ..write(obj.videoUrl)
      ..writeByte(6)
      ..write(obj.description)
      ..writeByte(7)
      ..write(obj.content)
      ..writeByte(8)
      ..write(obj.pubDate)
      ..writeByte(9)
      ..write(obj.imageUrl)
      ..writeByte(10)
      ..write(obj.sourceId)
      ..writeByte(11)
      ..write(obj.sourcePriority)
      ..writeByte(12)
      ..write(obj.country)
      ..writeByte(13)
      ..write(obj.category)
      ..writeByte(14)
      ..write(obj.language)
      ..writeByte(15)
      ..write(obj.isBookmarked)
      ..writeByte(16)
      ..write(obj.bookmarkedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NewsArticleAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
