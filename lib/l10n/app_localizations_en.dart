// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'NewsOn';

  @override
  String get welcomeTo => 'WELCOME TO';

  @override
  String get swipeToGetStarted => 'Swipe To Get Started';

  @override
  String get signIn => 'Sign In';

  @override
  String get signInToYourAccount => 'Sign in to your account';

  @override
  String get connecting => 'Connecting...';

  @override
  String get connectingToGoogle => 'Connecting to Google...';

  @override
  String get welcome => 'Welcome!';

  @override
  String get signInCancelled => 'Sign-in cancelled';

  @override
  String signInFailed(String error) {
    return 'Sign-in failed: $error';
  }

  @override
  String get skip => 'Skip';

  @override
  String get continueText => 'Continue';

  @override
  String get enterYourName => 'Enter your name';

  @override
  String get selectCategories => 'Select Categories';

  @override
  String get selectAtLeastOneCategory => 'Please select at least one category';

  @override
  String get categories => 'Categories';

  @override
  String get bookmarks => 'Bookmarks';

  @override
  String get search => 'Search';

  @override
  String get headlines => 'Headlines';

  @override
  String get newsFeed => 'News Feed';

  @override
  String get retry => 'Retry';

  @override
  String get noNewsAvailable => 'No news available';

  @override
  String get noResultsFound => 'No results found';

  @override
  String get clearAllBookmarks => 'Clear all bookmarks?';

  @override
  String get cancel => 'Cancel';

  @override
  String get clear => 'Clear';

  @override
  String get allBookmarksCleared => 'All bookmarks cleared';

  @override
  String get addedToBookmarks => 'Added to bookmarks';

  @override
  String get removedFromBookmarks => 'Removed from bookmarks';

  @override
  String get noInternetConnection => 'No internet connection. Please check your network.';

  @override
  String get serverError => 'Server error. Please try again later.';

  @override
  String get unknownError => 'An unknown error occurred.';

  @override
  String get noDataAvailable => 'No data available.';

  @override
  String error(String error) {
    return 'Error: $error';
  }

  @override
  String get textSizeSaved => 'Text size saved';

  @override
  String get formSubmittedSuccessfully => 'Form submitted successfully!';

  @override
  String get pleaseFixErrorsBeforeSaving => 'Please fix errors before saving';

  @override
  String get accountSettings => 'Account Settings';

  @override
  String get appearanceSettings => 'Appearance';

  @override
  String get applicationSettings => 'Application Settings';

  @override
  String get notifications => 'Notifications';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get termsAndConditions => 'Terms and Conditions';

  @override
  String get language => 'Language';

  @override
  String get logout => 'Logout';

  @override
  String get selectLanguage => 'Select Language';

  @override
  String get english => 'English';

  @override
  String get hindi => 'Hindi';

  @override
  String get tamil => 'Tamil';

  @override
  String get spanish => 'Spanish';

  @override
  String get french => 'French';

  @override
  String get german => 'German';

  @override
  String get chinese => 'Chinese';

  @override
  String get japanese => 'Japanese';

  @override
  String get arabic => 'Arabic';

  @override
  String get portuguese => 'Portuguese';

  @override
  String get russian => 'Russian';

  @override
  String get loading => 'Loading...';

  @override
  String get somethingWentWrong => 'Something went wrong';

  @override
  String get tryAgain => 'Try Again';

  @override
  String get noNewsForDate => 'No news found for this date';

  @override
  String get remoteConfigRefreshed => 'Remote Config refreshed successfully!';

  @override
  String failedToRefresh(String error) {
    return 'Failed to refresh: $error';
  }

  @override
  String get welcomeTitleText => 'Welcome';

  @override
  String get welcomeDescText => 'Get ready to explore the world of news!';

  @override
  String get selectCategoryTitle => 'Select Your Interests';

  @override
  String get selectCategoryDesc => 'Choose the categories you want to follow';

  @override
  String get menu => 'Menu';

  @override
  String get today => 'Today';

  @override
  String get forLater => 'For Later';

  @override
  String get notificationInbox => 'Notification Inbox';

  @override
  String get bookmark => 'Bookmark';

  @override
  String get termsOfUse => 'Terms of Use';

  @override
  String get newsCategories => 'News Categories';

  @override
  String get listen => 'Listen';

  @override
  String get userName => 'User name';

  @override
  String get enterYourFirstName => 'Enter Your First Name *';

  @override
  String get enterYourSecondName => 'Enter Your Second Name';

  @override
  String get firstNameRequired => 'First name is required';

  @override
  String get emailId => 'Email-ID';

  @override
  String get enterYourEmailId => 'Enter Your Email ID';

  @override
  String get emailRequired => 'Email is required';

  @override
  String get enterValidEmail => 'Enter a valid email';

  @override
  String get personalDetails => 'Personal details';

  @override
  String get enterMobileNumber => 'Enter mobile number';

  @override
  String get mobileNumberRequired => 'Mobile number is required';

  @override
  String get enterValidMobileNumber => 'Enter a valid 10-digit mobile number';

  @override
  String get selectCity => 'Select City';

  @override
  String get pleaseSelectCity => 'Please select a city';

  @override
  String get enterPincode => 'Enter Pincode';

  @override
  String get pincodeRequired => 'Pincode is required';

  @override
  String get enterValidPincode => 'Enter a valid 6-digit pincode';

  @override
  String get selectCountry => 'Select Country';

  @override
  String get pleaseSelectCountry => 'Please select a country';

  @override
  String get socialAccount => 'Social account';

  @override
  String get loginWithGoogle => 'Login with Google';

  @override
  String get connected => 'Connected';

  @override
  String get appearance => 'Appearance';

  @override
  String get textSize => 'Text size';

  @override
  String get save => 'Save';

  @override
  String get lightMode => 'Light mode';

  @override
  String get darkMode => 'Dark mode';

  @override
  String get systemDefault => 'System default';

  @override
  String get unknownSource => 'Unknown Source';

  @override
  String get version => 'Version';

  @override
  String get yourPersonalizedNewsApplication => 'Your personalized news application';

  @override
  String get close => 'Close';

  @override
  String get breakingNews => 'Breaking News';

  @override
  String get viewAll => 'View All';

  @override
  String get flashNews => 'Flash News';

  @override
  String get liveCricketScore => 'Live Cricket Score';

  @override
  String get yesterday => 'Yesterday';

  @override
  String get hotNews => 'Hot News';
}
