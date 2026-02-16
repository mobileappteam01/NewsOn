import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/language_provider.dart';
import '../../providers/dynamic_language_provider.dart';
import '../../providers/remote_config_provider.dart';
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
        
        // Use dynamic active languages if available, otherwise fall back to static list
        // Only show languages with isActive=true
        final languageNames = dynamicProvider.isInitialized && dynamicProvider.activeLanguages.isNotEmpty
            ? dynamicProvider.languageNames
            : languageProvider.languageNames;

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
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      showImage(
                        config.languageImg,
                        BoxFit.contain,
                        height: 20,
                        width: 30,
                      ),

                      Text(
                        _isNews ? 'Select News Language' : 'Select App Language',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),

                // Loading indicator if dynamic provider is loading
                if (dynamicProvider.isLoading)
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  ),

                // Language List
                if (!dynamicProvider.isLoading)
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: languageNames.length,
                      itemBuilder: (context, index) {
                        final languageName = languageNames[index];
                        final isSelected = languageName == _selectedLanguage;
                        
                        // Get native name if using dynamic provider (only from active languages)
                        String displayName = languageName;
                        if (dynamicProvider.isInitialized && dynamicProvider.activeLanguages.isNotEmpty) {
                          final lang = dynamicProvider.activeLanguages[index];
                          displayName = '${lang.name} (${lang.nativeName})';
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
                        child: const Text(
                          'Cancel',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () async {
                          if (_selectedLanguage != null) {
                            if (_isNews) {
                              await languageProvider.setNewsLanguage(_selectedLanguage!);
                              if (mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'News language changed to $_selectedLanguage',
                                    ),
                                    duration: const Duration(seconds: 2),
                                    backgroundColor: config.primaryColorValue,
                                  ),
                                );
                              }
                            } else {
                              if (dynamicProvider.isInitialized) {
                                await dynamicProvider.setLanguage(_selectedLanguage!);
                              }
                              await languageProvider.setLanguage(_selectedLanguage!);
                              if (mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'App language changed to $_selectedLanguage',
                                    ),
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
                        child: const Text(
                          'Submit',
                          style: TextStyle(
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
