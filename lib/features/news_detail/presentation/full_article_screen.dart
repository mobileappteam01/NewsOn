import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/utils/localization_helper.dart';

/// Full publisher article experience using existing [url_launcher]
/// (no new WebView dependency in Phase 2A — SDK constraint with AdMob).
class FullArticleScreen extends StatefulWidget {
  const FullArticleScreen({
    super.key,
    required this.url,
    required this.title,
    this.publisherName,
  });

  final String url;
  final String title;
  final String? publisherName;

  @override
  State<FullArticleScreen> createState() => _FullArticleScreenState();
}

class _FullArticleScreenState extends State<FullArticleScreen> {
  var _loading = true;
  var _error = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _open());
  }

  Future<void> _open() async {
    setState(() {
      _loading = true;
      _error = false;
      _errorMessage = null;
    });

    final uri = Uri.tryParse(widget.url);
    if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
      setState(() {
        _loading = false;
        _error = true;
        _errorMessage = 'Invalid article URL';
      });
      return;
    }

    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!mounted) return;
      if (!ok) {
        setState(() {
          _loading = false;
          _error = true;
          _errorMessage = 'Unable to open article';
        });
        return;
      }
      setState(() => _loading = false);
      // Return to NewsOn after handing off to the browser.
      if (mounted) Navigator.of(context).maybePop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = true;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16),
            ),
            if (widget.publisherName != null &&
                widget.publisherName!.isNotEmpty)
              Text(
                widget.publisherName!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).hintColor,
                ),
              ),
          ],
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _loading
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(LocalizationHelper.v2ViewFullArticle(context)),
                  ],
                )
              : _error
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.link_off, size: 48),
                        const SizedBox(height: 12),
                        Text(
                          _errorMessage ??
                              LocalizationHelper.v2SummaryUnavailable(context),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _open,
                          child: Text(LocalizationHelper.v2Retry(context)),
                        ),
                      ],
                    )
                  : Text(LocalizationHelper.v2ReadFullStory(context)),
        ),
      ),
    );
  }
}
