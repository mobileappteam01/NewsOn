import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../app/routing/v2_routes.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../data/models/news_article.dart';
import '../../../../providers/language_provider.dart';
import '../../../news/domain/news_summary.dart';
import '../v2_reader_ad_placement.dart';
import 'v2_article_actions.dart';
import 'v2_article_image.dart';
import 'v2_reader_ad_slot.dart';
import 'v2_summary_section.dart';
import 'v2_vintage_paper_background.dart';

/// Compact editorial single-article page for the V2 reader.
class V2ArticlePage extends StatelessWidget {
  const V2ArticlePage({
    super.key,
    required this.article,
    required this.cutsLabel,
    required this.index,
    required this.total,
    required this.bookmarked,
    required this.onBookmark,
    required this.onShare,
    required this.onViewFullArticle,
    required this.onPrevious,
    required this.onNext,
    this.canPrevious = true,
    this.canNext = true,
    this.showAdSlot,
    /// When false, bookmark/share are omitted from the hero (hosted by
    /// [V2ReaderHome] chrome outside TurnablePage instead).
    this.showHeroActions = true,
  });

  final NewsArticle article;
  final String cutsLabel;
  final int index;
  final int total;
  final bool bookmarked;
  final VoidCallback onBookmark;
  final VoidCallback onShare;
  final VoidCallback onViewFullArticle;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final bool canPrevious;
  final bool canNext;
  final bool? showAdSlot;
  final bool showHeroActions;

  String _relativeTime(String? pubDate) {
    final dt = DateFormatter.parseApiDate(pubDate);
    if (dt == null) return '';
    return DateFormatter.getRelativeTime(dt);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categories = article.category
            ?.map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList() ??
        const <String>[];
    final primaryCategory =
        categories.isNotEmpty ? categories.first.toUpperCase() : null;
    final time = _relativeTime(article.pubDate);
    final showAd =
        showAdSlot ?? V2ReaderAdPlacement.shouldShowAdOnArticle(index);

    return Material(
      color: Colors.transparent,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const V2VintagePaperBackground(
            intensity: V2PaperIntensity.page,
          ),
          SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _HeroBlock(
                  article: article,
                  category: primaryCategory,
                  publisherTime: time,
                  bookmarked: bookmarked,
                  onBookmark: onBookmark,
                  onShare: onShare,
                  showActions: showHeroActions,
                ),
                const SizedBox(height: 10),
                Text(
                  article.title,
                  style: GoogleFonts.libreBaskerville(
                    fontWeight: FontWeight.w700,
                    fontSize: 19,
                    height: 1.22,
                    letterSpacing: -0.25,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                V2SummarySection(article: article, cutsLabel: cutsLabel),
                const SizedBox(height: 14),
                PageTurnExclusive(
                  child: V2ArticleActions(
                    onViewFullArticle: onViewFullArticle,
                    publisherName: article.publisherDisplayName,
                  ),
                ),
                if (showAd)
                  V2ReaderAdSlot(
                    slotIndex: V2ReaderAdPlacement.slotIndexForArticle(index),
                  ),
                // Intentional paper residual — keeps composition page-like.
                const SizedBox(height: 28),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroBlock extends StatelessWidget {
  const _HeroBlock({
    required this.article,
    required this.category,
    required this.publisherTime,
    required this.bookmarked,
    required this.onBookmark,
    required this.onShare,
    required this.showActions,
  });

  final NewsArticle article;
  final String? category;
  final String publisherTime;
  final bool bookmarked;
  final VoidCallback onBookmark;
  final VoidCallback onShare;
  final bool showActions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Stack(
      children: [
        V2ArticleImage(
          imageUrl: article.imageUrl,
          aspectRatio: 16 / 9.5,
          borderRadius: 14,
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.36),
                  Colors.transparent,
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.58),
                ],
                stops: const [0.0, 0.26, 0.48, 1.0],
              ),
            ),
          ),
        ),
        if (category != null)
          Positioned(
            top: 10,
            left: 10,
            child: PageTurnExclusive(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  category!,
                  style: GoogleFonts.inter(
                    color: theme.colorScheme.onPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 10,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ),
        // Hero-corner actions omitted when [showActions] is false — V2 Reader
        // hosts them outside TurnablePage so taps never hit the curl corner.
        if (showActions)
          Positioned(
            top: 8,
            right: 8,
            child: PageTurnExclusive(
              child: V2ReaderActionButtons(
                bookmarked: bookmarked,
                onBookmark: onBookmark,
                onShare: onShare,
              ),
            ),
          ),
        Positioned(
          left: 10,
          bottom: 10,
          right: 10,
          child: PageTurnExclusive(
            child: _PublisherOverlay(
              article: article,
              time: publisherTime,
            ),
          ),
        ),
      ],
    );
  }
}

/// Bookmark + share chrome used by the V2 reader (hero or shell overlay).
class V2ReaderActionButtons extends StatelessWidget {
  const V2ReaderActionButtons({
    super.key,
    required this.bookmarked,
    required this.onBookmark,
    required this.onShare,
  });

  final bool bookmarked;
  final VoidCallback onBookmark;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _OverlayIconButton(
          tooltip: bookmarked ? 'Remove bookmark' : 'Bookmark',
          icon: bookmarked ? Icons.bookmark : Icons.bookmark_border,
          onPressed: onBookmark,
        ),
        const SizedBox(width: 8),
        _OverlayIconButton(
          tooltip: 'Share',
          icon: Icons.ios_share_rounded,
          onPressed: onShare,
        ),
      ],
    );
  }
}

/// Absorbs pointer/pan gestures so TurnablePage never flips from chrome taps.
class PageTurnExclusive extends StatelessWidget {
  const PageTurnExclusive({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return RawGestureDetector(
      behavior: HitTestBehavior.opaque,
      gestures: <Type, GestureRecognizerFactory>{
        HorizontalDragGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<HorizontalDragGestureRecognizer>(
          HorizontalDragGestureRecognizer.new,
          (instance) {
            instance
              ..onStart = (_) {}
              ..onUpdate = (_) {}
              ..onEnd = (_) {}
              ..onCancel = () {};
          },
        ),
        PanGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<PanGestureRecognizer>(
          PanGestureRecognizer.new,
          (instance) {
            instance
              ..onStart = (_) {}
              ..onUpdate = (_) {}
              ..onEnd = (_) {}
              ..onCancel = () {};
          },
        ),
      },
      child: child,
    );
  }
}

class _PublisherOverlay extends StatelessWidget {
  const _PublisherOverlay({
    required this.article,
    required this.time,
  });

  final NewsArticle article;
  final String time;

  @override
  Widget build(BuildContext context) {
    final name = article.publisherDisplayName;
    final icon = article.sourceIcon?.trim();
    final canOpen = V2Routes.canOpenPublisher(context, article);

    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.38),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipOval(
            child: SizedBox(
              width: 22,
              height: 22,
              child: icon != null && icon.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: icon,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => const ColoredBox(
                        color: Color(0x33FFFFFF),
                        child: Icon(
                          Icons.apartment,
                          color: Colors.white,
                          size: 13,
                        ),
                      ),
                    )
                  : const ColoredBox(
                      color: Color(0x33FFFFFF),
                      child: Icon(
                        Icons.apartment,
                        color: Colors.white,
                        size: 13,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 7),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    height: 1.15,
                    decoration: canOpen ? TextDecoration.underline : null,
                    decorationColor: Colors.white.withValues(alpha: 0.55),
                  ),
                ),
                if (time.isNotEmpty)
                  Text(
                    time,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontWeight: FontWeight.w500,
                      fontSize: 10.5,
                      height: 1.15,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );

    if (!canOpen) {
      debugPrint(
        '[PublisherTap] screen=reader enabled=false '
        'publisherId=${(article.publisherId ?? '').trim().isEmpty ? 'missing' : article.publisherId} '
        'publisherName=${name.isEmpty ? 'missing' : name}',
      );
      return content;
    }

    return Semantics(
      button: true,
      label: name,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            debugPrint(
              '[PublisherTap] screen=reader enabled=true '
              'publisherId=${article.publisherId} '
              'publisherName=$name',
            );
            V2Routes.openPublisherFromArticle(
              context,
              article,
              sourceScreen: 'reader',
              language: context.read<LanguageProvider>().newsLanguageCode,
            );
          },
          borderRadius: BorderRadius.circular(12),
          child: content,
        ),
      ),
    );
  }
}

class _OverlayIconButton extends StatelessWidget {
  const _OverlayIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.45),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: Tooltip(
          message: tooltip,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(icon, color: Colors.white, size: 19),
          ),
        ),
      ),
    );
  }
}
