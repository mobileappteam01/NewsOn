import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:newson/core/utils/shared_functions.dart';
import 'package:provider/provider.dart';

import '../data/models/remote_config_model.dart';
import '../providers/remote_config_provider.dart';

class NewsGridView extends StatelessWidget {
  final String type;
  final Map newsDetails;
  const NewsGridView({
    super.key,
    required this.type,
    required this.newsDetails,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<RemoteConfigProvider>(
      builder: (context, configProvider, child) {
        final config = configProvider.config;

        // final isDark = theme.brightness == Brightness.dark;

        return type.toLowerCase() == 'listview'
            ? showListView(config, newsDetails, context)
            : type.toLowerCase() == 'cardView'
            ? showCardView(config, newsDetails, context)
            : type.toLowerCase() == 'thumbnail'
            ? showThumbNailView(config, newsDetails, context)
            : type.toLowerCase() == 'detailedview'
            ? showDetailedView(config, newsDetails, context)
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
        : Icon(
          // newsDetails['isSaved'] ?
          Icons.bookmark,
          //  : Icons.bookmark_border
          color: Colors.black,
        );
  }

  showListenButton(RemoteConfigModel config, BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
    );
  }

  showShareButton() {
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.rotationY(3.1416), // 180° flip horizontally
      child: Icon(Icons.reply_outlined, size: 24, color: Colors.black),
    );
  }

  showListView(
    RemoteConfigModel config,
    Map newsDetails,
    BuildContext context,
  ) {
    return SizedBox(
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
    );
  }

  showCardView(
    RemoteConfigModel config,
    Map newsDetails,
    BuildContext context,
  ) {}

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
