// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appName => 'NewsOn';

  @override
  String get welcomeTo => 'BIENVENIDO A';

  @override
  String get swipeToGetStarted => 'Desliza para comenzar';

  @override
  String get signIn => 'Iniciar sesión';

  @override
  String get signInToYourAccount => 'Inicia sesión en tu cuenta';

  @override
  String get connecting => 'Conectando...';

  @override
  String get connectingToGoogle => 'Conectando a Google...';

  @override
  String get welcome => '¡Bienvenido!';

  @override
  String get signInCancelled => 'Inicio de sesión cancelado';

  @override
  String signInFailed(String error) {
    return 'Error al iniciar sesión: $error';
  }

  @override
  String get skip => 'Omitir';

  @override
  String get continueText => 'Continuar';

  @override
  String get enterYourName => 'Ingresa tu nombre';

  @override
  String get selectCategories => 'Seleccionar Categorías';

  @override
  String get selectAtLeastOneCategory => 'Por favor selecciona al menos una categoría';

  @override
  String get categories => 'Categorías';

  @override
  String get bookmarks => 'Marcadores';

  @override
  String get search => 'Buscar';

  @override
  String get headlines => 'Titulares';

  @override
  String get newsFeed => 'Feed de Noticias';

  @override
  String get retry => 'Reintentar';

  @override
  String get noNewsAvailable => 'No hay noticias disponibles';

  @override
  String get noResultsFound => 'No se encontraron resultados';

  @override
  String get clearAllBookmarks => '¿Eliminar todos los marcadores?';

  @override
  String get cancel => 'Cancelar';

  @override
  String get clear => 'Limpiar';

  @override
  String get allBookmarksCleared => 'Todos los marcadores fueron eliminados';

  @override
  String get addedToBookmarks => 'Agregado a marcadores';

  @override
  String get removedFromBookmarks => 'Eliminado de marcadores';

  @override
  String get noInternetConnection => 'No hay conexión a Internet. Por favor verifica tu red.';

  @override
  String get serverError => 'Error del servidor. Por favor intenta más tarde.';

  @override
  String get unknownError => 'Ocurrió un error desconocido.';

  @override
  String get noDataAvailable => 'No hay datos disponibles.';

  @override
  String error(String error) {
    return 'Error: $error';
  }

  @override
  String get textSizeSaved => 'Tamaño de texto guardado';

  @override
  String get formSubmittedSuccessfully => '¡Formulario enviado exitosamente!';

  @override
  String get pleaseFixErrorsBeforeSaving => 'Por favor corrige los errores antes de guardar';

  @override
  String get accountSettings => 'Configuración de Cuenta';

  @override
  String get appearanceSettings => 'Apariencia';

  @override
  String get applicationSettings => 'Configuración de Aplicación';

  @override
  String get notifications => 'Notificaciones';

  @override
  String get privacyPolicy => 'Política de Privacidad';

  @override
  String get termsAndConditions => 'Términos y Condiciones';

  @override
  String get language => 'Idioma';

  @override
  String get logout => 'Cerrar sesión';

  @override
  String get areYouSureYouWantToLogout => '¿Estás seguro de que quieres cerrar sesión?';

  @override
  String get yes => 'Sí';

  @override
  String get no => 'No';

  @override
  String get selectLanguage => 'Seleccionar Idioma';

  @override
  String get english => 'Inglés';

  @override
  String get hindi => 'Hindi';

  @override
  String get tamil => 'Tamil';

  @override
  String get spanish => 'Español';

  @override
  String get french => 'Francés';

  @override
  String get german => 'Alemán';

  @override
  String get chinese => 'Chino';

  @override
  String get japanese => 'Japonés';

  @override
  String get arabic => 'Árabe';

  @override
  String get portuguese => 'Portugués';

  @override
  String get russian => 'Ruso';

  @override
  String get loading => 'Cargando...';

  @override
  String get somethingWentWrong => 'Algo salió mal';

  @override
  String get tryAgain => 'Intentar de nuevo';

  @override
  String get noNewsForDate => 'No se encontraron noticias para esta fecha';

  @override
  String get remoteConfigRefreshed => '¡Configuración remota actualizada exitosamente!';

  @override
  String failedToRefresh(String error) {
    return 'Error al actualizar: $error';
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
  String get newsReadingSettings => 'Configuración de lectura de noticias';

  @override
  String get playTitleOnly => 'Reproducir solo el título';

  @override
  String get playDescriptionOnly => 'Reproducir solo la descripción';

  @override
  String get playFullNews => 'Reproducir noticia completa';

  @override
  String get selectNewsReadingMode => 'Seleccionar modo de lectura de noticias';

  @override
  String get settingsSaved => 'Configuración guardada';
}
