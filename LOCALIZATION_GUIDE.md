# Localization Implementation Guide

This document explains how to use the comprehensive localization system implemented in the NewsOn app.

## Overview

The app now supports multiple languages with a well-architected localization system using Flutter's built-in `intl` package and ARB (Application Resource Bundle) files.

## Supported Languages

- English (en) - Default
- Hindi (hi)
- Spanish (es)
- French (fr)
- German (de)
- Chinese (zh)
- Japanese (ja)
- Arabic (ar)
- Portuguese (pt)
- Russian (ru)

## Architecture

### 1. ARB Files
Translation files are located in `lib/l10n/`:
- `app_en.arb` - English translations
- `app_hi.arb` - Hindi translations
- `app_es.arb` - Spanish translations
- `app_fr.arb` - French translations
- (Additional languages can be added similarly)

### 2. Language Provider
`LanguageProvider` manages the current locale and provides methods to change languages.

### 3. Localization Helper
`LocalizationHelper` provides convenient static methods to access localized strings.

## Usage

### Method 1: Using LocalizationHelper (Recommended)

```dart
import 'package:newson/core/utils/localization_helper.dart';

// In your widget
Text(LocalizationHelper.welcomeTo(context))
Text(LocalizationHelper.signIn(context))
Text(LocalizationHelper.continueText(context))
```

### Method 2: Direct Access via AppLocalizations

```dart
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

// In your widget
final l10n = AppLocalizations.of(context)!;
Text(l10n.welcomeTo)
Text(l10n.signIn)
Text(l10n.continueText)
```

### Method 3: Using Consumer for Language Changes

```dart
import 'package:provider/provider.dart';
import 'package:newson/providers/language_provider.dart';

Consumer<LanguageProvider>(
  builder: (context, languageProvider, child) {
    return DropdownButton<String>(
      value: languageProvider.selectedLanguage,
      items: languageProvider.languageNames.map((String language) {
        return DropdownMenuItem<String>(
          value: language,
          child: Text(language),
        );
      }).toList(),
      onChanged: (String? newLanguage) {
        if (newLanguage != null) {
          languageProvider.setLanguage(newLanguage);
        }
      },
    );
  },
)
```

## Adding New Translations

### Step 1: Add to English ARB File

Edit `lib/l10n/app_en.arb`:

```json
{
  "myNewString": "My New String",
  "@myNewString": {
    "description": "Description of what this string is for"
  }
}
```

### Step 2: Add to Other Language ARB Files

Add the same key to all other language files with appropriate translations:

`lib/l10n/app_hi.arb`:
```json
{
  "myNewString": "मेरी नई स्ट्रिंग"
}
```

### Step 3: Regenerate Localization Files

Run:
```bash
flutter gen-l10n
```

### Step 4: Add to LocalizationHelper (Optional)

Add a helper method in `lib/core/utils/localization_helper.dart`:

```dart
static String myNewString(BuildContext context) {
  return of(context).myNewString;
}
```

## Examples

### Example 1: Basic Text

```dart
// Before
Text('Sign In')

// After
Text(LocalizationHelper.signIn(context))
```

### Example 2: Text with Parameters

```dart
// Before
Text('Sign-in failed: $error')

// After
Text(LocalizationHelper.signInFailed(context, error))
```

### Example 3: Button Text

```dart
// Before
ElevatedButton(
  onPressed: () {},
  child: Text('Continue'),
)

// After
ElevatedButton(
  onPressed: () {},
  child: Text(LocalizationHelper.continueText(context)),
)
```

### Example 4: SnackBar Messages

```dart
// Before
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(content: Text('Added to bookmarks')),
);

// After
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(content: Text(LocalizationHelper.addedToBookmarks(context))),
);
```

### Example 5: Dialog Titles

```dart
// Before
showDialog(
  context: context,
  builder: (context) => AlertDialog(
    title: Text('Clear all bookmarks?'),
    // ...
  ),
);

// After
showDialog(
  context: context,
  builder: (context) => AlertDialog(
    title: Text(LocalizationHelper.clearAllBookmarks(context)),
    // ...
  ),
);
```

## Language Switching

The language can be changed programmatically:

```dart
final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

// Change by language name
await languageProvider.setLanguage('Hindi');

// Change by locale
await languageProvider.setLocale(const Locale('hi'));
```

The app will automatically update all localized strings when the language changes.

## Best Practices

1. **Always use localization for user-facing text** - Never hardcode strings that users will see
2. **Use LocalizationHelper for consistency** - It provides a clean API and ensures consistent usage
3. **Add descriptions in ARB files** - This helps translators understand context
4. **Test with different languages** - Ensure UI layouts work with longer/shorter translations
5. **Keep keys descriptive** - Use clear, descriptive keys like `signIn` instead of `btn1`

## Available Localized Strings

All available strings can be found in `lib/l10n/app_en.arb`. Common strings include:

- `appName` - Application name
- `welcomeTo` - Welcome text
- `signIn` - Sign in button
- `skip` - Skip button
- `continueText` - Continue button
- `categories` - Categories tab
- `bookmarks` - Bookmarks tab
- `search` - Search tab
- `retry` - Retry button
- `cancel` - Cancel button
- `clear` - Clear button
- And many more...

## Troubleshooting

### Localization not working?

1. Ensure `flutter gen-l10n` has been run
2. Check that `l10n.yaml` exists in the project root
3. Verify `pubspec.yaml` has `generate: true` in the flutter section
4. Make sure `MaterialApp` has `localizationsDelegates` and `supportedLocales` configured

### Strings not updating after language change?

1. Ensure you're using `Consumer<LanguageProvider>` or accessing strings through context
2. Check that `LanguageProvider` is properly notifying listeners
3. Verify the locale is being set correctly in `MaterialApp`

## Next Steps

To complete the localization implementation:

1. Replace all hardcoded strings in screens with localized versions
2. Add more translations for additional languages as needed
3. Test language switching across all screens
4. Consider adding RTL (Right-to-Left) support for Arabic and Hebrew

