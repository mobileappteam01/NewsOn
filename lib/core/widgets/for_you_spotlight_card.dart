import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../data/models/news_article.dart';
import '../../providers/bookmark_provider.dart';

/// Compact explore-style tile used in the For You 2-column spotlight grid.
class ForYouSpotlightCard extends StatelessWidget {
  const ForYouSpotlightCard({
    super.key,
    required this.article,
    required this.primaryColor,
    required this.onTap,
    required this.onSaveTap,
    required this.onShareTap,
    this.onListenTap,
    this.showListenButton = false,
  });

  final NewsArticle article;
  final Color primaryColor;
  final VoidCallback onTap;
  final VoidCallback onSaveTap;
  final VoidCallback onShareTap;
  final VoidCallback? onListenTap;
  final bool showListenButton;

  String? get _imageUrl {
    final url = article.imageUrl ?? article.sourceIcon;
    if (url == null || url.isEmpty) return null;
    return url;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasImage = _imageUrl != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: hasImage ? null : primaryColor.withValues(alpha: 0.12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: hasImage ? 3 : 2,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (hasImage)
                        CachedNetworkImage(
                          imageUrl: _imageUrl!,
                          fit: BoxFit.cover,
                          placeholder: (_, __) =>
                              Container(color: Colors.grey[300]),
                          errorWidget: (_, __, ___) => _textBackdrop(theme),
                        )
                      else
                        _textBackdrop(theme),
                      if (hasImage)
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.7),
                              ],
                            ),
                          ),
                        ),
                      if (article.category != null &&
                          article.category!.isNotEmpty)
                        Positioned(
                          left: 8,
                          top: 8,
                          child: _chip(article.category!.first),
                        ),
                      if (showListenButton && onListenTap != null)
                        Positioned(
                          right: 6,
                          top: 6,
                          child: _iconAction(
                            icon: Icons.headphones,
                            onTap: onListenTap!,
                          ),
                        ),
                      if (hasImage)
                        Positioned(
                          left: 8,
                          right: 8,
                          bottom: 8,
                          child: Text(
                            article.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              height: 1.2,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (!hasImage)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
                    child: Text(
                      article.title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(6, 4, 6, 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Consumer<BookmarkProvider>(
                        builder: (context, bookmarks, _) {
                          final saved = bookmarks.isBookmarked(article);
                          return _iconAction(
                            icon: saved
                                ? Icons.bookmark
                                : Icons.bookmark_border,
                            onTap: onSaveTap,
                            color: saved ? primaryColor : null,
                          );
                        },
                      ),
                      _iconAction(
                        icon: Icons.share_outlined,
                        onTap: onShareTap,
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

  Widget _chip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: primaryColor.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _textBackdrop(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            primaryColor.withValues(alpha: 0.35),
            theme.colorScheme.surface,
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.article_outlined,
          size: 36,
          color: primaryColor.withValues(alpha: 0.5),
        ),
      ),
    );
  }

  Widget _iconAction({
    required IconData icon,
    required VoidCallback onTap,
    Color? color,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 18, color: color ?? Colors.grey[700]),
        ),
      ),
    );
  }
}
