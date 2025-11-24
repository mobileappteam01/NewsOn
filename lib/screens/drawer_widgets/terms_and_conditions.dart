import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:shimmer/shimmer.dart';

import '../../core/utils/shared_functions.dart';
import '../../core/utils/localization_helper.dart';
import '../../providers/remote_config_provider.dart';
import '../../data/services/content_api_service.dart';
import '../../data/models/remote_config_model.dart';

class TermsAndConditions extends StatefulWidget {
  const TermsAndConditions({super.key});

  @override
  State<TermsAndConditions> createState() => _TermsAndConditionsState();
}

class _TermsAndConditionsState extends State<TermsAndConditions> {
  final ContentApiService _contentApiService = ContentApiService();
  String? _htmlContent;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  Future<void> _loadContent() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final content = await _contentApiService.getTermsAndConditions();
      if (mounted) {
        setState(() {
          _htmlContent = content;
          _isLoading = false;
          if (content == null || content.isEmpty) {
            _error = 'Terms and Conditions not available';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load Terms and Conditions: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Consumer<RemoteConfigProvider>(
      builder: (context, configProvider, child) {
        final config = configProvider.config;

        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          body: SafeArea(
            child: Column(
              children: [
                // App Bar
                commonappBar(config.appNameLogo, () {
                  Navigator.pop(context);
                }),

                // Title
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    LocalizationHelper.termsAndConditions(context),
                    style: GoogleFonts.playfairDisplay(
                      color: config.primaryColorValue,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                // Content
                Expanded(
                  child:
                      _isLoading
                          ? _buildShimmerLoader(isDark)
                          : _error != null
                          ? _buildErrorWidget(_error!, config)
                          : _htmlContent != null
                          ? _buildContent(_htmlContent!, isDark, config)
                          : _buildEmptyWidget(config),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildShimmerLoader(bool isDark) {
    final baseColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;
    final highlightColor = isDark ? Colors.grey[700]! : Colors.grey[100]!;

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: List.generate(
          10,
          (index) => Container(
            height: 20,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: baseColor,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorWidget(String error, RemoteConfigModel config) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              error,
              style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadContent,
              style: ElevatedButton.styleFrom(
                backgroundColor: config.primaryColorValue,
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyWidget(RemoteConfigModel config) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.description_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Terms and Conditions not available',
              style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(
    String htmlContent,
    bool isDark,
    RemoteConfigModel config,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Html(
        data: htmlContent,
        style: {
          'body': Style(
            margin: Margins.zero,
            padding: HtmlPaddings.zero,
            color: isDark ? Colors.white : Colors.black87,
            fontSize: FontSize(16),
            lineHeight: const LineHeight(1.6),
          ),
          'h1': Style(
            color: config.primaryColorValue,
            fontSize: FontSize(24),
            fontWeight: FontWeight.bold,
            margin: Margins.only(bottom: 16),
          ),
          'h2': Style(
            color: isDark ? Colors.white : Colors.black87,
            fontSize: FontSize(20),
            fontWeight: FontWeight.bold,
            margin: Margins.only(top: 24, bottom: 12),
          ),
          'p': Style(
            margin: Margins.only(bottom: 12),
            fontSize: FontSize(16),
            lineHeight: const LineHeight(1.6),
          ),
          'ul': Style(margin: Margins.only(bottom: 12, left: 20)),
          'li': Style(margin: Margins.only(bottom: 8)),
          'blockquote': Style(
            margin: Margins.only(bottom: 16),
            padding: HtmlPaddings.all(16),
            border: Border(
              left: BorderSide(color: config.primaryColorValue, width: 4),
            ),
          ),
          'b': Style(fontWeight: FontWeight.bold),
          'u': Style(textDecoration: TextDecoration.underline),
        },
      ),
    );
  }
}
