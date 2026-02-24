// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hindi (`hi`).
class AppLocalizationsHi extends AppLocalizations {
  AppLocalizationsHi([String locale = 'hi']) : super(locale);

  @override
  String get appName => 'NewsOn';

  @override
  String get welcomeTo => 'स्वागत है';

  @override
  String get swipeToGetStarted => 'शुरू करने के लिए स्वाइप करें';

  @override
  String get signIn => 'साइन इन करें';

  @override
  String get signInToYourAccount => 'अपने खाते में साइन इन करें';

  @override
  String get connecting => 'कनेक्ट हो रहा है...';

  @override
  String get connectingToGoogle => 'Google से कनेक्ट हो रहा है...';

  @override
  String get welcome => 'स्वागत है!';

  @override
  String get signInCancelled => 'साइन-इन रद्द कर दिया गया';

  @override
  String signInFailed(String error) {
    return 'साइन-इन विफल: $error';
  }

  @override
  String get skip => 'छोड़ें';

  @override
  String get continueText => 'जारी रखें';

  @override
  String get enterYourName => 'अपना नाम दर्ज करें';

  @override
  String get selectCategories => 'श्रेणियाँ चुनें';

  @override
  String get selectAtLeastOneCategory => 'कृपया कम से कम एक श्रेणी चुनें';

  @override
  String get categories => 'श्रेणियाँ';

  @override
  String get bookmarks => 'बुकमार्क';

  @override
  String get search => 'खोजें';

  @override
  String get headlines => 'सुर्खियां';

  @override
  String get newsFeed => 'समाचार फ़ीड';

  @override
  String get retry => 'पुनः प्रयास करें';

  @override
  String get noNewsAvailable => 'कोई समाचार उपलब्ध नहीं';

  @override
  String get noResultsFound => 'कोई परिणाम नहीं मिला';

  @override
  String get clearAllBookmarks => 'सभी बुकमार्क साफ़ करें?';

  @override
  String get cancel => 'रद्द करें';

  @override
  String get clear => 'साफ़ करें';

  @override
  String get allBookmarksCleared => 'सभी बुकमार्क साफ़ कर दिए गए';

  @override
  String get addedToBookmarks => 'बुकमार्क में जोड़ा गया';

  @override
  String get removedFromBookmarks => 'बुकमार्क से हटा दिया गया';

  @override
  String get noInternetConnection => 'कोई इंटरनेट कनेक्शन नहीं। कृपया अपना नेटवर्क जांचें।';

  @override
  String get serverError => 'सर्वर त्रुटि। कृपया बाद में पुनः प्रयास करें।';

  @override
  String get unknownError => 'एक अज्ञात त्रुटि हुई।';

  @override
  String get noDataAvailable => 'कोई डेटा उपलब्ध नहीं।';

  @override
  String error(String error) {
    return 'त्रुटि: $error';
  }

  @override
  String get textSizeSaved => 'टेक्स्ट आकार सहेजा गया';

  @override
  String get formSubmittedSuccessfully => 'फॉर्म सफलतापूर्वक सबमिट किया गया!';

  @override
  String get pleaseFixErrorsBeforeSaving => 'सहेजने से पहले कृपया त्रुटियों को ठीक करें';

  @override
  String get accountSettings => 'खाता सेटिंग्स';

  @override
  String get appearanceSettings => 'दिखावट';

  @override
  String get applicationSettings => 'एप्लिकेशन सेटिंग्स';

  @override
  String get notifications => 'सूचनाएं';

  @override
  String get privacyPolicy => 'गोपनीयता नीति';

  @override
  String get termsAndConditions => 'नियम और शर्तें';

  @override
  String get language => 'भाषा';

  @override
  String get logout => 'लॉगआउट';

  @override
  String get areYouSureYouWantToLogout => 'क्या आप वाकई लॉगआउट करना चाहते हैं?';

  @override
  String get yes => 'हाँ';

  @override
  String get no => 'नहीं';

  @override
  String get selectLanguage => 'भाषा चुनें';

  @override
  String get english => 'अंग्रेज़ी';

  @override
  String get hindi => 'हिंदी';

  @override
  String get tamil => 'तमिल';

  @override
  String get spanish => 'स्पेनिश';

  @override
  String get french => 'फ्रेंच';

  @override
  String get german => 'जर्मन';

  @override
  String get chinese => 'चीनी';

  @override
  String get japanese => 'जापानी';

  @override
  String get arabic => 'अरबी';

  @override
  String get portuguese => 'पुर्तगाली';

  @override
  String get russian => 'रूसी';

  @override
  String get loading => 'लोड हो रहा है...';

  @override
  String get somethingWentWrong => 'कुछ गलत हो गया';

  @override
  String get tryAgain => 'पुनः प्रयास करें';

  @override
  String get noNewsForDate => 'इस तारीख के लिए कोई समाचार नहीं मिला';

  @override
  String get remoteConfigRefreshed => 'रिमोट कॉन्फ़िग सफलतापूर्वक रीफ्रेश किया गया!';

  @override
  String failedToRefresh(String error) {
    return 'रीफ्रेश करने में विफल: $error';
  }

  @override
  String get welcomeTitleText => 'स्वागत है';

  @override
  String get welcomeDescText => 'समाचार की दुनिया का अन्वेषण करने के लिए तैयार हो जाएं!';

  @override
  String get selectCategoryTitle => 'अपनी रुचियाँ चुनें';

  @override
  String get selectCategoryDesc => 'वे श्रेणियाँ चुनें जिन्हें आप फॉलो करना चाहते हैं';

  @override
  String get menu => 'मेनू';

  @override
  String get today => 'आज';

  @override
  String get forLater => 'बाद के लिए';

  @override
  String get notificationInbox => 'अधिसूचना इनबॉक्स';

  @override
  String get bookmark => 'बुकमार्क';

  @override
  String get termsOfUse => 'उपयोग की शर्तें';

  @override
  String get newsCategories => 'समाचार श्रेणियां';

  @override
  String get listen => 'सुनें';

  @override
  String get userName => 'उपयोगकर्ता नाम';

  @override
  String get enterYourFirstName => 'अपना पहला नाम दर्ज करें *';

  @override
  String get enterYourSecondName => 'अपना दूसरा नाम दर्ज करें';

  @override
  String get firstNameRequired => 'पहला नाम आवश्यक है';

  @override
  String get emailId => 'ईमेल-आईडी';

  @override
  String get enterYourEmailId => 'अपना ईमेल आईडी दर्ज करें';

  @override
  String get emailRequired => 'ईमेल आवश्यक है';

  @override
  String get enterValidEmail => 'एक वैध ईमेल दर्ज करें';

  @override
  String get personalDetails => 'व्यक्तिगत विवरण';

  @override
  String get enterMobileNumber => 'मोबाइल नंबर दर्ज करें';

  @override
  String get mobileNumberRequired => 'मोबाइल नंबर आवश्यक है';

  @override
  String get enterValidMobileNumber => 'एक वैध 10-अंकीय मोबाइल नंबर दर्ज करें';

  @override
  String get selectCity => 'शहर चुनें';

  @override
  String get pleaseSelectCity => 'कृपया एक शहर चुनें';

  @override
  String get enterPincode => 'पिनकोड दर्ज करें';

  @override
  String get pincodeRequired => 'पिनकोड आवश्यक है';

  @override
  String get enterValidPincode => 'एक वैध 6-अंकीय पिनकोड दर्ज करें';

  @override
  String get selectCountry => 'देश चुनें';

  @override
  String get pleaseSelectCountry => 'कृपया एक देश चुनें';

  @override
  String get socialAccount => 'सामाजिक खाता';

  @override
  String get loginWithGoogle => 'Google के साथ लॉगिन करें';

  @override
  String get connected => 'जुड़ा हुआ';

  @override
  String get appearance => 'दिखावट';

  @override
  String get textSize => 'पाठ आकार';

  @override
  String get save => 'सहेजें';

  @override
  String get lightMode => 'लाइट मोड';

  @override
  String get darkMode => 'डार्क मोड';

  @override
  String get systemDefault => 'सिस्टम डिफ़ॉल्ट';

  @override
  String get unknownSource => 'अज्ञात स्रोत';

  @override
  String get version => 'संस्करण';

  @override
  String get yourPersonalizedNewsApplication => 'आपका व्यक्तिगत समाचार अनुप्रयोग';

  @override
  String get close => 'बंद करें';

  @override
  String get breakingNews => 'ताज़ा खबर';

  @override
  String get viewAll => 'सभी देखें';

  @override
  String get flashNews => 'फ्लैश न्यूज़';

  @override
  String get liveCricketScore => 'लाइव क्रिकेट स्कोर';

  @override
  String get yesterday => 'कल';

  @override
  String get hotNews => 'हॉट न्यूज़';

  @override
  String get newsReadingSettings => 'समाचार पढ़ने की सेटिंग्स';

  @override
  String get playTitleOnly => 'केवल शीर्षक चलाएं';

  @override
  String get playDescriptionOnly => 'केवल विवरण चलाएं';

  @override
  String get playFullNews => 'पूरी खबर चलाएं';

  @override
  String get selectNewsReadingMode => 'समाचार पढ़ने का मोड चुनें';

  @override
  String get settingsSaved => 'सेटिंग्स सहेजी गईं';

  @override
  String get backgroundMusic => 'पृष्ठभूमि संगीत';

  @override
  String get backgroundMusicSettings => 'पृष्ठभूमि संगीत';

  @override
  String get backgroundMusicSettingsDescription => 'खबर सुनते समय पृष्ठभूमि संगीत बजाएं। नीचे बंद या वॉल्यूम समायोजित कर सकते हैं।';

  @override
  String get enableBackgroundMusic => 'पृष्ठभूमि संगीत चालू करें';

  @override
  String get backgroundMusicVolume => 'पृष्ठभूमि संगीत वॉल्यूम';

  @override
  String get backgroundMusicEnabled => 'पृष्ठभूमि संगीत चालू';

  @override
  String get backgroundMusicDisabled => 'पृष्ठभूमि संगीत बंद';
}
