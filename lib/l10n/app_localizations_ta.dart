// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Tamil (`ta`).
class AppLocalizationsTa extends AppLocalizations {
  AppLocalizationsTa([String locale = 'ta']) : super(locale);

  @override
  String get appName => 'NewsOn';

  @override
  String get welcomeTo => 'வரவேற்கிறோம்';

  @override
  String get swipeToGetStarted => 'தொடங்குவதற்கு வலப்புறம் நகர்த்தவும்';

  @override
  String get getStarted => 'தொடங்குங்கள்';

  @override
  String get signIn => 'உள்நுழைய';

  @override
  String get signInToYourAccount => 'உங்கள் கணக்கில் உள்நுழைய';

  @override
  String get connecting => 'இணைக்கப்படுகிறது...';

  @override
  String get connectingToGoogle => 'Google உடன் இணைக்கப்படுகிறது...';

  @override
  String get welcome => 'வரவேற்கிறோம்!';

  @override
  String get signInCancelled => 'உள்நுழைவு ரத்து செய்யப்பட்டது';

  @override
  String signInFailed(String error) {
    return 'உள்நுழைவு தோல்வி: $error';
  }

  @override
  String get skip => 'தவிர்க்க';

  @override
  String get continueText => 'தொடர';

  @override
  String get enterYourName => 'உங்கள் பெயரை உள்ளிடவும்';

  @override
  String get selectCategories => 'வகைகளைத் தேர்ந்தெடுக்கவும்';

  @override
  String get selectAtLeastOneCategory =>
      'தயவுசெய்து குறைந்தது ஒரு வகையைத் தேர்ந்தெடுக்கவும்';

  @override
  String get categories => 'வகைகள்';

  @override
  String get bookmarks => 'புத்தகக்குறிகள்';

  @override
  String get search => 'தேட';

  @override
  String get headlines => 'தலைப்புகள்';

  @override
  String get forYou => 'உங்களுக்காக';

  @override
  String get pickedForYouSubtitle =>
      'உங்கள் ஆர்வங்களின் அடிப்படையில் தேர்ந்தெடுக்கப்பட்ட கதைகள்';

  @override
  String get moreStoriesForYou => 'உங்களுக்கான மேலும் கதைகள்';

  @override
  String storiesCount(int count) {
    return '$count கதைகள்';
  }

  @override
  String get shareNewsCuriousCta =>
      '🔥 இந்த செய்தியின் முழு உண்மை NewsOn-ல் — இப்போதே படியுங்கள் 👇';

  @override
  String get newsFeed => 'செய்தி ஊட்டம்';

  @override
  String get retry => 'மீண்டும் முயற்சிக்க';

  @override
  String get noNewsAvailable => 'செய்திகள் இல்லை';

  @override
  String get noResultsFound => 'முடிவுகள் எதுவும் கிடைக்கவில்லை';

  @override
  String get clearAllBookmarks => 'அனைத்து புத்தகக்குறிகளையும் அழிக்கவா?';

  @override
  String get cancel => 'ரத்து செய்';

  @override
  String get selectDate => 'தேதியைத் தேர்ந்தெடுக்கவும்';

  @override
  String get datePickerConfirm => 'தேர்ந்தெடு';

  @override
  String get dateLabel => 'தேதி';

  @override
  String get datePickerFieldHint => 'மாதம்/நாள்/ஆண்டு';

  @override
  String get clear => 'அழி';

  @override
  String get allBookmarksCleared => 'அனைத்து புத்தகக்குறிகளும் அழிக்கப்பட்டன';

  @override
  String get addedToBookmarks => 'புத்தகக்குறிகளில் சேர்க்கப்பட்டது';

  @override
  String get removedFromBookmarks => 'புத்தகக்குறிகளிலிருந்து நீக்கப்பட்டது';

  @override
  String get noInternetConnection =>
      'இணைய இணைப்பு இல்லை. தயவுசெய்து உங்கள் நெட்வொர்க்கை சரிபார்க்கவும்.';

  @override
  String get serverError => 'சர்வர் பிழை. தயவுசெய்து பிறகு முயற்சிக்கவும்.';

  @override
  String get unknownError => 'அறியப்படாத பிழை ஏற்பட்டது.';

  @override
  String get noDataAvailable => 'தரவு இல்லை.';

  @override
  String error(String error) {
    return 'பிழை: $error';
  }

  @override
  String get textSizeSaved => 'உரை அளவு சேமிக்கப்பட்டது';

  @override
  String get formSubmittedSuccessfully =>
      'படிவம் வெற்றிகரமாக சமர்ப்பிக்கப்பட்டது!';

  @override
  String get pleaseFixErrorsBeforeSaving =>
      'சேமிப்பதற்கு முன் தயவுசெய்து பிழைகளை சரிசெய்யவும்';

  @override
  String get accountSettings => 'கணக்கு அமைப்புகள்';

  @override
  String get appearanceSettings => 'தோற்றம்';

  @override
  String get applicationSettings => 'பயன்பாட்டு அமைப்புகள்';

  @override
  String get notifications => 'அறிவிப்புகள்';

  @override
  String get privacyPolicy => 'தனியுரிமை கொள்கை';

  @override
  String get termsAndConditions => 'விதிமுறைகள் மற்றும் நிபந்தனைகள்';

  @override
  String get language => 'மொழி';

  @override
  String get logout => 'வெளியேற';

  @override
  String get areYouSureYouWantToLogout =>
      'நீங்கள் உறுதியாக வெளியேற விரும்புகிறீர்களா?';

  @override
  String get yes => 'ஆம்';

  @override
  String get no => 'இல்லை';

  @override
  String get selectLanguage => 'மொழியைத் தேர்ந்தெடுக்கவும்';

  @override
  String get english => 'ஆங்கிலம்';

  @override
  String get hindi => 'இந்தி';

  @override
  String get tamil => 'தமிழ்';

  @override
  String get spanish => 'ஸ்பானிஷ்';

  @override
  String get french => 'பிரெஞ்சு';

  @override
  String get german => 'ஜெர்மன்';

  @override
  String get chinese => 'சீனம்';

  @override
  String get japanese => 'ஜப்பானியம்';

  @override
  String get arabic => 'அரபு';

  @override
  String get portuguese => 'போர்த்துகீசியம்';

  @override
  String get russian => 'ரஷ்யன்';

  @override
  String get loading => 'ஏற்றுகிறது...';

  @override
  String get somethingWentWrong => 'ஏதோ தவறு நடந்தது';

  @override
  String get tryAgain => 'மீண்டும் முயற்சிக்க';

  @override
  String get noNewsForDate => 'இந்த தேதிக்கு செய்திகள் கிடைக்கவில்லை';

  @override
  String get remoteConfigRefreshed =>
      'ரிமோட் கன்ஃபிக் வெற்றிகரமாக புதுப்பிக்கப்பட்டது!';

  @override
  String failedToRefresh(String error) {
    return 'புதுப்பிக்க முடியவில்லை: $error';
  }

  @override
  String get welcomeTitleText => 'வரவேற்கிறோம்';

  @override
  String get welcomeDescText => 'செய்திகளின் உலகை ஆராய தயாராகுங்கள்!';

  @override
  String get selectCategoryTitle => 'உங்கள் ஆர்வங்களைத் தேர்ந்தெடுக்கவும்';

  @override
  String get selectCategoryDesc =>
      'நீங்கள் பின்தொடர விரும்பும் வகைகளைத் தேர்ந்தெடுக்கவும்';

  @override
  String get menu => 'மெனு';

  @override
  String get today => 'இன்று';

  @override
  String get forLater => 'பின்னர்';

  @override
  String get notificationInbox => 'அறிவிப்பு இன்பாக்ஸ்';

  @override
  String get bookmark => 'புத்தகக்குறி';

  @override
  String get termsOfUse => 'பயன்பாட்டு விதிமுறைகள்';

  @override
  String get newsCategories => 'செய்தி வகைகள்';

  @override
  String get listen => 'கேள்';

  @override
  String get userName => 'பயனர் பெயர்';

  @override
  String get enterYourFirstName => 'உங்கள் முதல் பெயரை உள்ளிடவும் *';

  @override
  String get enterYourSecondName => 'உங்கள் இரண்டாம் பெயரை உள்ளிடவும்';

  @override
  String get firstNameRequired => 'முதல் பெயர் தேவை';

  @override
  String get emailId => 'மின்னஞ்சல்-ஐடி';

  @override
  String get enterYourEmailId => 'உங்கள் மின்னஞ்சல் ஐடியை உள்ளிடவும்';

  @override
  String get emailRequired => 'மின்னஞ்சல் தேவை';

  @override
  String get enterValidEmail => 'செல்லுபடியாகும் மின்னஞ்சலை உள்ளிடவும்';

  @override
  String get personalDetails => 'தனிப்பட்ட விவரங்கள்';

  @override
  String get enterMobileNumber => 'மொபைல் எண்ணை உள்ளிடவும்';

  @override
  String get mobileNumberRequired => 'மொபைல் எண் தேவை';

  @override
  String get enterValidMobileNumber =>
      'செல்லுபடியாகும் 10-இலக்க மொபைல் எண்ணை உள்ளிடவும்';

  @override
  String get selectCity => 'நகரத்தைத் தேர்ந்தெடுக்கவும்';

  @override
  String get pleaseSelectCity => 'தயவுசெய்து ஒரு நகரத்தைத் தேர்ந்தெடுக்கவும்';

  @override
  String get enterPincode => 'பின்கோட் உள்ளிடவும்';

  @override
  String get pincodeRequired => 'பின்கோட் தேவை';

  @override
  String get enterValidPincode =>
      'செல்லுபடியாகும் 6-இலக்க பின்கோட்டை உள்ளிடவும்';

  @override
  String get selectCountry => 'நாட்டைத் தேர்ந்தெடுக்கவும்';

  @override
  String get pleaseSelectCountry => 'தயவுசெய்து ஒரு நாட்டைத் தேர்ந்தெடுக்கவும்';

  @override
  String get socialAccount => 'சமூக கணக்கு';

  @override
  String get loginWithGoogle => 'Google உடன் உள்நுழைய';

  @override
  String get connected => 'இணைக்கப்பட்டது';

  @override
  String get appearance => 'தோற்றம்';

  @override
  String get textSize => 'உரை அளவு';

  @override
  String get save => 'சேமிக்க';

  @override
  String get lightMode => 'வெளிச்ச முறை';

  @override
  String get darkMode => 'இருண்ட முறை';

  @override
  String get systemDefault => 'கணினி இயல்புநிலை';

  @override
  String get unknownSource => 'அறியப்படாத மூலம்';

  @override
  String get version => 'பதிப்பு';

  @override
  String get yourPersonalizedNewsApplication =>
      'உங்கள் தனிப்பயனாக்கப்பட்ட செய்தி பயன்பாடு';

  @override
  String get close => 'மூடு';

  @override
  String get breakingNews => 'பிரேக்கிங் நியூஸ்';

  @override
  String get viewAll => 'அனைத்தையும் பார்க்க';

  @override
  String get flashNews => 'ஃபிளாஷ் செய்தி';

  @override
  String get liveCricketScore => 'நேரடி கிரிக்கெட் ஸ்கோர்';

  @override
  String get yesterday => 'நேற்று';

  @override
  String get hotNews => 'ஹாட் நியூஸ்';

  @override
  String get newsReadingSettings => 'செய்தி வாசிப்பு அமைப்புகள்';

  @override
  String get playTitleOnly => 'தலைப்பை மட்டும் இயக்க';

  @override
  String get playDescriptionOnly => 'விளக்கத்தை மட்டும் இயக்க';

  @override
  String get playFullNews => 'முழு செய்தியை இயக்க';

  @override
  String get selectNewsReadingMode =>
      'செய்தி வாசிப்பு முறையைத் தேர்ந்தெடுக்கவும்';

  @override
  String get settingsSaved => 'அமைப்புகள் சேமிக்கப்பட்டது';

  @override
  String get backgroundMusic => 'பின்னணி இசை';

  @override
  String get backgroundMusicSettings => 'பின்னணி இசை';

  @override
  String get backgroundMusicSettingsDescription =>
      'செய்திகளைக் கேட்கும்போது பின்னணி இசையை இயக்கவும். கீழே அணைக்கலாம் அல்லது வலிமையை சரிசெய்யலாம்.';

  @override
  String get enableBackgroundMusic => 'பின்னணி இசையை இயக்கு';

  @override
  String get backgroundMusicVolume => 'பின்னணி இசை வலிமை';

  @override
  String get backgroundMusicEnabled => 'பின்னணி இசை இயக்கப்பட்டது';

  @override
  String get backgroundMusicDisabled => 'பின்னணி இசை அணைக்கப்பட்டது';

  @override
  String get contactUs => 'எங்களை தொடர்பு கொள்ள';

  @override
  String get getInTouch => 'தொடர்பில் இருங்கள்';

  @override
  String get contactSupportText =>
      'எங்கள் உள்ளடக்கம் மற்றும் தளம் தொடர்பான ஆதரவு, விசாரணைகள் அல்லது பின்னூட்டங்களுக்கு, தயவுசெய்து எங்களை தொடர்பு கொள்ளவும்.';

  @override
  String get email => 'மின்னஞ்சல்';

  @override
  String get phone => 'தொலைபேசி';

  @override
  String get website => 'இணையதளம்';

  @override
  String get selectRegion => 'பிராந்தியத்தைத் தேர்ந்தெடுக்கவும்';

  @override
  String get regionCountry => 'நாடு';

  @override
  String get regionState => 'மாநிலம்';

  @override
  String get regionDistrict => 'மாவட்டம்';

  @override
  String get selectOption => 'ஒரு விருப்பத்தைத் தேர்ந்தெடுக்கவும்';

  @override
  String get apply => 'பயன்படுத்து';

  @override
  String get reset => 'மீட்டமை';

  @override
  String get noNewsForRegion =>
      'தேர்ந்தெடுக்கப்பட்ட பிராந்தியத்திற்கு செய்திகள் இல்லை';

  @override
  String get selectRegionTooltip =>
      'பிராந்தியத்தின் அடிப்படையில் செய்திகளை வடிகட்டு';

  @override
  String get noBookmarks => 'புக்மார்க்குகள் இல்லை';

  @override
  String get bookmarksWillAppearHere =>
      'நீங்கள் புக்மார்க் செய்யும் கட்டுரைகள் இங்கே தோன்றும்';

  @override
  String get errorLoadingBookmarks => 'புக்மார்க்குகளை ஏற்றுவதில் பிழை';

  @override
  String get clearBookmarksMessage =>
      'இது சேமித்த அனைத்து கட்டுரைகளையும் நீக்கும். இந்தச் செயலை மீட்டமைக்க முடியாது.';

  @override
  String errorPlayingAudio(String error) {
    return 'ஆடியோவை இயக்குவதில் பிழை: $error';
  }

  @override
  String failedToPlayAudio(String error) {
    return 'ஆடியோவை இயக்க முடியவில்லை: $error';
  }

  @override
  String get noBreakingNewsAvailable => 'முக்கியச் செய்திகள் எதுவும் இல்லை';

  @override
  String get noNewsForThisCategory =>
      'இந்தப் பிரிவுக்கு செய்திகள் எதுவும் இல்லை';

  @override
  String get recentSearches => 'சமீபத்திய தேடல்கள்';

  @override
  String get searchNewsHint => 'செய்திகளைத் தேடு...';

  @override
  String get enterKeywordsToFindArticles =>
      'கட்டுரைகளைக் கண்டறிய முக்கிய வார்த்தைகளை உள்ளிடவும்';

  @override
  String get orTryVoiceSearch =>
      'அல்லது மைக்ரோஃபோனைப் பயன்படுத்தி குரல் தேடலை முயற்சிக்கவும்';

  @override
  String get tryDifferentKeywords =>
      'வேறு முக்கிய வார்த்தைகளை முயற்சிக்கவும் அல்லது எழுத்துப்பிழையைச் சரிபார்க்கவும்';

  @override
  String sourceLabel(String source) {
    return 'ஆதாரம்: $source';
  }

  @override
  String authorLabel(String author) {
    return 'எழுதியவர்: $author';
  }

  @override
  String publishedLabel(String date) {
    return 'வெளியிடப்பட்டது: $date';
  }

  @override
  String get justNow => 'இப்போதே';

  @override
  String get selectAll => 'அனைத்தையும் தேர்ந்தெடு';

  @override
  String get deselectAll => 'அனைத்தையும் நீக்கு';

  @override
  String get updatePreferences => 'விருப்பங்களைப் புதுப்பி';

  @override
  String categoriesSelectedCount(int selected, int total) {
    return '$total இல் $selected தேர்ந்தெடுக்கப்பட்டது';
  }

  @override
  String get agreeToTermsPrivacy =>
      'தொடர்வதன் மூலம், எங்கள் விதிமுறைகள் & தனியுரிமைக் கொள்கையை ஏற்கிறீர்கள்';

  @override
  String get tapToPlayArticle => 'கட்டுரையை இயக்க தட்டவும்';

  @override
  String get selectNewsLanguage => 'செய்தி மொழியைத் தேர்ந்தெடு';

  @override
  String get selectAppLanguage => 'ஆப் மொழியைத் தேர்ந்தெடு';

  @override
  String get submit => 'சமர்ப்பி';

  @override
  String get shareThisNews => 'இந்தச் செய்தியைப் பகிர்';

  @override
  String get shareThisNewsSubtitle =>
      'NewsOn உள்ள நண்பர்கள் கட்டுரையை ஆப்பில் திறக்க முடியும்';

  @override
  String get generatingAudio => 'ஆடியோ உருவாக்கப்படுகிறது...';

  @override
  String get convertingTextToSpeech =>
      'ElevenLabs மூலம் உரையைப் பேச்சாக மாற்றுகிறது';

  @override
  String get sponsored => 'விளம்பரம்';

  @override
  String get deleteAccount => 'கணக்கை நீக்கு';

  @override
  String get deleteAccountTitle => 'கணக்கை நீக்கவா?';

  @override
  String get deleteAccountMessage =>
      'இது உங்கள் கணக்கையும் அதனுடன் தொடர்புடைய அனைத்து தரவையும் நிரந்தரமாக நீக்கும். இந்தச் செயலை மீட்டமைக்க முடியாது.';

  @override
  String get delete => 'நீக்கு';

  @override
  String get signInToReadSharedArticle =>
      'பகிரப்பட்ட கட்டுரையைப் படிக்க உள்நுழையவும்';

  @override
  String get pleaseWaitSettingUp => 'அமைக்கும் வரை சிறிது காத்திருக்கவும்';

  @override
  String get signInWithApple => 'ஆப்பிள் மூலம் உள்நுழையவும்';

  @override
  String get continueWithGoogle => 'Google உடன் தொடரவும்';

  @override
  String get failedToLoadCategories => 'பிரிவுகளை ஏற்ற முடியவில்லை';

  @override
  String errorLoadingNews(String error) {
    return 'செய்திகளை ஏற்றுவதில் பிழை: $error';
  }

  @override
  String get playing => 'இயக்குகிறது...';

  @override
  String get paused => 'இடைநிறுத்தப்பட்டது';

  @override
  String get voiceFeaturesUnavailable =>
      'குரல் மற்றும் ஆடியோ அம்சங்கள் தற்போது கிடைக்கவில்லை.';
}
