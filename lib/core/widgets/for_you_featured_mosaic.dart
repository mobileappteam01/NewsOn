import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../data/models/news_article.dart';
import '../../providers/bookmark_provider.dart';
import 'news_article_image.dart';

/// Instagram-style featured row: two stacked tiles left, one hero tile right.
class ForYouFeaturedMosaic extends StatelessWidget {
  const ForYouFeaturedMosaic({
    super.key,
    required this.articles,
    required this.primaryColor,
    required this.onArticleTap,
    this.onListenTap,
    this.onBookmark,
    this.onShare,
    this.showListenOverlay = false,
  });

  final List<NewsArticle> articles;
  final Color primaryColor;
  final void Function(NewsArticle article, int index) onArticleTap;
  final void Function(NewsArticle article, int index)? onListenTap;
  final void Function(NewsArticle article, int index)? onBookmark;
  final void Function(NewsArticle article, int index)? onShare;
  final bool showListenOverlay;

  static const double _mosaicHeight = 248;
  static const double _gap = 3;

  @override
  Widget build(BuildContext context) {
    if (articles.isEmpty) return const SizedBox.shrink();

    if (articles.length == 1) {
      return _FeaturedTile(
        article: articles[0],
        index: 0,
        height: _mosaicHeight,
        primaryColor: primaryColor,
        borderRadius: BorderRadius.circular(12),
        onTap: () => onArticleTap(articles[0], 0),
        onListenTap: onListenTap != null
            ? () => onListenTap!(articles[0], 0)
            : null,
        onBookmark: onBookmark != null
            ? () => onBookmark!(articles[0], 0)
            : null,
        onShare: onShare != null ? () => onShare!(articles[0], 0) : null,
        showListenOverlay: showListenOverlay,
      );
    }

    if (articles.length == 2) {
      return SizedBox(
        height: _mosaicHeight,
        child: Row(
          children: [
            Expanded(
              child: _FeaturedTile(
                article: articles[0],
                index: 0,
                height: _mosaicHeight,
                primaryColor: primaryColor,
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(12),
                ),
                onTap: () => onArticleTap(articles[0], 0),
                onListenTap: onListenTap != null
                    ? () => onListenTap!(articles[0], 0)
                    : null,
                onBookmark: onBookmark != null
                    ? () => onBookmark!(articles[0], 0)
                    : null,
                onShare:
                    onShare != null ? () => onShare!(articles[0], 0) : null,
                showListenOverlay: showListenOverlay,
              ),
            ),
            const SizedBox(width: _gap),
            Expanded(
              child: _FeaturedTile(
                article: articles[1],
                index: 1,
                height: _mosaicHeight,
                primaryColor: primaryColor,
                borderRadius: const BorderRadius.horizontal(
                  right: Radius.circular(12),
                ),
                onTap: () => onArticleTap(articles[1], 1),
                onListenTap: onListenTap != null
                    ? () => onListenTap!(articles[1], 1)
                    : null,
                onBookmark: onBookmark != null
                    ? () => onBookmark!(articles[1], 1)
                    : null,
                onShare:
                    onShare != null ? () => onShare!(articles[1], 1) : null,
                showListenOverlay: showListenOverlay,
              ),
            ),
          ],
        ),
      );
    }

    final leftTop = articles[0];
    final leftBottom = articles[1];
    final hero = articles[2];
    final halfHeight = (_mosaicHeight - _gap) / 2;

    return SizedBox(
      height: _mosaicHeight,
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: _FeaturedTile(
                    article: leftTop,
                    index: 0,
                    height: halfHeight,
                    primaryColor: primaryColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                    ),
                    onTap: () => onArticleTap(leftTop, 0),
                    onListenTap: onListenTap != null
                        ? () => onListenTap!(leftTop, 0)
                        : null,
                    onBookmark: onBookmark != null
                        ? () => onBookmark!(leftTop, 0)
                        : null,
                    onShare:
                        onShare != null ? () => onShare!(leftTop, 0) : null,
                    showListenOverlay: showListenOverlay,
                  ),
                ),
                const SizedBox(height: _gap),
                Expanded(
                  child: _FeaturedTile(
                    article: leftBottom,
                    index: 1,
                    height: halfHeight,
                    primaryColor: primaryColor,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(12),
                    ),
                    onTap: () => onArticleTap(leftBottom, 1),
                    onListenTap: onListenTap != null
                        ? () => onListenTap!(leftBottom, 1)
                        : null,
                    onBookmark: onBookmark != null
                        ? () => onBookmark!(leftBottom, 1)
                        : null,
                    onShare: onShare != null
                        ? () => onShare!(leftBottom, 1)
                        : null,
                    showListenOverlay: showListenOverlay,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: _gap),
          Expanded(
            child: _FeaturedTile(
              article: hero,
              index: 2,
              height: _mosaicHeight,
              primaryColor: primaryColor,
              borderRadius: const BorderRadius.horizontal(
                right: Radius.circular(12),
              ),
              onTap: () => onArticleTap(hero, 2),
              onListenTap: onListenTap != null
                  ? () => onListenTap!(hero, 2)
                  : null,
              onBookmark:
                  onBookmark != null ? () => onBookmark!(hero, 2) : null,
              onShare: onShare != null ? () => onShare!(hero, 2) : null,
              showListenOverlay: showListenOverlay,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeaturedTile extends StatelessWidget {
  const _FeaturedTile({
    required this.article,
    required this.index,
    required this.height,
    required this.primaryColor,
    required this.borderRadius,
    required this.onTap,
    this.onListenTap,
    this.onBookmark,
    this.onShare,
    this.showListenOverlay = false,
  });

  final NewsArticle article;
  final int index;
  final double height;
  final Color primaryColor;
  final BorderRadius borderRadius;
  final VoidCallback onTap;
  final VoidCallback? onListenTap;
  final VoidCallback? onBookmark;
  final VoidCallback? onShare;
  final bool showListenOverlay;

  String? get _imageUrl {
    final url = article.imageUrl ?? article.sourceIcon;
    if (url == null || url.isEmpty) return null;
    return url;
  }

  @override
  Widget build(BuildContext context) {
    final showActions = onBookmark != null || onShare != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        child: ClipRRect(
          borderRadius: borderRadius,
          child: SizedBox(
            height: height,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                NewsArticleImage(
                  imageUrl: _imageUrl,
                  fit: BoxFit.cover,
                  height: height,
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.75),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 10,
                  right: showActions ? 56 : 10,
                  bottom: 10,
                  child: Text(
                    article.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: index == 2 ? 13 : 11,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                  ),
                ),
                if (article.category != null && article.category!.isNotEmpty)
                  Positioned(
                    left: 10,
                    top: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        article.category!.first,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                if (showListenOverlay && onListenTap != null)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Material(
                      color: Colors.black45,
                      shape: const CircleBorder(),
                      child: InkWell(
                        onTap: onListenTap,
                        customBorder: const CircleBorder(),
                        child: const Padding(
                          padding: EdgeInsets.all(8),
                          child: Icon(
                            Icons.headphones,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (showActions)
                  Positioned(
                    right: 4,
                    bottom: 4,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (onBookmark != null)
                          Consumer<BookmarkProvider>(
                            builder: (context, bookmarks, _) {
                              final saved = bookmarks.isBookmarked(article);
                              return _mosaicAction(
                                icon: saved
                                    ? Icons.bookmark
                                    : Icons.bookmark_border,
                                onTap: onBookmark!,
                                color: saved ? primaryColor : Colors.white,
                              );
                            },
                          ),
                        if (onShare != null)
                          _mosaicAction(
                            icon: Icons.share_outlined,
                            onTap: onShare!,
                            color: Colors.white,
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _mosaicAction({
    required IconData icon,
    required VoidCallback onTap,
    required Color color,
  }) {
    return Material(
      color: Colors.black45,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }
}
