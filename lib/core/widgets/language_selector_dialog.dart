import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/language_provider.dart';
import '../../providers/dynamic_language_provider.dart';
import '../../providers/remote_config_provider.dart';
import '../utils/localization_helper.dart';
import '../utils/shared_functions.dart';

/// Whether the dialog is selecting app language (UI) or news language (content only).
enum LanguageSelectorType {
  /// App language: menus, labels, entire app UI.
  app,
  /// News language: language of news articles only.
  news,
}

/// Language selector dialog with submit button.
/// [type] = app: changes app UI language. [type] = news: changes only news content language.
class LanguageSelectorDialog extends StatefulWidget {
  const LanguageSelectorDialog({super.key, this.type = LanguageSelectorType.app});

  final LanguageSelectorType type;

  @override
  State<LanguageSelectorDialog> createState() => _LanguageSelectorDialogState();
}

class _LanguageSelectorDialogState extends State<LanguageSelectorDialog> {
  String? _selectedLanguage;

  bool get _isNews => widget.type == LanguageSelectorType.news;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final dynamicProvider = Provider.of<DynamicLanguageProvider>(
        context,
        listen: false,
      );
      final languageProvider = Provider.of<LanguageProvider>(
        context,
        listen: false,
      );
      setState(() {
        if (_isNews) {
          _selectedLanguage = languageProvider.newsLanguageName;
        } else {
          _selectedLanguage = dynamicProvider.isInitialized
              ? dynamicProvider.selectedLanguage
              : languageProvider.selectedLanguage;
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<RemoteConfigProvider, DynamicLanguageProvider>(
      builder: (context, configProvider, dynamicProvider, child) {
        final config = configProvider.config;
        final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
        
        // App UI languages: Firebase dynamic list (or static fallback).
        // News languages: dedicated list (English, Tamil, Hindi, Malayalam, Telugu, Kannada).
        final languageNames = _isNews
            ? languageProvider.newsLanguageNames
            : (dynamicProvider.isInitialized &&
                    dynamicProvider.activeLanguages.isNotEmpty
                ? dynamicProvider.languageNames
                : languageProvider.languageNames);

        if (_selectedLanguage == null) {
          if (_isNews) {
            _selectedLanguage = languageProvider.newsLanguageName;
          } else {
            _selectedLanguage = dynamicProvider.isInitialized
                ? dynamicProvider.selectedLanguage
                : languageProvider.selectedLanguage;
          }
        }

        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: config.primaryColorValue,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      _LanguageDialogLogo(
                        networkUrl: config.languageImg,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _isNews
                              ? LocalizationHelper.selectNewsLanguage(context)
                              : LocalizationHelper.selectAppLanguage(context),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 40,
                          minHeight: 40,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),

                // Loading indicator (app language waits for Firebase; news list is local)
                if (!_isNews && dynamicProvider.isLoading)
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  ),

                // Language List
                if (_isNews || !dynamicProvider.isLoading)
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: languageNames.length,
                      itemBuilder: (context, index) {
                        final languageName = languageNames[index];
                        final isSelected = languageName == _selectedLanguage;
                        
                        String displayName = languageName;
                        if (_isNews) {
                          final nativeName =
                              languageProvider.nativeNameForNewsLanguage(
                            languageName,
                          );
                          displayName = '$languageName ($nativeName)';
                        } else if (dynamicProvider.isInitialized &&
                            dynamicProvider.activeLanguages.isNotEmpty) {
                          final matches = dynamicProvider.activeLanguages
                              .where((l) => l.name == languageName)
                              .toList();
                          if (matches.isNotEmpty) {
                            final lang = matches.first;
                            displayName = '${lang.name} (${lang.nativeName})';
                          }
                        }

                        return InkWell(
                          onTap: () {
                            setState(() {
                              _selectedLanguage = languageName;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 16,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  isSelected
                                      ? config.primaryColorValue.withOpacity(0.1)
                                      : null,
                              border: Border(
                                left: BorderSide(
                                  color:
                                      isSelected
                                          ? config.primaryColorValue
                                          : Colors.transparent,
                                  width: 4,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isSelected
                                      ? Icons.radio_button_checked
                                      : Icons.radio_button_unchecked,
                                  color:
                                      isSelected
                                          ? config.primaryColorValue
                                          : Colors.grey,
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Text(
                                    displayName,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight:
                                          isSelected
                                              ? FontWeight.w600
                                              : FontWeight.normal,
                                      color:
                                          isSelected
                                              ? config.primaryColorValue
                                              : null,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                // Footer with Submit Button
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          LocalizationHelper.cancel(context),
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () async {
                          if (_selectedLanguage != null) {
                            if (_isNews) {
                              await languageProvider.setNewsLanguage(_selectedLanguage!);
                              if (context.mounted) {
                                final message =
                                    LocalizationHelper.newsLanguageChangedTo(
                                  context,
                                  languageProvider.nativeNameForNewsLanguage(
                                    _selectedLanguage!,
                                  ),
                                );
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(message),
                                    duration: const Duration(seconds: 2),
                                    backgroundColor: config.primaryColorValue,
                                  ),
                                );
                              }
                            } else {
                              // App UI language: keep Dynamic + Language providers in sync.
                              // Dynamic translations must finish loading before UI rebuilds.
                              if (!dynamicProvider.isInitialized) {
                                await dynamicProvider.initialize();
                              }
                              await dynamicProvider
                                  .setLanguage(_selectedLanguage!);
                              await languageProvider
                                  .setLanguage(_selectedLanguage!);
                              if (context.mounted) {
                                final nativeName =
                                    dynamicProvider.currentLanguage?.nativeName;
                                final message =
                                    LocalizationHelper.appLanguageChangedTo(
                                  context,
                                  nativeName == null || nativeName.isEmpty
                                      ? _selectedLanguage!
                                      : nativeName,
                                );
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(message),
                                    duration: const Duration(seconds: 2),
                                    backgroundColor: config.primaryColorValue,
                                  ),
                                );
                              }
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: config.primaryColorValue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          LocalizationHelper.submit(context),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Shows dialog to select news content language only (used on news feed header).
void showNewsLanguageSelectorDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => const LanguageSelectorDialog(
      type: LanguageSelectorType.news,
    ),
  );
}

/// Shows dialog to select app UI language (used in Application Settings).
void showAppLanguageSelectorDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => const LanguageSelectorDialog(
      type: LanguageSelectorType.app,
    ),
  );
}

/// Legacy: defaults to app language. Prefer [showAppLanguageSelectorDialog] or [showNewsLanguageSelectorDialog].
void showLanguageSelectorDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => const LanguageSelectorDialog(
      type: LanguageSelectorType.app,
    ),
  );
}

/// Language dialog brand mark — prefers bundled asset so shimmer never sticks
/// when Firebase `languageImg` is empty or fails to load.
class _LanguageDialogLogo extends StatelessWidget {
  const _LanguageDialogLogo({this.networkUrl});

  final String? networkUrl;

  @override
  Widget build(BuildContext context) {
    final url = networkUrl?.trim() ?? '';
    final asset = Image.asset(
      kNewsOnLogoAsset,
      height: 20,
      width: 30,
      fit: BoxFit.contain,
      color: Colors.white,
      colorBlendMode: BlendMode.srcIn,
      errorBuilder: (_, __, ___) => const Icon(
        Icons.language,
        color: Colors.white,
        size: 20,
      ),
    );

    if (url.isEmpty) return asset;

    return Image.network(
      url,
      height: 20,
      width: 30,
      fit: BoxFit.contain,
      color: Colors.white,
      colorBlendMode: BlendMode.srcIn,
      errorBuilder: (_, __, ___) => asset,
      // Never leave an indefinite shimmer — blank until first frame, then asset.
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded || frame != null) return child;
        return asset;
      },
    );
  }
}
