import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_hi.dart';
import 'app_localizations_ta.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('hi'),
    Locale('ta')
  ];

  /// Application name
  ///
  /// In en, this message translates to:
  /// **'NewsOn'**
  String get appName;

  /// Welcome text on splash screen
  ///
  /// In en, this message translates to:
  /// **'WELCOME TO'**
  String get welcomeTo;

  /// Swipe button text on splash screen
  ///
  /// In en, this message translates to:
  /// **'Swipe To Get Started'**
  String get swipeToGetStarted;

  /// Sign in button text
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signIn;

  /// Sign in description text
  ///
  /// In en, this message translates to:
  /// **'Sign in to your account'**
  String get signInToYourAccount;

  /// Loading message when connecting
  ///
  /// In en, this message translates to:
  /// **'Connecting...'**
  String get connecting;

  /// Loading message when connecting to Google
  ///
  /// In en, this message translates to:
  /// **'Connecting to Google...'**
  String get connectingToGoogle;

  /// Welcome message
  ///
  /// In en, this message translates to:
  /// **'Welcome!'**
  String get welcome;

  /// Message when user cancels sign-in
  ///
  /// In en, this message translates to:
  /// **'Sign-in cancelled'**
  String get signInCancelled;

  /// Error message when sign-in fails
  ///
  /// In en, this message translates to:
  /// **'Sign-in failed: {error}'**
  String signInFailed(String error);

  /// Skip button text
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// Continue button text
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueText;

  /// Placeholder text for name input
  ///
  /// In en, this message translates to:
  /// **'Enter your name'**
  String get enterYourName;

  /// Title for category selection screen
  ///
  /// In en, this message translates to:
  /// **'Select Categories'**
  String get selectCategories;

  /// Error message when no category is selected
  ///
  /// In en, this message translates to:
  /// **'Please select at least one category'**
  String get selectAtLeastOneCategory;

  /// Categories tab title
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get categories;

  /// Bookmarks tab title
  ///
  /// In en, this message translates to:
  /// **'Bookmarks'**
  String get bookmarks;

  /// Search tab title
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// Bottom navigation headlines label
  ///
  /// In en, this message translates to:
  /// **'Headlines'**
  String get headlines;

  /// News feed tab title
  ///
  /// In en, this message translates to:
  /// **'News Feed'**
  String get newsFeed;

  /// Retry button text
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// Message when no news is available
  ///
  /// In en, this message translates to:
  /// **'No news available'**
  String get noNewsAvailable;

  /// Message when search returns no results
  ///
  /// In en, this message translates to:
  /// **'No results found'**
  String get noResultsFound;

  /// Confirmation dialog title for clearing bookmarks
  ///
  /// In en, this message translates to:
  /// **'Clear all bookmarks?'**
  String get clearAllBookmarks;

  /// Cancel button text
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Clear button text
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// Success message when bookmarks are cleared
  ///
  /// In en, this message translates to:
  /// **'All bookmarks cleared'**
  String get allBookmarksCleared;

  /// Success message when article is bookmarked
  ///
  /// In en, this message translates to:
  /// **'Added to bookmarks'**
  String get addedToBookmarks;

  /// Success message when bookmark is removed
  ///
  /// In en, this message translates to:
  /// **'Removed from bookmarks'**
  String get removedFromBookmarks;

  /// Error message for no internet connection
  ///
  /// In en, this message translates to:
  /// **'No internet connection. Please check your network.'**
  String get noInternetConnection;

  /// Error message for server error
  ///
  /// In en, this message translates to:
  /// **'Server error. Please try again later.'**
  String get serverError;

  /// Error message for unknown error
  ///
  /// In en, this message translates to:
  /// **'An unknown error occurred.'**
  String get unknownError;

  /// Message when no data is available
  ///
  /// In en, this message translates to:
  /// **'No data available.'**
  String get noDataAvailable;

  /// Generic error message
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String error(String error);

  /// Success message when text size is saved
  ///
  /// In en, this message translates to:
  /// **'Text size saved'**
  String get textSizeSaved;

  /// Success message when form is submitted
  ///
  /// In en, this message translates to:
  /// **'Form submitted successfully!'**
  String get formSubmittedSuccessfully;

  /// Error message when form has validation errors
  ///
  /// In en, this message translates to:
  /// **'Please fix errors before saving'**
  String get pleaseFixErrorsBeforeSaving;

  /// Account settings menu item
  ///
  /// In en, this message translates to:
  /// **'Account Settings'**
  String get accountSettings;

  /// Appearance settings menu item
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearanceSettings;

  /// Application settings menu item
  ///
  /// In en, this message translates to:
  /// **'Application Settings'**
  String get applicationSettings;

  /// Notifications menu item
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// Privacy policy menu item
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// Terms and conditions menu item
  ///
  /// In en, this message translates to:
  /// **'Terms and Conditions'**
  String get termsAndConditions;

  /// Language menu item
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// Logout menu item
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// Logout confirmation message
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to logout?'**
  String get areYouSureYouWantToLogout;

  /// Yes button text
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// No button text
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// Language selection dialog title
  ///
  /// In en, this message translates to:
  /// **'Select Language'**
  String get selectLanguage;

  /// English language name
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// Hindi language name
  ///
  /// In en, this message translates to:
  /// **'Hindi'**
  String get hindi;

  /// Tamil language name
  ///
  /// In en, this message translates to:
  /// **'Tamil'**
  String get tamil;

  /// Spanish language name
  ///
  /// In en, this message translates to:
  /// **'Spanish'**
  String get spanish;

  /// French language name
  ///
  /// In en, this message translates to:
  /// **'French'**
  String get french;

  /// German language name
  ///
  /// In en, this message translates to:
  /// **'German'**
  String get german;

  /// Chinese language name
  ///
  /// In en, this message translates to:
  /// **'Chinese'**
  String get chinese;

  /// Japanese language name
  ///
  /// In en, this message translates to:
  /// **'Japanese'**
  String get japanese;

  /// Arabic language name
  ///
  /// In en, this message translates to:
  /// **'Arabic'**
  String get arabic;

  /// Portuguese language name
  ///
  /// In en, this message translates to:
  /// **'Portuguese'**
  String get portuguese;

  /// Russian language name
  ///
  /// In en, this message translates to:
  /// **'Russian'**
  String get russian;

  /// Generic loading message
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// Generic error message
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get somethingWentWrong;

  /// Try again button text
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get tryAgain;

  /// Message when no news is found for a specific date
  ///
  /// In en, this message translates to:
  /// **'No news found for this date'**
  String get noNewsForDate;

  /// Success message when remote config is refreshed
  ///
  /// In en, this message translates to:
  /// **'Remote Config refreshed successfully!'**
  String get remoteConfigRefreshed;

  /// Error message when remote config refresh fails
  ///
  /// In en, this message translates to:
  /// **'Failed to refresh: {error}'**
  String failedToRefresh(String error);

  /// Welcome screen title text
  ///
  /// In en, this message translates to:
  /// **'Welcome'**
  String get welcomeTitleText;

  /// Welcome screen description text
  ///
  /// In en, this message translates to:
  /// **'Get ready to explore the world of news!'**
  String get welcomeDescText;

  /// Category selection screen title
  ///
  /// In en, this message translates to:
  /// **'Select Your Interests'**
  String get selectCategoryTitle;

  /// Category selection screen description
  ///
  /// In en, this message translates to:
  /// **'Choose the categories you want to follow'**
  String get selectCategoryDesc;

  /// Bottom navigation menu label
  ///
  /// In en, this message translates to:
  /// **'Menu'**
  String get menu;

  /// Bottom navigation today label
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// Bottom navigation for later label
  ///
  /// In en, this message translates to:
  /// **'For Later'**
  String get forLater;

  /// Notification inbox menu item
  ///
  /// In en, this message translates to:
  /// **'Notification Inbox'**
  String get notificationInbox;

  /// Bookmark menu item
  ///
  /// In en, this message translates to:
  /// **'Bookmark'**
  String get bookmark;

  /// Terms of use menu item
  ///
  /// In en, this message translates to:
  /// **'Terms of Use'**
  String get termsOfUse;

  /// News categories menu item
  ///
  /// In en, this message translates to:
  /// **'News Categories'**
  String get newsCategories;

  /// Listen button text
  ///
  /// In en, this message translates to:
  /// **'Listen'**
  String get listen;

  /// User name section title
  ///
  /// In en, this message translates to:
  /// **'User name'**
  String get userName;

  /// First name input label
  ///
  /// In en, this message translates to:
  /// **'Enter Your First Name *'**
  String get enterYourFirstName;

  /// Second name input label
  ///
  /// In en, this message translates to:
  /// **'Enter Your Second Name'**
  String get enterYourSecondName;

  /// First name validation error
  ///
  /// In en, this message translates to:
  /// **'First name is required'**
  String get firstNameRequired;

  /// Email section title
  ///
  /// In en, this message translates to:
  /// **'Email-ID'**
  String get emailId;

  /// Email input label
  ///
  /// In en, this message translates to:
  /// **'Enter Your Email ID'**
  String get enterYourEmailId;

  /// Email validation error
  ///
  /// In en, this message translates to:
  /// **'Email is required'**
  String get emailRequired;

  /// Email format validation error
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email'**
  String get enterValidEmail;

  /// Personal details section title
  ///
  /// In en, this message translates to:
  /// **'Personal details'**
  String get personalDetails;

  /// Mobile number input label
  ///
  /// In en, this message translates to:
  /// **'Enter mobile number'**
  String get enterMobileNumber;

  /// Mobile number validation error
  ///
  /// In en, this message translates to:
  /// **'Mobile number is required'**
  String get mobileNumberRequired;

  /// Mobile number format validation error
  ///
  /// In en, this message translates to:
  /// **'Enter a valid 10-digit mobile number'**
  String get enterValidMobileNumber;

  /// City dropdown hint
  ///
  /// In en, this message translates to:
  /// **'Select City'**
  String get selectCity;

  /// City selection validation error
  ///
  /// In en, this message translates to:
  /// **'Please select a city'**
  String get pleaseSelectCity;

  /// Pincode input label
  ///
  /// In en, this message translates to:
  /// **'Enter Pincode'**
  String get enterPincode;

  /// Pincode validation error
  ///
  /// In en, this message translates to:
  /// **'Pincode is required'**
  String get pincodeRequired;

  /// Pincode format validation error
  ///
  /// In en, this message translates to:
  /// **'Enter a valid 6-digit pincode'**
  String get enterValidPincode;

  /// Country dropdown hint
  ///
  /// In en, this message translates to:
  /// **'Select Country'**
  String get selectCountry;

  /// Country selection validation error
  ///
  /// In en, this message translates to:
  /// **'Please select a country'**
  String get pleaseSelectCountry;

  /// Social account section title
  ///
  /// In en, this message translates to:
  /// **'Social account'**
  String get socialAccount;

  /// Google login button text
  ///
  /// In en, this message translates to:
  /// **'Login with Google'**
  String get loginWithGoogle;

  /// Connected status text
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get connected;

  /// Appearance settings title
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// Text size settings title
  ///
  /// In en, this message translates to:
  /// **'Text size'**
  String get textSize;

  /// Save button text
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// Light theme mode option
  ///
  /// In en, this message translates to:
  /// **'Light mode'**
  String get lightMode;

  /// Dark theme mode option
  ///
  /// In en, this message translates to:
  /// **'Dark mode'**
  String get darkMode;

  /// System default theme mode option
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get systemDefault;

  /// Unknown source fallback text
  ///
  /// In en, this message translates to:
  /// **'Unknown Source'**
  String get unknownSource;

  /// Version label
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get version;

  /// About dialog description
  ///
  /// In en, this message translates to:
  /// **'Your personalized news application'**
  String get yourPersonalizedNewsApplication;

  /// Close button text
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// Breaking news section title
  ///
  /// In en, this message translates to:
  /// **'Breaking News'**
  String get breakingNews;

  /// View all link text
  ///
  /// In en, this message translates to:
  /// **'View All'**
  String get viewAll;

  /// Flash news section title
  ///
  /// In en, this message translates to:
  /// **'Flash News'**
  String get flashNews;

  /// Live cricket score section title
  ///
  /// In en, this message translates to:
  /// **'Live Cricket Score'**
  String get liveCricketScore;

  /// Yesterday date label
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterday;

  /// Hot news label
  ///
  /// In en, this message translates to:
  /// **'Hot News'**
  String get hotNews;

  /// News reading settings menu item
  ///
  /// In en, this message translates to:
  /// **'News Reading Settings'**
  String get newsReadingSettings;

  /// Play only article title option
  ///
  /// In en, this message translates to:
  /// **'Play Title Only'**
  String get playTitleOnly;

  /// Play only article description option
  ///
  /// In en, this message translates to:
  /// **'Play Description Only'**
  String get playDescriptionOnly;

  /// Play full news (title + description) option
  ///
  /// In en, this message translates to:
  /// **'Play Full News'**
  String get playFullNews;

  /// News reading mode selection title
  ///
  /// In en, this message translates to:
  /// **'Select News Reading Mode'**
  String get selectNewsReadingMode;

  /// Success message when settings are saved
  ///
  /// In en, this message translates to:
  /// **'Settings saved'**
  String get settingsSaved;

  /// No description provided for @backgroundMusic.
  ///
  /// In en, this message translates to:
  /// **'Background Music'**
  String get backgroundMusic;

  /// No description provided for @backgroundMusicSettings.
  ///
  /// In en, this message translates to:
  /// **'Background Music'**
  String get backgroundMusicSettings;

  /// No description provided for @backgroundMusicSettingsDescription.
  ///
  /// In en, this message translates to:
  /// **'Play background music while listening to news. You can turn it off or adjust the volume below.'**
  String get backgroundMusicSettingsDescription;

  /// No description provided for @enableBackgroundMusic.
  ///
  /// In en, this message translates to:
  /// **'Enable background music'**
  String get enableBackgroundMusic;

  /// No description provided for @backgroundMusicVolume.
  ///
  /// In en, this message translates to:
  /// **'Background music volume'**
  String get backgroundMusicVolume;

  /// No description provided for @backgroundMusicEnabled.
  ///
  /// In en, this message translates to:
  /// **'Background music enabled'**
  String get backgroundMusicEnabled;

  /// No description provided for @backgroundMusicDisabled.
  ///
  /// In en, this message translates to:
  /// **'Background music disabled'**
  String get backgroundMusicDisabled;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'es', 'fr', 'hi', 'ta'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en': return AppLocalizationsEn();
    case 'es': return AppLocalizationsEs();
    case 'fr': return AppLocalizationsFr();
    case 'hi': return AppLocalizationsHi();
    case 'ta': return AppLocalizationsTa();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
