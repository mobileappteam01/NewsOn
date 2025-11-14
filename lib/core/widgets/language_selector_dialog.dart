import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/language_provider.dart';
import '../../providers/remote_config_provider.dart';
import '../utils/shared_functions.dart';

/// Language selector dialog with submit button
class LanguageSelectorDialog extends StatefulWidget {
  const LanguageSelectorDialog({super.key});

  @override
  State<LanguageSelectorDialog> createState() => _LanguageSelectorDialogState();
}

class _LanguageSelectorDialogState extends State<LanguageSelectorDialog> {
  String? _selectedLanguage;

  @override
  void initState() {
    super.initState();
    // Initialize with current language
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final languageProvider = Provider.of<LanguageProvider>(
        context,
        listen: false,
      );
      setState(() {
        _selectedLanguage = languageProvider.selectedLanguage;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(
      context,
      listen: false,
    );

    if (_selectedLanguage == null) {
      _selectedLanguage = languageProvider.selectedLanguage;
    }

    return Consumer<RemoteConfigProvider>(
      builder: (context, configProvider, child) {
        final config = configProvider.config;
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

                      const Text(
                        'Select Language',
                        style: TextStyle(
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

                // Language List
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: languageProvider.supportedLanguages.length,
                    itemBuilder: (context, index) {
                      final language =
                          languageProvider.supportedLanguages[index];
                      final isSelected = language == _selectedLanguage;

                      return InkWell(
                        onTap: () {
                          setState(() {
                            _selectedLanguage = language;
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
                              Text(
                                language,
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
                        onPressed: () {
                          if (_selectedLanguage != null) {
                            languageProvider.setLanguage(_selectedLanguage!);
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Language changed to $_selectedLanguage',
                                ),
                                duration: const Duration(seconds: 2),
                                backgroundColor: config.primaryColorValue,
                              ),
                            );
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

/// Helper function to show language selector dialog
void showLanguageSelectorDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => const LanguageSelectorDialog(),
  );
}
