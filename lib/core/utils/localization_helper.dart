import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../../l10n/app_localizations.dart';

/// Helper class for easy access to localized strings
/// This provides a convenient way to access AppLocalizations throughout the app
class LocalizationHelper {
  /// Get the current AppLocalizations instance from context
  /// Returns null if localization is not available (fallback to English strings)
  static AppLocalizations? of(BuildContext context) {
    return AppLocalizations.of(context);
  }

  /// Get localized string with fallback to English
  static String _getString(
    BuildContext context,
    String Function(AppLocalizations) getter,
    String fallback,
  ) {
    final l10n = of(context);
    if (l10n != null) {
      try {
        return getter(l10n);
      } catch (e) {
        debugPrint('⚠️ Localization error: $e, using fallback: $fallback');
        return fallback;
      }
    }
    return fallback;
  }

  /// Get localized string for app name
  static String appName(BuildContext context) {
    return _getString(context, (l10n) => l10n.appName, 'NewsOn');
  }

  /// Get localized string for welcome text
  static String welcomeTo(BuildContext context) {
    return _getString(context, (l10n) => l10n.welcomeTo, 'WELCOME TO');
  }

  /// Get localized string for swipe to get started
  static String swipeToGetStarted(BuildContext context) {
    return _getString(
      context,
      (l10n) => l10n.swipeToGetStarted,
      'Swipe To Get Started',
    );
  }

  /// Get localized string for sign in
  static String signIn(BuildContext context) {
    return _getString(context, (l10n) => l10n.signIn, 'Sign In');
  }

  /// Get localized string for sign in description
  static String signInToYourAccount(BuildContext context) {
    return _getString(
      context,
      (l10n) => l10n.signInToYourAccount,
      'Sign in to your account',
    );
  }

  /// Get localized string for connecting
  static String connecting(BuildContext context) {
    return _getString(context, (l10n) => l10n.connecting, 'Connecting...');
  }

  /// Get localized string for connecting to Google
  static String connectingToGoogle(BuildContext context) {
    return _getString(
      context,
      (l10n) => l10n.connectingToGoogle,
      'Connecting to Google...',
    );
  }

  /// Get localized string for welcome
  static String welcome(BuildContext context) {
    return _getString(context, (l10n) => l10n.welcome, 'Welcome!');
  }

  /// Get localized string for sign in cancelled
  static String signInCancelled(BuildContext context) {
    return _getString(
      context,
      (l10n) => l10n.signInCancelled,
      'Sign-in cancelled',
    );
  }

  /// Get localized string for sign in failed
  static String signInFailed(BuildContext context, String error) {
    final l10n = of(context);
    if (l10n != null) {
      try {
        return l10n.signInFailed(error);
      } catch (e) {
        return 'Sign-in failed: $error';
      }
    }
    return 'Sign-in failed: $error';
  }

  /// Get localized string for skip
  static String skip(BuildContext context) {
    return _getString(context, (l10n) => l10n.skip, 'Skip');
  }

  /// Get localized string for continue
  static String continueText(BuildContext context) {
    return _getString(context, (l10n) => l10n.continueText, 'Continue');
  }

  /// Get localized string for enter your name
  static String enterYourName(BuildContext context) {
    return _getString(context, (l10n) => l10n.enterYourName, 'Enter your name');
  }

  /// Get localized string for select categories
  static String selectCategories(BuildContext context) {
    return _getString(
      context,
      (l10n) => l10n.selectCategories,
      'Select Categories',
    );
  }

  /// Get localized string for select at least one category
  static String selectAtLeastOneCategory(BuildContext context) {
    return _getString(
      context,
      (l10n) => l10n.selectAtLeastOneCategory,
      'Please select at least one category',
    );
  }

  /// Get localized string for categories
  static String categories(BuildContext context) {
    return _getString(context, (l10n) => l10n.categories, 'Categories');
  }

  /// Get localized string for bookmarks
  static String bookmarks(BuildContext context) {
    return _getString(context, (l10n) => l10n.bookmarks, 'Bookmarks');
  }

  /// Get localized string for search
  static String search(BuildContext context) {
    return _getString(context, (l10n) => l10n.search, 'Search');
  }

  /// Get localized string for headlines
  static String headlines(BuildContext context) {
    return _getString(context, (l10n) => l10n.headlines, 'Headlines');
  }

  /// Get localized string for news feed
  static String newsFeed(BuildContext context) {
    return _getString(context, (l10n) => l10n.newsFeed, 'News Feed');
  }

  /// Get localized string for retry
  static String retry(BuildContext context) {
    return _getString(context, (l10n) => l10n.retry, 'Retry');
  }

  /// Get localized string for no news available
  static String noNewsAvailable(BuildContext context) {
    return _getString(
      context,
      (l10n) => l10n.noNewsAvailable,
      'No news available',
    );
  }

  /// Get localized string for no results found
  static String noResultsFound(BuildContext context) {
    return _getString(
      context,
      (l10n) => l10n.noResultsFound,
      'No results found',
    );
  }

  /// Get localized string for clear all bookmarks
  static String clearAllBookmarks(BuildContext context) {
    return _getString(
      context,
      (l10n) => l10n.clearAllBookmarks,
      'Clear all bookmarks?',
    );
  }

  /// Get localized string for cancel
  static String cancel(BuildContext context) {
    return _getString(context, (l10n) => l10n.cancel, 'Cancel');
  }

  /// Get localized string for clear
  static String clear(BuildContext context) {
    return _getString(context, (l10n) => l10n.clear, 'Clear');
  }

  /// Get localized string for all bookmarks cleared
  static String allBookmarksCleared(BuildContext context) {
    return _getString(
      context,
      (l10n) => l10n.allBookmarksCleared,
      'All bookmarks cleared',
    );
  }

  /// Get localized string for added to bookmarks
  static String addedToBookmarks(BuildContext context) {
    return _getString(
      context,
      (l10n) => l10n.addedToBookmarks,
      'Added to bookmarks',
    );
  }

  /// Get localized string for removed from bookmarks
  static String removedFromBookmarks(BuildContext context) {
    return _getString(
      context,
      (l10n) => l10n.removedFromBookmarks,
      'Removed from bookmarks',
    );
  }

  /// Get localized string for no internet connection
  static String noInternetConnection(BuildContext context) {
    return _getString(
      context,
      (l10n) => l10n.noInternetConnection,
      'No internet connection. Please check your network.',
    );
  }

  /// Get localized string for server error
  static String serverError(BuildContext context) {
    return _getString(
      context,
      (l10n) => l10n.serverError,
      'Server error. Please try again later.',
    );
  }

  /// Get localized string for unknown error
  static String unknownError(BuildContext context) {
    return _getString(
      context,
      (l10n) => l10n.unknownError,
      'An unknown error occurred.',
    );
  }

  /// Get localized string for no data available
  static String noDataAvailable(BuildContext context) {
    return _getString(
      context,
      (l10n) => l10n.noDataAvailable,
      'No data available.',
    );
  }

  /// Get localized string for error
  static String error(BuildContext context, String error) {
    final l10n = of(context);
    if (l10n != null) {
      try {
        return l10n.error(error);
      } catch (e) {
        return 'Error: $error';
      }
    }
    return 'Error: $error';
  }

  /// Get localized string for text size saved
  static String textSizeSaved(BuildContext context) {
    return _getString(context, (l10n) => l10n.textSizeSaved, 'Text size saved');
  }

  /// Get localized string for form submitted successfully
  static String formSubmittedSuccessfully(BuildContext context) {
    return _getString(
      context,
      (l10n) => l10n.formSubmittedSuccessfully,
      'Form submitted successfully!',
    );
  }

  /// Get localized string for please fix errors before saving
  static String pleaseFixErrorsBeforeSaving(BuildContext context) {
    return _getString(
      context,
      (l10n) => l10n.pleaseFixErrorsBeforeSaving,
      'Please fix errors before saving',
    );
  }

  /// Get localized string for account settings
  static String accountSettings(BuildContext context) {
    return _getString(
      context,
      (l10n) => l10n.accountSettings,
      'Account Settings',
    );
  }

  /// Get localized string for appearance settings
  static String appearanceSettings(BuildContext context) {
    return _getString(context, (l10n) => l10n.appearanceSettings, 'Appearance');
  }

  /// Get localized string for application settings
  static String applicationSettings(BuildContext context) {
    return _getString(
      context,
      (l10n) => l10n.applicationSettings,
      'Application Settings',
    );
  }

  /// Get localized string for notifications
  static String notifications(BuildContext context) {
    return _getString(context, (l10n) => l10n.notifications, 'Notifications');
  }

  /// Get localized string for privacy policy
  static String privacyPolicy(BuildContext context) {
    return _getString(context, (l10n) => l10n.privacyPolicy, 'Privacy Policy');
  }

  /// Get localized string for terms and conditions
  static String termsAndConditions(BuildContext context) {
    return _getString(
      context,
      (l10n) => l10n.termsAndConditions,
      'Terms and Conditions',
    );
  }

  /// Get localized string for language
  static String language(BuildContext context) {
    return _getString(context, (l10n) => l10n.language, 'Language');
  }

  /// Get localized string for logout
  static String logout(BuildContext context) {
    return _getString(context, (l10n) => l10n.logout, 'Logout');
  }

  /// Get localized string for logout confirmation message
  static String areYouSureYouWantToLogout(BuildContext context) {
    return _getString(
      context,
      (l10n) => l10n.areYouSureYouWantToLogout,
      'Are you sure you want to logout?',
    );
  }

  /// Get localized string for yes button
  static String yes(BuildContext context) {
    return _getString(context, (l10n) => l10n.yes, 'Yes');
  }

  /// Get localized string for no button
  static String no(BuildContext context) {
    return _getString(context, (l10n) => l10n.no, 'No');
  }

  /// Get localized string for select language
  static String selectLanguage(BuildContext context) {
    return _getString(
      context,
      (l10n) => l10n.selectLanguage,
      'Select Language',
    );
  }

  /// Get localized string for loading
  static String loading(BuildContext context) {
    return _getString(context, (l10n) => l10n.loading, 'Loading...');
  }

  /// Get localized string for something went wrong
  static String somethingWentWrong(BuildContext context) {
    return _getString(
      context,
      (l10n) => l10n.somethingWentWrong,
      'Something went wrong',
    );
  }

  /// Get localized string for try again
  static String tryAgain(BuildContext context) {
    return _getString(context, (l10n) => l10n.tryAgain, 'Try Again');
  }

  /// Get localized string for no news for date
  static String noNewsForDate(BuildContext context) {
    return _getString(
      context,
      (l10n) => l10n.noNewsForDate,
      'No news found for this date',
    );
  }

  /// Get localized string for remote config refreshed
  static String remoteConfigRefreshed(BuildContext context) {
    return _getString(
      context,
      (l10n) => l10n.remoteConfigRefreshed,
      'Remote Config refreshed successfully!',
    );
  }

  /// Get localized string for failed to refresh
  static String failedToRefresh(BuildContext context, String error) {
    final l10n = of(context);
    if (l10n != null) {
      try {
        return l10n.failedToRefresh(error);
      } catch (e) {
        return 'Failed to refresh: $error';
      }
    }
    return 'Failed to refresh: $error';
  }

  /// Get localized string for welcome title text
  static String welcomeTitleText(BuildContext context) {
    return _getString(context, (l10n) => l10n.welcomeTitleText, 'Welcome');
  }

  /// Get localized string for welcome description text
  static String welcomeDescText(BuildContext context) {
    return _getString(
      context,
      (l10n) => l10n.welcomeDescText,
      'Get ready to explore the world of news!',
    );
  }

  /// Get localized string for select category title
  static String selectCategoryTitle(BuildContext context) {
    return _getString(
      context,
      (l10n) => l10n.selectCategoryTitle,
      'Select Your Interests',
    );
  }

  /// Get localized string for select category description
  static String selectCategoryDesc(BuildContext context) {
    return _getString(
      context,
      (l10n) => l10n.selectCategoryDesc,
      'Choose the categories you want to follow',
    );
  }

  /// Get localized string for menu
  static String menu(BuildContext context) {
    return _getString(context, (l10n) => l10n.menu, 'Menu');
  }

  /// Get localized string for today
  static String today(BuildContext context) {
    return _getString(context, (l10n) => l10n.today, 'Today');
  }

  /// Get localized string for for later
  static String forLater(BuildContext context) {
    return _getString(context, (l10n) => l10n.forLater, 'For Later');
  }

  /// Get localized string for notification inbox
  static String notificationInbox(BuildContext context) {
    return _getString(
      context,
      (l10n) => l10n.notificationInbox,
      'Notification Inbox',
    );
  }

  /// Get localized string for bookmark
  static String bookmark(BuildContext context) {
    return _getString(context, (l10n) => l10n.bookmark, 'Bookmark');
  }

  /// Get localized string for terms of use
  static String termsOfUse(BuildContext context) {
    return _getString(context, (l10n) => l10n.termsOfUse, 'Terms of Use');
  }

  /// Get localized string for news categories
  static String newsCategories(BuildContext context) {
    return _getString(
      context,
      (l10n) => l10n.newsCategories,
      'News Categories',
    );
  }

  /// Get localized drawer menu title based on route/index
  static String getDrawerMenuTitle(BuildContext context, int index) {
    switch (index) {
      case 0:
        return accountSettings(context);
      case 1:
        return notificationInbox(context);
      case 2:
        return bookmark(context);
      case 3:
        return applicationSettings(context);
      case 4:
        return termsAndConditions(context);
      case 5:
        return privacyPolicy(context);
      case 6:
        return newsCategories(context);
      default:
        return '';
    }
  }

  /// Get localized string for listen
  static String listen(BuildContext context) {
    return _getString(context, (l10n) => l10n.listen, 'Listen');
  }

  /// Get localized string for user name
  static String userName(BuildContext context) {
    return _getString(context, (l10n) => l10n.userName, 'User name');
  }

  /// Get localized string for enter your first name
  static String enterYourFirstName(BuildContext context) {
    return _getString(
      context,
      (l10n) => l10n.enterYourFirstName,
      'Enter Your First Name *',
    );
  }

  /// Get localized string for enter your second name
  static String enterYourSecondName(BuildContext context) {
    return _getString(
      context,
      (l10n) => l10n.enterYourSecondName,
      'Enter Your Second Name',
    );
  }

  /// Get localized string for first name required
  static String firstNameRequired(BuildContext context) {
    return _getString(
      context,
      (l10n) => l10n.firstNameRequired,
      'First name is required',
    );
  }

  /// Get localized string for email id
  static String emailId(BuildContext context) {
    return _getString(context, (l10n) => l10n.emailId, 'Email-ID');
  }

  /// Get localized string for enter your email id
  static String enterYourEmailId(BuildContext context) {
    return _getString(
      context,
      (l10n) => l10n.enterYourEmailId,
      'Enter Your Email ID',
    );
  }

  /// Get localized string for email required
  static String emailRequired(BuildContext context) {
    return _getString(
      context,
      (l10n) => l10n.emailRequired,
      'Email is required',
    );
  }

  /// Get localized string for enter valid email
  static String enterValidEmail(BuildContext context) {
    return _getString(
      context,
      (l10n) => l10n.enterValidEmail,
      'Enter a valid email',
    );
  }

  /// Get localized string for personal details
  static String personalDetails(BuildContext context) {
    return _getString(
      context,
      (l10n) => l10n.personalDetails,
      'Personal details',
    );
  }

  /// Get localized string for enter mobile number
  static String enterMobileNumber(BuildContext context) {
    return _getString(
      context,
      (l10n) => l10n.enterMobileNumber,
      'Enter mobile number',
    );
  }

  /// Get localized string for mobile number required
  static String mobileNumberRequired(BuildContext context) {
    return _getString(
      context,
      (l10n) => l10n.mobileNumberRequired,
      'Mobile number is required',
    );
  }

  /// Get localized string for enter valid mobile number
  static String enterValidMobileNumber(BuildContext context) {
    return _getString(
      context,
      (l10n) => l10n.enterValidMobileNumber,
      'Enter a valid 10-digit mobile number',
    );
  }

  /// Get localized string for select city
  static String selectCity(BuildContext context) {
    return _getString(context, (l10n) => l10n.selectCity, 'Select City');
  }

  /// Get localized string for please select city
  static String pleaseSelectCity(BuildContext context) {
    return _getString(
      context,
      (l10n) => l10n.pleaseSelectCity,
      'Please select a city',
    );
  }

  /// Get localized string for enter pincode
  static String enterPincode(BuildContext context) {
    return _getString(context, (l10n) => l10n.enterPincode, 'Enter Pincode');
  }

  /// Get localized string for pincode required
  static String pincodeRequired(BuildContext context) {
    return _getString(
      context,
      (l10n) => l10n.pincodeRequired,
      'Pincode is required',
    );
  }

  /// Get localized string for enter valid pincode
  static String enterValidPincode(BuildContext context) {
    return _getString(
      context,
      (l10n) => l10n.enterValidPincode,
      'Enter a valid 6-digit pincode',
    );
  }

  /// Get localized string for select country
  static String selectCountry(BuildContext context) {
    return _getString(context, (l10n) => l10n.selectCountry, 'Select Country');
  }

  /// Get localized string for please select country
  static String pleaseSelectCountry(BuildContext context) {
    return _getString(
      context,
      (l10n) => l10n.pleaseSelectCountry,
      'Please select a country',
    );
  }

  /// Get localized string for social account
  static String socialAccount(BuildContext context) {
    return _getString(context, (l10n) => l10n.socialAccount, 'Social account');
  }

  /// Get localized string for login with google
  static String loginWithGoogle(BuildContext context) {
    return _getString(
      context,
      (l10n) => l10n.loginWithGoogle,
      'Login with Google',
    );
  }

  /// Get localized string for connected
  static String connected(BuildContext context) {
    return _getString(context, (l10n) => l10n.connected, 'Connected');
  }

  /// Get localized string for appearance
  static String appearance(BuildContext context) {
    return _getString(context, (l10n) => l10n.appearance, 'Appearance');
  }

  /// Get localized string for text size
  static String textSize(BuildContext context) {
    return _getString(context, (l10n) => l10n.textSize, 'Text size');
  }

  /// Get localized string for save
  static String save(BuildContext context) {
    return _getString(context, (l10n) => l10n.save, 'Save');
  }

  /// Get localized string for light mode
  static String lightMode(BuildContext context) {
    return _getString(context, (l10n) => l10n.lightMode, 'Light mode');
  }

  /// Get localized string for dark mode
  static String darkMode(BuildContext context) {
    return _getString(context, (l10n) => l10n.darkMode, 'Dark mode');
  }

  /// Get localized string for system default
  static String systemDefault(BuildContext context) {
    return _getString(context, (l10n) => l10n.systemDefault, 'System default');
  }

  /// Get localized string for unknown source
  static String unknownSource(BuildContext context) {
    return _getString(context, (l10n) => l10n.unknownSource, 'Unknown Source');
  }

  /// Get localized string for version
  static String version(BuildContext context) {
    return _getString(context, (l10n) => l10n.version, 'Version');
  }

  /// Get localized string for your personalized news application
  static String yourPersonalizedNewsApplication(BuildContext context) {
    return _getString(
      context,
      (l10n) => l10n.yourPersonalizedNewsApplication,
      'Your personalized news application',
    );
  }

  /// Get localized string for close
  static String close(BuildContext context) {
    return _getString(context, (l10n) => l10n.close, 'Close');
  }

  /// Get localized string for breaking news
  static String breakingNews(BuildContext context) {
    return _getString(context, (l10n) => l10n.breakingNews, 'Breaking News');
  }

  /// Get localized string for view all
  static String viewAll(BuildContext context) {
    return _getString(context, (l10n) => l10n.viewAll, 'View All');
  }

  /// Get localized string for flash news
  static String flashNews(BuildContext context) {
    return _getString(context, (l10n) => l10n.flashNews, 'Flash News');
  }

  /// Get localized string for live cricket score
  static String liveCricketScore(BuildContext context) {
    return _getString(
      context,
      (l10n) => l10n.liveCricketScore,
      'Live Cricket Score',
    );
  }

  /// Get localized string for yesterday
  static String yesterday(BuildContext context) {
    return _getString(context, (l10n) => l10n.yesterday, 'Yesterday');
  }

  /// Get localized string for hot news
  static String hotNews(BuildContext context) {
    return _getString(context, (l10n) => l10n.hotNews, 'Hot News');
  }

  /// Get localized string for news reading settings
  static String newsReadingSettings(BuildContext context) {
    return _getString(
      context,
      (l10n) => l10n.newsReadingSettings,
      'News Reading Settings',
    );
  }

  /// Get localized string for play title only
  static String playTitleOnly(BuildContext context) {
    return _getString(context, (l10n) => l10n.playTitleOnly, 'Play Title Only');
  }

  /// Get localized string for play description only
  static String playDescriptionOnly(BuildContext context) {
    return _getString(
      context,
      (l10n) => l10n.playDescriptionOnly,
      'Play Description Only',
    );
  }

  /// Get localized string for play full news
  static String playFullNews(BuildContext context) {
    return _getString(context, (l10n) => l10n.playFullNews, 'Play Full News');
  }

  /// Get localized string for select news reading mode
  static String selectNewsReadingMode(BuildContext context) {
    return _getString(
      context,
      (l10n) => l10n.selectNewsReadingMode,
      'Select News Reading Mode',
    );
  }

  /// Get localized string for settings saved
  static String settingsSaved(BuildContext context) {
    return _getString(context, (l10n) => l10n.settingsSaved, 'Settings saved');
  }
}
