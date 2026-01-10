// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appName => 'NewsOn';

  @override
  String get welcomeTo => 'BIENVENUE DANS';

  @override
  String get swipeToGetStarted => 'Glissez pour commencer';

  @override
  String get signIn => 'Se connecter';

  @override
  String get signInToYourAccount => 'Connectez-vous à votre compte';

  @override
  String get connecting => 'Connexion...';

  @override
  String get connectingToGoogle => 'Connexion à Google...';

  @override
  String get welcome => 'Bienvenue !';

  @override
  String get signInCancelled => 'Connexion annulée';

  @override
  String signInFailed(String error) {
    return 'Échec de la connexion : $error';
  }

  @override
  String get skip => 'Passer';

  @override
  String get continueText => 'Continuer';

  @override
  String get enterYourName => 'Entrez votre nom';

  @override
  String get selectCategories => 'Sélectionner les Catégories';

  @override
  String get selectAtLeastOneCategory => 'Veuillez sélectionner au moins une catégorie';

  @override
  String get categories => 'Catégories';

  @override
  String get bookmarks => 'Signets';

  @override
  String get search => 'Rechercher';

  @override
  String get headlines => 'Titres';

  @override
  String get newsFeed => 'Fil d\'actualité';

  @override
  String get retry => 'Réessayer';

  @override
  String get noNewsAvailable => 'Aucune actualité disponible';

  @override
  String get noResultsFound => 'Aucun résultat trouvé';

  @override
  String get clearAllBookmarks => 'Effacer tous les signets ?';

  @override
  String get cancel => 'Annuler';

  @override
  String get clear => 'Effacer';

  @override
  String get allBookmarksCleared => 'Tous les signets ont été effacés';

  @override
  String get addedToBookmarks => 'Ajouté aux signets';

  @override
  String get removedFromBookmarks => 'Retiré des signets';

  @override
  String get noInternetConnection => 'Aucune connexion Internet. Veuillez vérifier votre réseau.';

  @override
  String get serverError => 'Erreur du serveur. Veuillez réessayer plus tard.';

  @override
  String get unknownError => 'Une erreur inconnue s\'est produite.';

  @override
  String get noDataAvailable => 'Aucune donnée disponible.';

  @override
  String error(String error) {
    return 'Erreur : $error';
  }

  @override
  String get textSizeSaved => 'Taille du texte enregistrée';

  @override
  String get formSubmittedSuccessfully => 'Formulaire soumis avec succès !';

  @override
  String get pleaseFixErrorsBeforeSaving => 'Veuillez corriger les erreurs avant d\'enregistrer';

  @override
  String get accountSettings => 'Paramètres du Compte';

  @override
  String get appearanceSettings => 'Apparence';

  @override
  String get applicationSettings => 'Paramètres de l\'Application';

  @override
  String get notifications => 'Notifications';

  @override
  String get privacyPolicy => 'Politique de Confidentialité';

  @override
  String get termsAndConditions => 'Termes et Conditions';

  @override
  String get language => 'Langue';

  @override
  String get logout => 'Déconnexion';

  @override
  String get areYouSureYouWantToLogout => 'Êtes-vous sûr de vouloir vous déconnecter ?';

  @override
  String get yes => 'Oui';

  @override
  String get no => 'Non';

  @override
  String get selectLanguage => 'Sélectionner la Langue';

  @override
  String get english => 'Anglais';

  @override
  String get hindi => 'Hindi';

  @override
  String get tamil => 'Tamil';

  @override
  String get spanish => 'Espagnol';

  @override
  String get french => 'Français';

  @override
  String get german => 'Allemand';

  @override
  String get chinese => 'Chinois';

  @override
  String get japanese => 'Japonais';

  @override
  String get arabic => 'Arabe';

  @override
  String get portuguese => 'Portugais';

  @override
  String get russian => 'Russe';

  @override
  String get loading => 'Chargement...';

  @override
  String get somethingWentWrong => 'Quelque chose s\'est mal passé';

  @override
  String get tryAgain => 'Réessayer';

  @override
  String get noNewsForDate => 'Aucune actualité trouvée pour cette date';

  @override
  String get remoteConfigRefreshed => 'Configuration distante actualisée avec succès !';

  @override
  String failedToRefresh(String error) {
    return 'Échec de l\'actualisation : $error';
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

  @override
  String get newsReadingSettings => 'Paramètres de lecture des actualités';

  @override
  String get playTitleOnly => 'Lire uniquement le titre';

  @override
  String get playDescriptionOnly => 'Lire uniquement la description';

  @override
  String get playFullNews => 'Lire l\'actualité complète';

  @override
  String get selectNewsReadingMode => 'Sélectionner le mode de lecture des actualités';

  @override
  String get settingsSaved => 'Paramètres enregistrés';
}
