// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:newson/core/utils/shared_functions.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/models/news_article.dart';
import '../../core/constants/app_constants.dart';
import '../../data/services/storage_service.dart';
import '../../providers/bookmark_provider.dart';
import '../../providers/remote_config_provider.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/widgets/audio_loading_overlay.dart';

class NewsDetailScreen extends StatefulWidget {
  final NewsArticle article;
  const NewsDetailScreen({super.key, required this.article});

  @override
  State<NewsDetailScreen> createState() => _NewsDetailScreenState();
}

class _NewsDetailScreenState extends State<NewsDetailScreen>
    with WidgetsBindingObserver {
  double _contentTextSize = AppConstants.defaultTextSize;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadTextSize();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadTextSize();
    }
  }

  void _loadTextSize() {
    final savedSize = StorageService.getSetting(
      AppConstants.textSizeKey,
      defaultValue: AppConstants.defaultTextSize,
    );
    if (mounted) {
      setState(() {
        _contentTextSize =
            (savedSize is double) ? savedSize : AppConstants.defaultTextSize;
      });
    }
  }

  /// Get the article content text to display
  String _getArticleContent() {
    // First try to use actual content if available and valid
    if (widget.article.content != null &&
        widget.article.content!.isNotEmpty &&
        widget.article.content != 'ONLY AVAILABLE IN PAID PLANS') {
      return widget.article.content!;
    }
    // Fallback to description
    if (widget.article.description != null &&
        widget.article.description!.isNotEmpty) {
      return widget.article.description!;
    }
    // Final fallback to placeholder text
    return 'White House trade adviser Peter Navarro accused India of helping finance Russia\'s war in Ukraine through continued oil imports, describing the conflict as "Modi\'s war."';
  }

  /// Get relative time string from article's pubDate
  String _getTimeAgo() {
    if (widget.article.pubDate == null || widget.article.pubDate!.isEmpty) {
      return 'Just now';
    }

    // Parse the pubDate - format is "2025-11-24 00:00:00"
    final dateTime = DateFormatter.parseApiDate(widget.article.pubDate);

    if (dateTime == null) {
      return 'Just now';
    }

    return DateFormatter.getRelativeTime(dateTime);
  }

  @override
  Widget build(BuildContext context) {
    final bookmarkProvider = Provider.of<BookmarkProvider>(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Consumer<RemoteConfigProvider>(
        builder: (context, configProvider, child) {
          final config = configProvider.config;

          return Stack(
            children: [
              Column(
            children: [
              /// 🔹 HEADER IMAGE + OVERLAY
              Stack(
                children: [
                  // Background image
                  CachedNetworkImage(
                    imageUrl:
                        widget.article.imageUrl ??
                        widget.article.sourceIcon ??
                        '',
                    height: 380,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),

                  // Gradient Overlay
                  Container(
                    height: 380,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black87],
                      ),
                    ),
                  ),

                  // Top AppBar section
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          InkWell(
                            onTap: () => Navigator.pop(context),
                            borderRadius: BorderRadius.circular(25),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: Colors.black45,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.arrow_back,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          giveWidth(12),
                          showImage(
                            config.appNameLogo,
                            BoxFit.contain,
                            height: 60,
                            width: 80,
                          ),
                          const Spacer(),

                          // Bookmark + Share buttons
                        ],
                      ),
                    ),
                  ),

                  // Title overlay (bottom)
                  Positioned(
                    bottom: 35,
                    left: 20,
                    right: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.article.category?.first ?? "Politics",
                          style: GoogleFonts.inter(
                            color: config.primaryColorValue,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '"${widget.article.title}"',
                          style: GoogleFonts.playfairDisplay(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 22,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _getTimeAgo(),
                          style: GoogleFonts.inter(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              /// 🔹 CONTENT AREA
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 22,
                  ),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(22),
                      topRight: Radius.circular(22),
                    ),
                  ),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        /// AUDIO CONTROL BAR
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: config.primaryColorValue,
                                  borderRadius: BorderRadius.circular(25),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.graphic_eq_rounded,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                    giveWidth(4),
                                    const Icon(
                                      Icons.play_arrow,
                                      color: Colors.white,
                                      size: 22,
                                    ),
                                    Expanded(
                                      child: SliderTheme(
                                        data: SliderTheme.of(context).copyWith(
                                          trackHeight: 2,
                                          thumbShape:
                                              const RoundSliderThumbShape(
                                                enabledThumbRadius: 4,
                                              ),
                                        ),
                                        child: Slider(
                                          value: 0.4,
                                          onChanged: (v) {},
                                          activeColor: Colors.white,
                                          inactiveColor: Colors.white24,
                                        ),
                                      ),
                                    ),
                                    const Text(
                                      "1x",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            giveWidth(12),
                            showSaveButton(false, () {
                              bookmarkProvider.toggleBookmark(widget.article);
                            }),
                            giveWidth(12),
                            showShareButton(() {
                              Share.share(
                                '${widget.article.title}\n\n${widget.article.link ?? ''}',
                              );
                            }),
                          ],
                        ),
                        const SizedBox(height: 20),

                        /// ARTICLE CONTENT
                        // Display the main article content/description with saved text size
                        Text(
                          _getArticleContent(),
                          style: GoogleFonts.inriaSerif(
                            fontSize: _contentTextSize,
                            fontWeight: FontWeight.w500,
                            height: 1.6,
                            color: Colors.black87,
                          ),
                        ),
                        // Additional content paragraphs if available
                        if (widget.article.content != null &&
                            widget.article.content!.isNotEmpty &&
                            widget.article.content !=
                                'ONLY AVAILABLE IN PAID PLANS' &&
                            widget.article.content !=
                                widget.article.description) ...[
                          const SizedBox(height: 16),
                          Text(
                            '"I mean Modi\'s war because the road to peace runs, in part, through New Delhi," Navarro told Bloomberg Television\'s Balance of Power on Wednesday.',
                            style: GoogleFonts.inriaSerif(
                              fontSize: _contentTextSize,
                              height: 1.6,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'He argued that buying discounted Russian crude directly strengthens Moscow\'s military effort. "By purchasing Russian oil at a discount, Russia uses the money it gets to fund its war machine," he said. "Everybody in America loses because of what India is doing."',
                            style: GoogleFonts.inriaSerif(
                              fontSize: _contentTextSize,
                              height: 1.6,
                              color: Colors.black87,
                            ),
                          ),
                        ] else ...[
                          const SizedBox(height: 16),
                          Text(
                            '"I mean Modi\'s war because the road to peace runs, in part, through New Delhi," Navarro told Bloomberg Television\'s Balance of Power on Wednesday.',
                            style: GoogleFonts.inriaSerif(
                              fontSize: _contentTextSize,
                              height: 1.6,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'He argued that buying discounted Russian crude directly strengthens Moscow\'s military effort. "By purchasing Russian oil at a discount, Russia uses the money it gets to fund its war machine," he said. "Everybody in America loses because of what India is doing."',
                            style: GoogleFonts.inriaSerif(
                              fontSize: _contentTextSize,
                              height: 1.6,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                        const SizedBox(height: 22),
                        // Subheading with slightly larger text
                        Text(
                          'India-US tariffs: 50 percent tariffs come into force',
                          style: GoogleFonts.inriaSerif(
                            fontSize: _contentTextSize + 1,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'The criticism coincided with the start of new tariffs on Indian goods ordered by President Donald Trump. The additional 25 percent duty has doubled the rate to 50 percent, hitting more than 55 percent of India\'s exports to the US.',
                          style: GoogleFonts.inriaSerif(
                            fontSize: _contentTextSize,
                            height: 1.7,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 32),

                        /// PAGE INDICATOR
                        Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: List.generate(
                              6,
                              (index) => Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 3,
                                ),
                                width: index == 2 ? 18 : 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color:
                                      index == 2
                                          ? config.primaryColorValue
                                          : Colors.grey.shade300,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

              // Audio Loading Overlay
              const AudioLoadingOverlay(),
            ],
          );
        },
      ),
    );
  }
}
