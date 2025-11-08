// ignore_for_file: must_be_immutable, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:newson/core/utils/shared_functions.dart';
import 'package:provider/provider.dart';

import '../data/models/remote_config_model.dart';
import '../providers/remote_config_provider.dart';

class NewsGridView extends StatelessWidget {
  final String type;
  final Map newsDetails;
  Function onListenTapped;
  Function onNewsTapped;
  Function onSaveTapped;
  Function onShareTapped;
  NewsGridView({
    super.key,
    required this.type,
    required this.newsDetails,
    required this.onListenTapped,
    required this.onNewsTapped,
    required this.onSaveTapped,
    required this.onShareTapped,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<RemoteConfigProvider>(
      builder: (context, configProvider, child) {
        final config = configProvider.config;

        // final isDark = theme.brightness == Brightness.dark;

        return type.toLowerCase() == 'listview'
            ? showListView(config, newsDetails, context)
            : type.toLowerCase() == 'cardview'
            ? showCardView(config, newsDetails, context)
            : type.toLowerCase() == 'thumbnail'
            ? showThumbNailView(config, newsDetails, context)
            : type.toLowerCase() == 'detailedview'
            ? showDetailedView(config, newsDetails, context)
            : type.toLowerCase() == 'bannerview'
            ? showBannerView(config, newsDetails, context)
            : showListView(config, newsDetails, context);
      },
    );
  }

  showCommonWidget(RemoteConfigModel config, String type, Map newsDetails) {
    return type.toLowerCase() == 'category'
        ? Text(
          newsDetails['category'],
          style: GoogleFonts.inter(
            color: config.primaryColorValue,
            fontWeight: FontWeight.w500,
            fontSize: 11,
          ),
        )
        : type.toLowerCase() == 'postedtime'
        ? Text(
          newsDetails['updatedAt'],
          style: GoogleFonts.inter(color: config.primaryColorValue),
        )
        : GestureDetector(
          onTap: () => onSaveTapped(), // ✅ FIXED
          child: Icon(Icons.bookmark, color: Colors.black),
        );
  }

  showListenButton(RemoteConfigModel config, BuildContext context) {
    return GestureDetector(
      onTap: () => onListenTapped(), // ✅ FIXED
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: config.primaryColorValue,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            showImage(config.listenIcon, BoxFit.contain, height: 15, width: 15),
            giveWidth(12),
            Text(
              'Listen',
              style: GoogleFonts.playfair(
                color: Colors.white,
                fontWeight: FontWeight.w400,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  showRoundedListenButton(RemoteConfigModel config, BuildContext context) {
    return GestureDetector(
      onTap: () => onListenTapped(),
      child: Center(
        child: Container(
          height: 50,
          width: 50,
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: config.primaryColorValue,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: showImage(
              config.listenIcon,
              BoxFit.contain,
              height: 15,
              width: 15,
            ),
          ),
        ),
      ),
    );
  }

  showShareButton() {
    return GestureDetector(
      onTap: () => onShareTapped(),
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.rotationY(3.1416), // 180° flip horizontally
        child: Icon(Icons.reply_outlined, size: 24, color: Colors.black),
      ),
    );
  }

  showListView(
    RemoteConfigModel config,
    Map newsDetails,
    BuildContext context,
  ) {
    return GestureDetector(
      onTap: () => onNewsTapped(),
      child: SizedBox(
        height: 200,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            showImage(
              newsDetails['img'],
              BoxFit.contain,
              height: 200,
              width: MediaQuery.of(context).size.width / 2.5,
            ),
            SizedBox(
              width: MediaQuery.of(context).size.width / 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  showCommonWidget(config, 'category', newsDetails),
                  giveHeight(3),
                  SizedBox(
                    height: 90,

                    child: Text(
                      newsDetails['headLines'],
                      style: GoogleFonts.inriaSerif(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                      overflow: TextOverflow.visible,
                    ),
                  ),
                  giveHeight(3),
                  showCommonWidget(config, 'postedtime', newsDetails),
                  giveHeight(3),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      showListenButton(config, context),
                      showCommonWidget(config, 'save', newsDetails),
                      showShareButton(),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  showCardView(
    RemoteConfigModel config,
    Map newsDetails,
    BuildContext context,
  ) {
    return GestureDetector(
      onTap: () => onNewsTapped(),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),

          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 🖼 Background image
              showImage(newsDetails['img'], BoxFit.cover),

              // 🌑 Gradient overlay for readability
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.85),
                    ],
                  ),
                ),
              ),

              // 🔤 Bottom content
              Positioned(
                bottom: 20,
                left: 16,
                right: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      newsDetails['category'] ?? "Hot News",
                      style: GoogleFonts.inter(
                        color: const Color(0xFFE31E24),
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      newsDetails['headLines'] ?? '',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 20,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        height: 1.3,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [showListenButton(config, context)],
                    ),
                  ],
                ),
              ),

              // 🔖 Top-right bookmark
              Positioned(
                top: 12,
                right: 12,
                child: IconButton(
                  icon: const Icon(
                    Icons.bookmark_border,
                    color: Colors.white,
                    size: 24,
                  ),
                  onPressed: () => onSaveTapped(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  showBannerView(
    RemoteConfigModel config,
    Map newsDetails,
    BuildContext context,
  ) {
    return GestureDetector(
      onTap: () => onNewsTapped(),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),

          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 🖼 Background image
              showImage(newsDetails['img'], BoxFit.cover),

              // 🌑 Gradient overlay for readability
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.85),
                    ],
                  ),
                ),
              ),

              // 🔤 Bottom content
              Positioned(
                bottom: 20,
                left: 16,
                right: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    showRoundedListenButton(config, context),
                    const SizedBox(height: 14),
                    Text(
                      newsDetails['headLines'] ?? '',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        height: 1.3,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  showThumbNailView(
    RemoteConfigModel config,
    Map newsDetails,
    BuildContext context,
  ) {}

  showDetailedView(
    RemoteConfigModel config,
    Map newsDetails,
    BuildContext context,
  ) {}
}
