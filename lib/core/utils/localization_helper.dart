import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../../l10n/app_localizations.dart';
import '../../data/services/dynamic_localization_service.dart';

/// Helper class for easy access to localized strings
/// This provides a convenient way to access AppLocalizations throughout the app
/// Now supports dynamic translations from Firebase for languages without ARB files
class LocalizationHelper {
  /// Get the current AppLocalizations instance from context
  /// Returns null if localization is not available (fallback to English strings)
  static AppLocalizations? of(BuildContext context) {
    return AppLocalizations.of(context);
  }

  /// Get localized string with fallback to English
  /// Priority: Dynamic translations > ARB translations > Fallback
  static String _getString(
    BuildContext context,
    String Function(AppLocalizations) getter,
    String fallback, {
    String? key,
  }) {
    // First, try dynamic translations (for languages like Malayalam)
    if (key != null) {
      final dynamicService = DynamicLocalizationService();
      if (dynamicService.isInitialized) {
        final dynamicTranslation = dynamicService.translate(key);
        if (dynamicTranslation != key) {
          // Translation found in dynamic service
          return dynamicTranslation;
        }
      }
    }

    // Fall back to ARB-based translations
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

  /// Get translation directly from dynamic service
  static String _getDynamic(String key, String fallback) {
    final dynamicService = DynamicLocalizationService();
    if (dynamicService.isInitialized) {
      final translation = dynamicService.translate(key);
      if (translation != key) {
        return translation;
      }
    }
    return fallback;
  }

  /// Get localized string for app name
  static String appName(BuildContext context) {
    return _getString(context, (l10n) => l10n.appName, 'NewsOn',
        key: 'appName');
  }

  /// Get localized string for welcome text
  static String welcomeTo(BuildContext context) {
    return _getString(context, (l10n) => l10n.welcomeTo, 'WELCOME TO',
        key: 'welcomeTo');
  }

  /// Get localized string for swipe to get started
  static String swipeToGetStarted(BuildContext context) {
    return _getString(
      context,
      (l10n) => l10n.swipeToGetStarted,
      'Swipe To Get Started',
      key: 'swipeToGetStarted',
    );
  }

  /// Get localized string for sign in
  static String signIn(BuildContext context) {
    return _getString(context, (l10n) => l10n.signIn, 'Sign In', key: 'signIn');
  }

  /// Get localized string for sign in description
  static String signInToYourAccount(BuildContext context) {
    return _getString(
      context,
      (l10n) => l10n.signInToYourAccount,
      'Sign in to your account',
      key: 'signInToYourAccount',
    );
  }

  /// Get localized string for connecting
  static String connecting(BuildContext context) {
    return _getString(context, (l10n) => l10n.connecting, 'Connecting...',
        key: 'connecting');
  }

  /// Get localized string for connecting to Google
  static String connectingToGoogle(BuildContext context) {
    return _getString(
      context,
      (l10n) => l10n.connectingToGoogle,
      'Connecting to Google...',
      key: 'connectingToGoogle',
    );
  }

  /// Get localized string for welcome
  static String welcome(BuildContext context) {
    return _getString(context, (l10n) => l10n.welcome, 'Welcome!',
        key: 'welcome');
  }

  /// Get localized string for sign in cancelled
  static String signInCancelled(BuildContext context) {
    return _getString(
      context,
      (l10n) => l10n.signInCancelled,
      'Sign-in cancelled',
      key: 'signInCancelled',
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
    return _getString(context, (l10n) => l10n.skip, 'Skip', key: 'skip');
  }

  /// Get localized string for continue
  static String continueText(BuildContext context) {
    return _getString(context, (l10n) => l10n.continueText, 'Continue',
        key: 'continueText');
  }

  /// Get localized string for enter your name
  static String enterYourName(BuildContext context) {
    return _getString(context, (l10n) => l10n.enterYourName, 'Enter your name',
        key: 'enterYourName');
  }

  /// Get localized string for select categories
  static String selectCategories(BuildContext context) {
    return _getString(
      context,
      (l10n) => l10n.selectCategories,
      'Select Categories',
      key: 'selectCategories',
    );
  }

  /// Get localized string for select at least one category
  static String selectAtLeastOneCategory(BuildContext context) {
    return _getString(
      context,
      (l10n) => l10n.selectAtLeastOneCategory,
      'Please select at least one category',
      key: 'selectAtLeastOneCategory',
    );
  }

  /// Get localized string for categories
  static String categories(BuildContext context) {
    return _getString(context, (l10n) => l10n.categories, 'Categories',
        key: 'categories');
  }

  /// Get localized string for bookmarks
  static String bookmarks(BuildContext context) {
    return _getString(context, (l10n) => l10n.bookmarks, 'Bookmarks',
        key: 'bookmarks');
  }

  /// Get localized string for search
  static String search(BuildContext context) {
    return _getString(context, (l10n) => l10n.search, 'Search', key: 'search');
  }

  /// Get localized string for headlines
  static String headlines(BuildContext context) {
    return _getString(context, (l10n) => l10n.headlines, 'Headlines',
        key: 'headlines');
  }

  /// Get localized string for news feed
  static String newsFeed(BuildContext context) {
    return _getString(context, (l10n) => l10n.newsFeed, 'News Feed',
        key: 'newsFeed');
  }

  /// Get localized string for retry
  static String retry(BuildContext context) {
    return _getString(context, (l10n) => l10n.retry, 'Retry', key: 'retry');
  }

  /// Get localized string for no news available
  static String noNewsAvailable(BuildContext context) {
    return _getString(
      context,
      (l10n) => l10n.noNewsAvailable,
      'No news available',
      key: 'noNewsAvailable',
    );
  }

  /// Get localized string for no results found
  static String noResultsFound(BuildContext context) {
    return _getString(
      context,
      (l10n) => l10n.noResultsFound,
      'No results found',
      key: 'noResultsFound',
    );
  }

  /// Get localized string for clear all bookmarks
  static String clearAllBookmarks(BuildContext context) {
    return _getString(
      context,
      (l10n) => l10n.clearAllBookmarks,
      'Clear all bookmarks?',
      key: 'clearAllBookmarks',
    );
  }

  /// Get localized string for cancel
  static String cancel(BuildContext context) {
    return _getString(context, (l10n) => l10n.cancel, 'Cancel', key: 'cancel');
  }

  /// Get localized string for clear
  static String clear(BuildContext context) {
    return _getString(context, (l10n) => l10n.clear, 'Clear', key: 'clear');
  }

  /// Get localized string for all bookmarks cleared
  static String allBookmarksCleared(BuildContext context) {
    return _getString(
      context,
      (l10n) => l10n.allBookmarksCleared,
      'All bookmarks cleared',
      key: 'allBookmarksCleared',
    );
  }

  /// Get localized string for added to bookmarks
  static String addedToBookmarks(BuildContext context) {
    return _getString(
      context,
      (l10n) => l10n.addedToBookmarks,
      'Added to bookmarks',
      key: 'addedToBookmarks',
    );
  }

  /// Get localized string for removed from bookmarks
  static String removedFromBookmarks(BuildContext context) {
    return _getString(
      context,
      (l10n) => l10n.removedFromBookmarks,
      'Removed from bookmarks',
      key: 'removedFromBookmarks',
    );
  }

  /// Get localized string for no internet connection
  static String noInternetConnection(BuildContext context) {
    return _getString(
      context,
      (l10n) => l10n.noInternetConnection,
      'No internet connection. Please check your network.',
      key: 'noInternetConnection',
    );
  }

  /// Get localized string for server error
  static String serverError(BuildContext context) {
    return _getString(
      context,
      (l10n) => l10n.serverError,
      'Server error. Please try again later.',
      key: 'serverError',
    );
  }

  /// Get localized string for unknown error
  static String unknownError(BuildContext context) {
    return _getString(
      context,
      (l10n) => l10n.unknownError,
      'An unknown error occurred.',
      key: 'unknownError',
    );
  }

  /// Get localized string for no data available
  static String noDataAvailable(BuildContext context) {
    return _getString(
      context,
      (l10n) => l10n.noDataAvailable,
      'No data available.',
      key: 'noDataAvailable',
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
    return _getString(context, (l10n) => l10n.textSizeSaved, 'Text size saved',
        key: 'textSizeSaved');
  }

  /// Get localized string for form submitted successfully
  static String formSubmittedSuccessfully(BuildContext context) {
    return _getString(
      context,
      (l10n) => l10n.formSubmittedSuccessfully,
      'Form submitted successfully!',
      key: 'formSubmittedSuccessfully',
    );
  }

  /// Get localized string for please fix errors before saving
  static String pleaseFixErrorsBeforeSaving(BuildContext context) {
    return _getString(
      context,
      (l10n) => l10n.pleaseFixErrorsBeforeSaving,
      'Please fix errors before saving',
      key: 'pleaseFixErrorsBeforeSaving',
    );
  }

  /// Get localized string for account settings
  static String accountSettings(BuildContext context) {
    return _getString(
      context,
      (l10n) => l10n.accountSettings,
      'Account Settings',
      key: 'accountSettings',
    );
  }

  /// Get localized string for appearance settings
  static String appearanceSettings(BuildContext context) {
    return _getString(context, (l10n) => l10n.appearanceSettings, 'Appearance',
        key: 'appearanceSettings');
  }

  /// Get localized string for application settings
  static String applicationSettings(BuildContext context) {
    return _getString(
      context,
      (l10n) => l10n.applicationSettings,
      'Application Settings',
      key: 'applicationSettings',
    );
  }

  /// Get localized string for notifications
  static String notifications(BuildContext context) {
    return _getString(context, (l10n) => l10n.notifications, 'Notifications',
        key: 'notifications');
  }

  /// Get localized string for privacy policy
  static String privacyPolicy(BuildContext context) {
    return _getString(context, (l10n) => l10n.privacyPolicy, 'Privacy Policy',
        key: 'privacyPolicy');
  }

  /// Get localized string for terms and conditions
  static String termsAndConditions(BuildContext context) {
    return _getString(
      context,
      (l10n) => l10n.termsAndConditions,
      'Terms and Conditions',
      key: 'termsAndConditions',
    );
  }

  /// Get localized string for language
  static String language(BuildContext context) {
    return _getString(context, (l10n) => l10n.language, 'Language',
        key: 'language');
  }

  /// Get localized string for logout
  static String logout(BuildContext context) {
    return _getString(context, (l10n) => l10n.logout, 'Logout', key: 'logout');
  }

  /// Get localized string for logout confirmation message
  static String areYouSureYouWantToLogout(BuildContext context) {
    return _getString(
      context,
      (l10n) => l10n.areYouSureYouWantToLogout,
      'Are you sure you want to logout?',
      key: 'areYouSureYouWantToLogout',
    );
  }

  /// Get localized string for yes button
  static String yes(BuildContext context) {
    return _getString(context, (l10n) => l10n.yes, 'Yes', key: 'yes');
  }

  /// Get localized string for no button
  static String no(BuildContext context) {
    return _getString(context, (l10n) => l10n.no, 'No', key: 'no');
  }

  /// Get localized string for select language
  static String selectLanguage(BuildContext context) {
    return _getString(
      context,
      (l10n) => l10n.selectLanguage,
      'Select Language',
      key: 'selectLanguage',
    );
  }

  /// Get localized string for loading
  static String loading(BuildContext context) {
    return _getString(context, (l10n) => l10n.loading, 'Loading...',
        key: 'loading');
  }

  /// Get localized string for something went wrong
  static String somethingWentWrong(BuildContext context) {
    return _getString(
      context,
      (l10n) => l10n.somethingWentWrong,
      'Something went wrong',
      key: 'somethingWentWrong',
    );
  }

  /// Get localized string for try again
  static String tryAgain(BuildContext context) {
    return _getString(context, (l10n) => l10n.tryAgain, 'Try Again',
        key: 'tryAgain');
  }

  /// Get localized string for no news for date
  static String noNewsForDate(BuildContext context) {
    return _getString(
      context,
      (l10n) => l10n.noNewsForDate,
      'No news found for this date',
      key: 'noNewsForDate',
    );
  }

  /// Get localized string for remote config refreshed
  static String remoteConfigRefreshed(BuildContext context) {
    return _getString(
      context,
      (l10n) => l10n.remoteConfigRefreshed,
      'Remote Config refreshed successfully!',
      key: 'remoteConfigRefreshed',
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
    return _getString(context, (l10n) => l10n.welcomeTitleText, 'Welcome',
        key: 'welcomeTitleText');
  }

  /// Get localized string for welcome description text
  static String welcomeDescText(BuildContext context) {
    return _getString(
      context,
      (l10n) => l10n.welcomeDescText,
      'Get ready to explore the world of news!',
      key: 'welcomeDescText',
    );
  }

  /// Get localized string for select category title
  static String selectCategoryTitle(BuildContext context) {
    return _getString(
      context,
      (l10n) => l10n.selectCategoryTitle,
      'Select Your Interests',
      key: 'selectCategoryTitle',
    );
  }

  /// Get localized string for select category description
  static String selectCategoryDesc(BuildContext context) {
    return _getString(
      context,
      (l10n) => l10n.selectCategoryDesc,
      'Choose the categories you want to follow',
      key: 'selectCategoryDesc',
    );
  }

  /// Get localized string for menu
  static String menu(BuildContext context) {
    return _getString(context, (l10n) => l10n.menu, 'Menu', key: 'menu');
  }

  /// Get localized string for today
  static String today(BuildContext context) {
    return _getString(context, (l10n) => l10n.today, 'Today', key: 'today');
  }

  /// Get localized string for for later
  static String forLater(BuildContext context) {
    return _getString(context, (l10n) => l10n.forLater, 'For Later',
        key: 'forLater');
  }

  /// Get localized string for notification inbox
  static String notificationInbox(BuildContext context) {
    return _getString(
      context,
      (l10n) => l10n.notificationInbox,
      'Notification Inbox',
      key: 'notificationInbox',
    );
  }

  /// Get localized string for bookmark
  static String bookmark(BuildContext context) {
    return _getString(context, (l10n) => l10n.bookmark, 'Bookmark',
        key: 'bookmark');
  }

  /// Get localized string for terms of use
  static String termsOfUse(BuildContext context) {
    return _getString(context, (l10n) => l10n.termsOfUse, 'Terms of Use',
        key: 'termsOfUse');
  }

  /// Get localized string for news categories
  static String newsCategories(BuildContext context) {
    return _getString(
      context,
      (l10n) => l10n.newsCategories,
      'News Categories',
      key: 'newsCategories',
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
    return _getString(context, (l10n) => l10n.listen, 'Listen', key: 'listen');
  }

  /// Get localized string for user name
  static String userName(BuildContext context) {
    return _getString(context, (l10n) => l10n.userName, 'User name',
        key: 'userName');
  }

  /// Get localized string for enter your first name
  static String enterYourFirstName(BuildContext context) {
    return _getString(
      context,
      (l10n) => l10n.enterYourFirstName,
      'Enter Your First Name *',
      key: 'enterYourFirstName',
    );
  }

  /// Get localized string for enter your second name
  static String enterYourSecondName(BuildContext context) {
    return _getString(
      context,
      (l10n) => l10n.enterYourSecondName,
      'Enter Your Second Name',
      key: 'enterYourSecondName',
    );
  }

  /// Get localized string for first name required
  static String firstNameRequired(BuildContext context) {
    return _getString(
      context,
      (l10n) => l10n.firstNameRequired,
      'First name is required',
      key: 'firstNameRequired',
    );
  }

  /// Get localized string for email id
  static String emailId(BuildContext context) {
    return _getString(context, (l10n) => l10n.emailId, 'Email-ID',
        key: 'emailId');
  }

  /// Get localized string for enter your email id
  static String enterYourEmailId(BuildContext context) {
    return _getString(
      context,
      (l10n) => l10n.enterYourEmailId,
      'Enter Your Email ID',
      key: 'enterYourEmailId',
    );
  }

  /// Get localized string for email required
  static String emailRequired(BuildContext context) {
    return _getString(
      context,
      (l10n) => l10n.emailRequired,
      'Email is required',
      key: 'emailRequired',
    );
  }

  /// Get localized string for enter valid email
  static String enterValidEmail(BuildContext context) {
    return _getString(
      context,
      (l10n) => l10n.enterValidEmail,
      'Enter a valid email',
      key: 'enterValidEmail',
    );
  }

  /// Get localized string for personal details
  static String personalDetails(BuildContext context) {
    return _getString(
      context,
      (l10n) => l10n.personalDetails,
      'Personal details',
      key: 'personalDetails',
    );
  }

  /// Get localized string for enter mobile number
  static String enterMobileNumber(BuildContext context) {
    return _getString(
      context,
      (l10n) => l10n.enterMobileNumber,
      'Enter mobile number',
      key: 'enterMobileNumber',
    );
  }

  /// Get localized string for mobile number required
  static String mobileNumberRequired(BuildContext context) {
    return _getString(
      context,
      (l10n) => l10n.mobileNumberRequired,
      'Mobile number is required',
      key: 'mobileNumberRequired',
    );
  }

  /// Get localized string for enter valid mobile number
  static String enterValidMobileNumber(BuildContext context) {
    return _getString(
      context,
      (l10n) => l10n.enterValidMobileNumber,
      'Enter a valid 10-digit mobile number',
      key: 'enterValidMobileNumber',
    );
  }

  /// Get localized string for select city
  static String selectCity(BuildContext context) {
    return _getString(context, (l10n) => l10n.selectCity, 'Select City',
        key: 'selectCity');
  }

  /// Get localized string for please select city
  static String pleaseSelectCity(BuildContext context) {
    return _getString(
      context,
      (l10n) => l10n.pleaseSelectCity,
      'Please select a city',
      key: 'pleaseSelectCity',
    );
  }

  /// Get localized string for enter pincode
  static String enterPincode(BuildContext context) {
    return _getString(context, (l10n) => l10n.enterPincode, 'Enter Pincode',
        key: 'enterPincode');
  }

  /// Get localized string for pincode required
  static String pincodeRequired(BuildContext context) {
    return _getString(
      context,
      (l10n) => l10n.pincodeRequired,
      'Pincode is required',
      key: 'pincodeRequired',
    );
  }

  /// Get localized string for enter valid pincode
  static String enterValidPincode(BuildContext context) {
    return _getString(
      context,
      (l10n) => l10n.enterValidPincode,
      'Enter a valid 6-digit pincode',
      key: 'enterValidPincode',
    );
  }

  /// Get localized string for select country
  static String selectCountry(BuildContext context) {
    return _getString(context, (l10n) => l10n.selectCountry, 'Select Country',
        key: 'selectCountry');
  }

  /// Get localized string for please select country
  static String pleaseSelectCountry(BuildContext context) {
    return _getString(
      context,
      (l10n) => l10n.pleaseSelectCountry,
      'Please select a country',
      key: 'pleaseSelectCountry',
    );
  }

  /// Get localized string for social account
  static String socialAccount(BuildContext context) {
    return _getString(context, (l10n) => l10n.socialAccount, 'Social account',
        key: 'socialAccount');
  }

  /// Get localized string for login with google
  static String loginWithGoogle(BuildContext context) {
    return _getString(
      context,
      (l10n) => l10n.loginWithGoogle,
      'Login with Google',
      key: 'loginWithGoogle',
    );
  }

  /// Get localized string for connected
  static String connected(BuildContext context) {
    return _getString(context, (l10n) => l10n.connected, 'Connected',
        key: 'connected');
  }

  /// Get localized string for appearance
  static String appearance(BuildContext context) {
    return _getString(context, (l10n) => l10n.appearance, 'Appearance',
        key: 'appearance');
  }

  /// Get localized string for text size
  static String textSize(BuildContext context) {
    return _getString(context, (l10n) => l10n.textSize, 'Text size',
        key: 'textSize');
  }

  /// Get localized string for save
  static String save(BuildContext context) {
    return _getString(context, (l10n) => l10n.save, 'Save', key: 'save');
  }

  /// Get localized string for light mode
  static String lightMode(BuildContext context) {
    return _getString(context, (l10n) => l10n.lightMode, 'Light mode',
        key: 'lightMode');
  }

  /// Get localized string for dark mode
  static String darkMode(BuildContext context) {
    return _getString(context, (l10n) => l10n.darkMode, 'Dark mode',
        key: 'darkMode');
  }

  /// Get localized string for system default
  static String systemDefault(BuildContext context) {
    return _getString(context, (l10n) => l10n.systemDefault, 'System default',
        key: 'systemDefault');
  }

  /// Get localized string for unknown source
  static String unknownSource(BuildContext context) {
    return _getString(context, (l10n) => l10n.unknownSource, 'Unknown Source',
        key: 'unknownSource');
  }

  /// Get localized string for version
  static String version(BuildContext context) {
    return _getString(context, (l10n) => l10n.version, 'Version',
        key: 'version');
  }

  /// Get localized string for your personalized news application
  static String yourPersonalizedNewsApplication(BuildContext context) {
    return _getString(
      context,
      (l10n) => l10n.yourPersonalizedNewsApplication,
      'Your personalized news application',
      key: 'yourPersonalizedNewsApplication',
    );
  }

  /// Get localized string for close
  static String close(BuildContext context) {
    return _getString(context, (l10n) => l10n.close, 'Close', key: 'close');
  }

  /// Get localized string for breaking news
  static String breakingNews(BuildContext context) {
    return _getString(context, (l10n) => l10n.breakingNews, 'Breaking News',
        key: 'breakingNews');
  }

  /// Get localized string for view all
  static String viewAll(BuildContext context) {
    return _getString(context, (l10n) => l10n.viewAll, 'View All',
        key: 'viewAll');
  }

  /// Get localized string for flash news
  static String flashNews(BuildContext context) {
    return _getString(context, (l10n) => l10n.flashNews, 'Flash News',
        key: 'flashNews');
  }

  /// Get localized string for live cricket score
  static String liveCricketScore(BuildContext context) {
    return _getString(
      context,
      (l10n) => l10n.liveCricketScore,
      'Live Cricket Score',
      key: 'liveCricketScore',
    );
  }

  /// Get localized string for yesterday
  static String yesterday(BuildContext context) {
    return _getString(context, (l10n) => l10n.yesterday, 'Yesterday',
        key: 'yesterday');
  }

  /// Get localized string for select date
  static String selectDate(BuildContext context) {
    return _getString(context, (l10n) => 'Select Date', 'Select Date',
        key: 'selectDate');
  }

  /// Get localized string for select (button)
  static String select(BuildContext context) {
    return _getString(context, (l10n) => 'Select', 'Select', key: 'select');
  }

  /// Get localized string for date (field label)
  static String date(BuildContext context) {
    return _getString(context, (l10n) => 'Date', 'Date', key: 'date');
  }

  /// Get localized string for select date hint
  static String selectDateHint(BuildContext context) {
    return _getString(context, (l10n) => 'Month/Day/Year', 'Month/Day/Year',
        key: 'selectDateHint');
  }

  /// Get localized string for date of birth
  static String dateOfBirth(BuildContext context) {
    return _getString(context, (l10n) => 'Date of Birth', 'Date of Birth',
        key: 'dateOfBirth');
  }

  /// Get localized string for hot news
  static String hotNews(BuildContext context) {
    return _getString(context, (l10n) => l10n.hotNews, 'Hot News',
        key: 'hotNews');
  }

  /// Get localized string for news reading settings
  static String newsReadingSettings(BuildContext context) {
    return _getString(
      context,
      (l10n) => l10n.newsReadingSettings,
      'News Reading Settings',
      key: 'newsReadingSettings',
    );
  }

  /// Get localized string for play title only
  static String playTitleOnly(BuildContext context) {
    return _getString(context, (l10n) => l10n.playTitleOnly, 'Play Title Only',
        key: 'playTitleOnly');
  }

  /// Get localized string for play description only
  static String playDescriptionOnly(BuildContext context) {
    return _getString(
      context,
      (l10n) => l10n.playDescriptionOnly,
      'Play Description Only',
      key: 'playDescriptionOnly',
    );
  }

  /// Get localized string for play full news
  static String playFullNews(BuildContext context) {
    return _getString(context, (l10n) => l10n.playFullNews, 'Play Full News',
        key: 'playFullNews');
  }

  /// Get localized string for select news reading mode
  static String selectNewsReadingMode(BuildContext context) {
    return _getString(
      context,
      (l10n) => l10n.selectNewsReadingMode,
      'Select News Reading Mode',
      key: 'selectNewsReadingMode',
    );
  }

  /// Get localized string for settings saved
  static String settingsSaved(BuildContext context) {
    return _getString(context, (l10n) => l10n.settingsSaved, 'Settings saved',
        key: 'settingsSaved');
  }
}
