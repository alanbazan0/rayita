// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'Calendar Check';

  @override
  String get signIn => 'Inicia sesión';

  @override
  String get createYourAccount => 'Crea tu cuenta';

  @override
  String get name => 'Nombre';

  @override
  String get email => 'Correo';

  @override
  String get password => 'Contraseña';

  @override
  String get validationName => 'Escribe tu nombre.';

  @override
  String get validationEmail => 'Escribe un correo válido.';

  @override
  String get validationPassword => 'Mínimo 8 caracteres.';

  @override
  String get register => 'Registrarme';

  @override
  String get enter => 'Entrar';

  @override
  String get haveAccount => 'Ya tengo cuenta';

  @override
  String get createAccount => 'Crear una cuenta';

  @override
  String get myHabits => 'Mis hábitos';

  @override
  String get logout => 'Cerrar sesión';

  @override
  String get newHabit => 'Nuevo hábito';

  @override
  String get noHabits =>
      'Aún no tienes hábitos.\nCrea el primero con el botón de abajo.';

  @override
  String get retry => 'Reintentar';

  @override
  String get editHabit => 'Editar hábito';

  @override
  String get deleteHabit => 'Eliminar hábito';

  @override
  String get deleteHabitTitle => '¿Eliminar hábito?';

  @override
  String deleteHabitBody(String name) {
    return 'Se borrará \"$name\" junto con todas sus marcas.';
  }

  @override
  String get cancel => 'Cancelar';

  @override
  String get delete => 'Eliminar';

  @override
  String get save => 'Guardar';

  @override
  String get create => 'Crear';

  @override
  String get habitNameLabel => 'Nombre (ej. Ir al gym)';

  @override
  String get color => 'Color';

  @override
  String get iconOptional => 'Ícono (opcional)';

  @override
  String iconSemantic(String name) {
    return 'Ícono $name';
  }

  @override
  String get previousMonth => 'Mes anterior';

  @override
  String get nextMonth => 'Mes siguiente';

  @override
  String get tapDayHint =>
      'Toca un día para marcarlo: cumplido, parcial o sin marca.';

  @override
  String get currentStreak => 'Racha actual';

  @override
  String get longestStreak => 'Racha más larga';

  @override
  String get thisMonth => 'Este mes';

  @override
  String get total => 'Total';

  @override
  String doneCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cumplidos',
      one: '1 cumplido',
    );
    return '$_temp0';
  }

  @override
  String partialCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count parciales',
      one: '1 parcial',
    );
    return '$_temp0';
  }

  @override
  String get noMarks => 'Sin marcas';

  @override
  String marksCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count marcas',
      one: '1 marca',
    );
    return '$_temp0';
  }

  @override
  String get statusNone => 'sin marca';

  @override
  String get statusDone => 'cumplido';

  @override
  String get statusPartial => 'parcial';

  @override
  String get weekdayInitials => 'L,M,M,J,V,S,D';

  @override
  String get errorConnection => 'No se pudo conectar con el servidor.';

  @override
  String get errorUnexpected => 'Ocurrió un error inesperado.';

  @override
  String get language => 'Idioma';

  @override
  String get languageSystem => 'Automático';

  @override
  String get tagline => 'Construye hábitos, un día a la vez.';

  @override
  String get todayLabel => 'Hoy';

  @override
  String todayProgress(int done, int total) {
    return '$done de $total cumplidos';
  }

  @override
  String streakDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count días',
      one: '1 día',
    );
    return '$_temp0';
  }

  @override
  String get markToday => 'Marcar hoy';

  @override
  String get unmarkToday => 'Quitar la marca de hoy';

  @override
  String doneWord(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'cumplidos',
      one: 'cumplido',
    );
    return '$_temp0';
  }

  @override
  String get confirmPassword => 'Confirmar contraseña';

  @override
  String get validationPasswordMatch => 'Las contraseñas no coinciden.';

  @override
  String get verifyTitle => 'Verifica tu correo';

  @override
  String verifySubtitle(String email) {
    return 'Enviamos un código de 6 dígitos a $email.';
  }

  @override
  String get codeLabel => 'Código de verificación';

  @override
  String get validationCode => 'Escribe el código de 6 dígitos.';

  @override
  String get verifyButton => 'Verificar';

  @override
  String get resendCode => 'Reenviar código';

  @override
  String resendIn(int seconds) {
    return 'Reenviar en $seconds s';
  }

  @override
  String get codeSent => 'Te enviamos un nuevo código.';

  @override
  String get useAnotherAccount => 'Usar otra cuenta';

  @override
  String get checkSpam => 'Si no lo ves, revisa la carpeta de spam.';

  @override
  String get goalSection => 'Meta (opcional)';

  @override
  String get goalEnable => 'Definir una meta';

  @override
  String get goalByDays => 'Por días';

  @override
  String get goalByDates => 'Por fechas';

  @override
  String get goalDaysLabel => 'Número de días';

  @override
  String get goalStartLabel => 'Inicio';

  @override
  String get goalEndLabel => 'Fin';

  @override
  String get goalOnFail => 'Si fallas un día';

  @override
  String get goalReset => 'Reiniciar';

  @override
  String get goalAccumulate => 'Acumular';

  @override
  String get goalResetHint => 'El conteo vuelve a empezar desde 0.';

  @override
  String get goalAccumulateHint =>
      'Cuentan los días cumplidos, aunque no sean seguidos.';

  @override
  String goalProgress(int progress, int target) {
    return '$progress / $target días';
  }

  @override
  String get goalAchieved => '¡Meta lograda! 🎉';

  @override
  String get goalFailed => 'Meta no lograda';

  @override
  String goalDaysLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Quedan $count días',
      one: 'Queda 1 día',
      zero: 'Último día',
    );
    return '$_temp0';
  }

  @override
  String get goalTitle => 'Meta';

  @override
  String get validationGoalDays => 'Escribe los días (1 a 3650).';

  @override
  String get validationGoalDates => 'Elige las fechas de inicio y fin.';

  @override
  String get validationGoalRange =>
      'El fin debe ser igual o posterior al inicio.';

  @override
  String get pickDate => 'Elegir fecha';

  @override
  String get activeDays => 'Días activos';

  @override
  String get activeDaysHint =>
      'Solo estos días cuentan; los demás no rompen la racha.';

  @override
  String get inactiveDayHint =>
      'Ese día no está activo para este hábito. Cambia los días en Editar para marcarlo.';

  @override
  String get notToday => 'Hoy no toca';

  @override
  String habitSince(String date) {
    return 'Desde el $date';
  }

  @override
  String goalPeriodFrom(String date) {
    return 'Desde el $date';
  }

  @override
  String goalPeriodRange(String start, String end) {
    return 'Del $start al $end';
  }

  @override
  String goalRemaining(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Faltan $count días',
      one: 'Falta 1 día',
    );
    return '$_temp0';
  }

  @override
  String get doneToday => 'Cumplidos hoy';

  @override
  String get bestStreak => 'Mejor racha';

  @override
  String streakLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'días de racha',
      one: 'día de racha',
    );
    return '$_temp0';
  }

  @override
  String get welcome => 'Bienvenido';

  @override
  String get haveAccountQuestion => '¿Ya tienes cuenta?';

  @override
  String get noAccountQuestion => '¿No tienes cuenta?';

  @override
  String get welcomeSubtitle =>
      'Marca cada día, mira crecer tus rayitas y construye hábitos que duran.';
}
