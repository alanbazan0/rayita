import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

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
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

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
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In es, this message translates to:
  /// **'Rayita'**
  String get appTitle;

  /// No description provided for @signIn.
  ///
  /// In es, this message translates to:
  /// **'Inicia sesión'**
  String get signIn;

  /// No description provided for @createYourAccount.
  ///
  /// In es, this message translates to:
  /// **'Crea tu cuenta'**
  String get createYourAccount;

  /// No description provided for @name.
  ///
  /// In es, this message translates to:
  /// **'Nombre'**
  String get name;

  /// No description provided for @email.
  ///
  /// In es, this message translates to:
  /// **'Correo'**
  String get email;

  /// No description provided for @password.
  ///
  /// In es, this message translates to:
  /// **'Contraseña'**
  String get password;

  /// No description provided for @validationName.
  ///
  /// In es, this message translates to:
  /// **'Escribe tu nombre.'**
  String get validationName;

  /// No description provided for @validationEmail.
  ///
  /// In es, this message translates to:
  /// **'Escribe un correo válido.'**
  String get validationEmail;

  /// No description provided for @validationPassword.
  ///
  /// In es, this message translates to:
  /// **'Mínimo 8 caracteres.'**
  String get validationPassword;

  /// No description provided for @register.
  ///
  /// In es, this message translates to:
  /// **'Registrarme'**
  String get register;

  /// No description provided for @enter.
  ///
  /// In es, this message translates to:
  /// **'Entrar'**
  String get enter;

  /// No description provided for @haveAccount.
  ///
  /// In es, this message translates to:
  /// **'Ya tengo cuenta'**
  String get haveAccount;

  /// No description provided for @createAccount.
  ///
  /// In es, this message translates to:
  /// **'Crear una cuenta'**
  String get createAccount;

  /// No description provided for @myHabits.
  ///
  /// In es, this message translates to:
  /// **'Mis hábitos'**
  String get myHabits;

  /// No description provided for @logout.
  ///
  /// In es, this message translates to:
  /// **'Cerrar sesión'**
  String get logout;

  /// No description provided for @newHabit.
  ///
  /// In es, this message translates to:
  /// **'Nuevo hábito'**
  String get newHabit;

  /// No description provided for @noHabits.
  ///
  /// In es, this message translates to:
  /// **'Aún no tienes hábitos.\nCrea el primero con el botón de abajo.'**
  String get noHabits;

  /// No description provided for @retry.
  ///
  /// In es, this message translates to:
  /// **'Reintentar'**
  String get retry;

  /// No description provided for @editHabit.
  ///
  /// In es, this message translates to:
  /// **'Editar hábito'**
  String get editHabit;

  /// No description provided for @deleteHabit.
  ///
  /// In es, this message translates to:
  /// **'Eliminar hábito'**
  String get deleteHabit;

  /// No description provided for @deleteHabitTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Eliminar hábito?'**
  String get deleteHabitTitle;

  /// No description provided for @deleteHabitBody.
  ///
  /// In es, this message translates to:
  /// **'Se borrará \"{name}\" junto con todas sus marcas.'**
  String deleteHabitBody(String name);

  /// No description provided for @cancel.
  ///
  /// In es, this message translates to:
  /// **'Cancelar'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In es, this message translates to:
  /// **'Eliminar'**
  String get delete;

  /// No description provided for @save.
  ///
  /// In es, this message translates to:
  /// **'Guardar'**
  String get save;

  /// No description provided for @create.
  ///
  /// In es, this message translates to:
  /// **'Crear'**
  String get create;

  /// No description provided for @habitNameLabel.
  ///
  /// In es, this message translates to:
  /// **'Nombre (ej. Ir al gym)'**
  String get habitNameLabel;

  /// No description provided for @color.
  ///
  /// In es, this message translates to:
  /// **'Color'**
  String get color;

  /// No description provided for @iconOptional.
  ///
  /// In es, this message translates to:
  /// **'Ícono (opcional)'**
  String get iconOptional;

  /// No description provided for @iconSemantic.
  ///
  /// In es, this message translates to:
  /// **'Ícono {name}'**
  String iconSemantic(String name);

  /// No description provided for @previousMonth.
  ///
  /// In es, this message translates to:
  /// **'Mes anterior'**
  String get previousMonth;

  /// No description provided for @nextMonth.
  ///
  /// In es, this message translates to:
  /// **'Mes siguiente'**
  String get nextMonth;

  /// No description provided for @tapDayHint.
  ///
  /// In es, this message translates to:
  /// **'Toca un día para marcarlo como cumplido, o tócalo de nuevo para quitarlo.'**
  String get tapDayHint;

  /// No description provided for @currentStreak.
  ///
  /// In es, this message translates to:
  /// **'Racha actual'**
  String get currentStreak;

  /// No description provided for @longestStreak.
  ///
  /// In es, this message translates to:
  /// **'Racha más larga'**
  String get longestStreak;

  /// No description provided for @thisMonth.
  ///
  /// In es, this message translates to:
  /// **'Este mes'**
  String get thisMonth;

  /// No description provided for @total.
  ///
  /// In es, this message translates to:
  /// **'Total'**
  String get total;

  /// No description provided for @doneCount.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 cumplido} other{{count} cumplidos}}'**
  String doneCount(int count);

  /// No description provided for @noMarks.
  ///
  /// In es, this message translates to:
  /// **'Sin marcas'**
  String get noMarks;

  /// No description provided for @marksCount.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 marca} other{{count} marcas}}'**
  String marksCount(int count);

  /// No description provided for @statusNone.
  ///
  /// In es, this message translates to:
  /// **'sin marca'**
  String get statusNone;

  /// No description provided for @statusDone.
  ///
  /// In es, this message translates to:
  /// **'cumplido'**
  String get statusDone;

  /// No description provided for @weekdayInitials.
  ///
  /// In es, this message translates to:
  /// **'L,M,M,J,V,S,D'**
  String get weekdayInitials;

  /// No description provided for @errorConnection.
  ///
  /// In es, this message translates to:
  /// **'No se pudo conectar con el servidor.'**
  String get errorConnection;

  /// No description provided for @errorUnexpected.
  ///
  /// In es, this message translates to:
  /// **'Ocurrió un error inesperado.'**
  String get errorUnexpected;

  /// No description provided for @language.
  ///
  /// In es, this message translates to:
  /// **'Idioma'**
  String get language;

  /// No description provided for @languageSystem.
  ///
  /// In es, this message translates to:
  /// **'Automático'**
  String get languageSystem;

  /// No description provided for @tagline.
  ///
  /// In es, this message translates to:
  /// **'Construye hábitos, un día a la vez.'**
  String get tagline;

  /// No description provided for @todayLabel.
  ///
  /// In es, this message translates to:
  /// **'Hoy'**
  String get todayLabel;

  /// No description provided for @todayProgress.
  ///
  /// In es, this message translates to:
  /// **'{done} de {total} cumplidos'**
  String todayProgress(int done, int total);

  /// No description provided for @streakDays.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 día} other{{count} días}}'**
  String streakDays(int count);

  /// No description provided for @markToday.
  ///
  /// In es, this message translates to:
  /// **'Marcar hoy'**
  String get markToday;

  /// No description provided for @unmarkToday.
  ///
  /// In es, this message translates to:
  /// **'Quitar la marca de hoy'**
  String get unmarkToday;

  /// No description provided for @doneWord.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{cumplido} other{cumplidos}}'**
  String doneWord(int count);

  /// No description provided for @confirmPassword.
  ///
  /// In es, this message translates to:
  /// **'Confirmar contraseña'**
  String get confirmPassword;

  /// No description provided for @validationPasswordMatch.
  ///
  /// In es, this message translates to:
  /// **'Las contraseñas no coinciden.'**
  String get validationPasswordMatch;

  /// No description provided for @verifyTitle.
  ///
  /// In es, this message translates to:
  /// **'Verifica tu correo'**
  String get verifyTitle;

  /// No description provided for @verifySubtitle.
  ///
  /// In es, this message translates to:
  /// **'Enviamos un código de 6 dígitos a {email}.'**
  String verifySubtitle(String email);

  /// No description provided for @codeLabel.
  ///
  /// In es, this message translates to:
  /// **'Código de verificación'**
  String get codeLabel;

  /// No description provided for @validationCode.
  ///
  /// In es, this message translates to:
  /// **'Escribe el código de 6 dígitos.'**
  String get validationCode;

  /// No description provided for @verifyButton.
  ///
  /// In es, this message translates to:
  /// **'Verificar'**
  String get verifyButton;

  /// No description provided for @resendCode.
  ///
  /// In es, this message translates to:
  /// **'Reenviar código'**
  String get resendCode;

  /// No description provided for @resendIn.
  ///
  /// In es, this message translates to:
  /// **'Reenviar en {seconds} s'**
  String resendIn(int seconds);

  /// No description provided for @codeSent.
  ///
  /// In es, this message translates to:
  /// **'Te enviamos un nuevo código.'**
  String get codeSent;

  /// No description provided for @useAnotherAccount.
  ///
  /// In es, this message translates to:
  /// **'Usar otra cuenta'**
  String get useAnotherAccount;

  /// No description provided for @checkSpam.
  ///
  /// In es, this message translates to:
  /// **'Si no lo ves, revisa la carpeta de spam.'**
  String get checkSpam;

  /// No description provided for @goalSection.
  ///
  /// In es, this message translates to:
  /// **'Meta (opcional)'**
  String get goalSection;

  /// No description provided for @goalEnable.
  ///
  /// In es, this message translates to:
  /// **'Definir una meta'**
  String get goalEnable;

  /// No description provided for @goalByDays.
  ///
  /// In es, this message translates to:
  /// **'Por días'**
  String get goalByDays;

  /// No description provided for @goalByDates.
  ///
  /// In es, this message translates to:
  /// **'Por fechas'**
  String get goalByDates;

  /// No description provided for @goalDaysLabel.
  ///
  /// In es, this message translates to:
  /// **'Número de días'**
  String get goalDaysLabel;

  /// No description provided for @goalStartLabel.
  ///
  /// In es, this message translates to:
  /// **'Inicio'**
  String get goalStartLabel;

  /// No description provided for @goalEndLabel.
  ///
  /// In es, this message translates to:
  /// **'Fin'**
  String get goalEndLabel;

  /// No description provided for @goalOnFail.
  ///
  /// In es, this message translates to:
  /// **'Si fallas un día'**
  String get goalOnFail;

  /// No description provided for @goalReset.
  ///
  /// In es, this message translates to:
  /// **'Reiniciar'**
  String get goalReset;

  /// No description provided for @goalAccumulate.
  ///
  /// In es, this message translates to:
  /// **'Acumular'**
  String get goalAccumulate;

  /// No description provided for @goalResetHint.
  ///
  /// In es, this message translates to:
  /// **'El conteo vuelve a empezar desde 0.'**
  String get goalResetHint;

  /// No description provided for @goalAccumulateHint.
  ///
  /// In es, this message translates to:
  /// **'Cuentan los días cumplidos, aunque no sean seguidos.'**
  String get goalAccumulateHint;

  /// No description provided for @goalProgress.
  ///
  /// In es, this message translates to:
  /// **'{progress} / {target} días'**
  String goalProgress(int progress, int target);

  /// No description provided for @goalAchieved.
  ///
  /// In es, this message translates to:
  /// **'¡Meta lograda! 🎉'**
  String get goalAchieved;

  /// No description provided for @goalFailed.
  ///
  /// In es, this message translates to:
  /// **'Meta no lograda'**
  String get goalFailed;

  /// No description provided for @goalDaysLeft.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =0{Último día} =1{Queda 1 día} other{Quedan {count} días}}'**
  String goalDaysLeft(int count);

  /// No description provided for @goalTitle.
  ///
  /// In es, this message translates to:
  /// **'Meta'**
  String get goalTitle;

  /// No description provided for @validationGoalDays.
  ///
  /// In es, this message translates to:
  /// **'Escribe los días (1 a 3650).'**
  String get validationGoalDays;

  /// No description provided for @validationGoalDates.
  ///
  /// In es, this message translates to:
  /// **'Elige las fechas de inicio y fin.'**
  String get validationGoalDates;

  /// No description provided for @validationGoalRange.
  ///
  /// In es, this message translates to:
  /// **'El fin debe ser igual o posterior al inicio.'**
  String get validationGoalRange;

  /// No description provided for @pickDate.
  ///
  /// In es, this message translates to:
  /// **'Elegir fecha'**
  String get pickDate;

  /// No description provided for @activeDays.
  ///
  /// In es, this message translates to:
  /// **'Días activos'**
  String get activeDays;

  /// No description provided for @activeDaysHint.
  ///
  /// In es, this message translates to:
  /// **'Solo estos días cuentan; los demás no rompen la racha.'**
  String get activeDaysHint;

  /// No description provided for @inactiveDayHint.
  ///
  /// In es, this message translates to:
  /// **'Ese día no está activo para este hábito. Cambia los días en Editar para marcarlo.'**
  String get inactiveDayHint;

  /// No description provided for @notToday.
  ///
  /// In es, this message translates to:
  /// **'Hoy no toca'**
  String get notToday;

  /// No description provided for @habitSince.
  ///
  /// In es, this message translates to:
  /// **'Desde el {date}'**
  String habitSince(String date);

  /// No description provided for @goalPeriodFrom.
  ///
  /// In es, this message translates to:
  /// **'Desde el {date}'**
  String goalPeriodFrom(String date);

  /// No description provided for @goalPeriodRange.
  ///
  /// In es, this message translates to:
  /// **'Del {start} al {end}'**
  String goalPeriodRange(String start, String end);

  /// No description provided for @goalRemaining.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{Falta 1 día} other{Faltan {count} días}}'**
  String goalRemaining(int count);

  /// No description provided for @doneToday.
  ///
  /// In es, this message translates to:
  /// **'Cumplidos hoy'**
  String get doneToday;

  /// No description provided for @bestStreak.
  ///
  /// In es, this message translates to:
  /// **'Mejor racha'**
  String get bestStreak;

  /// No description provided for @streakLabel.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{día de racha} other{días de racha}}'**
  String streakLabel(int count);

  /// No description provided for @welcome.
  ///
  /// In es, this message translates to:
  /// **'Bienvenido'**
  String get welcome;

  /// No description provided for @haveAccountQuestion.
  ///
  /// In es, this message translates to:
  /// **'¿Ya tienes cuenta?'**
  String get haveAccountQuestion;

  /// No description provided for @noAccountQuestion.
  ///
  /// In es, this message translates to:
  /// **'¿No tienes cuenta?'**
  String get noAccountQuestion;

  /// No description provided for @welcomeSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Marca cada día, mira crecer tus rayitas y construye hábitos que duran.'**
  String get welcomeSubtitle;

  /// No description provided for @viewList.
  ///
  /// In es, this message translates to:
  /// **'Vista de lista'**
  String get viewList;

  /// No description provided for @viewWide.
  ///
  /// In es, this message translates to:
  /// **'Vista de tarjetas anchas'**
  String get viewWide;

  /// No description provided for @viewCompact.
  ///
  /// In es, this message translates to:
  /// **'Vista de tarjetas bajas'**
  String get viewCompact;

  /// No description provided for @notebookTitle.
  ///
  /// In es, this message translates to:
  /// **'Cuaderno'**
  String get notebookTitle;

  /// No description provided for @notebookMore.
  ///
  /// In es, this message translates to:
  /// **'Ver todos los meses'**
  String get notebookMore;

  /// No description provided for @notebookLess.
  ///
  /// In es, this message translates to:
  /// **'Ver menos'**
  String get notebookLess;

  /// No description provided for @inviteCode.
  ///
  /// In es, this message translates to:
  /// **'Código de invitación'**
  String get inviteCode;

  /// No description provided for @validationInviteCode.
  ///
  /// In es, this message translates to:
  /// **'Escribe el código de invitación.'**
  String get validationInviteCode;

  /// No description provided for @continueWithGoogle.
  ///
  /// In es, this message translates to:
  /// **'Continuar con Google'**
  String get continueWithGoogle;

  /// No description provided for @orDivider.
  ///
  /// In es, this message translates to:
  /// **'o'**
  String get orDivider;

  /// No description provided for @googleInviteBody.
  ///
  /// In es, this message translates to:
  /// **'Para crear tu cuenta con Google necesitas un código de invitación.'**
  String get googleInviteBody;

  /// No description provided for @continueLabel.
  ///
  /// In es, this message translates to:
  /// **'Continuar'**
  String get continueLabel;

  /// No description provided for @googleFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo iniciar sesión con Google.'**
  String get googleFailed;

  /// No description provided for @goalRestartFromStreak.
  ///
  /// In es, this message translates to:
  /// **'Contar desde el inicio de mi racha actual'**
  String get goalRestartFromStreak;

  /// No description provided for @account.
  ///
  /// In es, this message translates to:
  /// **'Cuenta'**
  String get account;

  /// No description provided for @deleteAccount.
  ///
  /// In es, this message translates to:
  /// **'Eliminar cuenta'**
  String get deleteAccount;

  /// No description provided for @deleteAccountTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Eliminar tu cuenta?'**
  String get deleteAccountTitle;

  /// No description provided for @deleteAccountBody.
  ///
  /// In es, this message translates to:
  /// **'Se borrarán para siempre tu cuenta, tus hábitos y todas tus marcas. No se puede deshacer.'**
  String get deleteAccountBody;

  /// No description provided for @deleteAccountConfirm.
  ///
  /// In es, this message translates to:
  /// **'Escribe tu correo ({email}) para confirmar'**
  String deleteAccountConfirm(String email);

  /// No description provided for @deleteAccountButton.
  ///
  /// In es, this message translates to:
  /// **'Eliminar para siempre'**
  String get deleteAccountButton;

  /// No description provided for @accountDeleted.
  ///
  /// In es, this message translates to:
  /// **'Tu cuenta fue eliminada.'**
  String get accountDeleted;

  /// No description provided for @dangerZone.
  ///
  /// In es, this message translates to:
  /// **'Zona de peligro'**
  String get dangerZone;

  /// No description provided for @deleteAccountHint.
  ///
  /// In es, this message translates to:
  /// **'Elimina tu cuenta y todos tus datos para siempre.'**
  String get deleteAccountHint;

  /// No description provided for @memberSince.
  ///
  /// In es, this message translates to:
  /// **'Miembro desde {date}'**
  String memberSince(String date);

  /// No description provided for @habitsCount.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =0{Sin hábitos} =1{1 hábito} other{{count} hábitos}}'**
  String habitsCount(int count);

  /// No description provided for @privacyPolicy.
  ///
  /// In es, this message translates to:
  /// **'Política de privacidad'**
  String get privacyPolicy;

  /// No description provided for @termsOfService.
  ///
  /// In es, this message translates to:
  /// **'Términos y condiciones'**
  String get termsOfService;

  /// No description provided for @contactSupport.
  ///
  /// In es, this message translates to:
  /// **'Contacto y ayuda'**
  String get contactSupport;

  /// No description provided for @couldNotOpenLink.
  ///
  /// In es, this message translates to:
  /// **'No se pudo abrir el enlace.'**
  String get couldNotOpenLink;

  /// No description provided for @verifiedEmail.
  ///
  /// In es, this message translates to:
  /// **'Correo verificado'**
  String get verifiedEmail;

  /// No description provided for @legalSection.
  ///
  /// In es, this message translates to:
  /// **'Información'**
  String get legalSection;

  /// No description provided for @adsSection.
  ///
  /// In es, this message translates to:
  /// **'Anuncios'**
  String get adsSection;

  /// No description provided for @removeAds.
  ///
  /// In es, this message translates to:
  /// **'Quitar anuncios'**
  String get removeAds;

  /// No description provided for @removeAdsHint.
  ///
  /// In es, this message translates to:
  /// **'Pago único. Sin banners, para siempre y en todos tus dispositivos Android.'**
  String get removeAdsHint;

  /// No description provided for @adsRemovedThanks.
  ///
  /// In es, this message translates to:
  /// **'Los anuncios están desactivados. ¡Gracias por apoyar Rayita!'**
  String get adsRemovedThanks;

  /// No description provided for @restorePurchase.
  ///
  /// In es, this message translates to:
  /// **'Restaurar compra'**
  String get restorePurchase;

  /// No description provided for @purchaseUnavailable.
  ///
  /// In es, this message translates to:
  /// **'La compra aún no está disponible. Inténtalo más tarde.'**
  String get purchaseUnavailable;

  /// No description provided for @purchaseDone.
  ///
  /// In es, this message translates to:
  /// **'Listo, ya no verás anuncios. ¡Gracias!'**
  String get purchaseDone;

  /// No description provided for @purchaseRestored.
  ///
  /// In es, this message translates to:
  /// **'Compra restaurada. Anuncios desactivados.'**
  String get purchaseRestored;

  /// No description provided for @purchaseNothingToRestore.
  ///
  /// In es, this message translates to:
  /// **'No encontramos una compra para restaurar.'**
  String get purchaseNothingToRestore;

  /// No description provided for @purchaseFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo completar la compra.'**
  String get purchaseFailed;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
