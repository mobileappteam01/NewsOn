# Localization Setup Instructions

## Important: Generate Localization Files First

Before running the app, you **must** generate the localization files by running:

```bash
flutter gen-l10n
```

This command will:
1. Read the ARB files from `lib/l10n/`
2. Generate `AppLocalizations` class in `.dart_tool/flutter_gen/gen_l10n/`
3. Create the necessary localization delegates

## After Generation

Once you run `flutter gen-l10n`, the following files will be generated:
- `.dart_tool/flutter_gen/gen_l10n/app_localizations.dart`
- `.dart_tool/flutter_gen/gen_l10n/app_localizations_en.dart`
- `.dart_tool/flutter_gen/gen_l10n/app_localizations_hi.dart`
- `.dart_tool/flutter_gen/gen_l10n/app_localizations_es.dart`
- `.dart_tool/flutter_gen/gen_l10n/app_localizations_fr.dart`
- And more for each language...

## Verification

After running `flutter gen-l10n`, you should see:
- ✅ No errors in `lib/main.dart` related to `AppLocalizations`
- ✅ No errors in `lib/core/utils/localization_helper.dart`
- ✅ The app compiles successfully

## Troubleshooting

If you see errors like:
- `Target of URI doesn't exist: 'package:flutter_gen/gen_l10n/app_localizations.dart'`
- `Undefined class 'AppLocalizations'`

**Solution:** Run `flutter gen-l10n` to generate the files.

## Adding New Languages

1. Create a new ARB file: `lib/l10n/app_<locale>.arb` (e.g., `app_de.arb` for German)
2. Copy the structure from `app_en.arb` and translate all strings
3. Run `flutter gen-l10n` again
4. Add the locale to `LanguageProvider.supportedLanguages` if needed

## Notes

- The `flutter_localizations` package is part of the Flutter SDK, so no additional dependency is needed
- The `intl` package is already in your `pubspec.yaml`
- Make sure `generate: true` is set in `pubspec.yaml` under the `flutter:` section

