// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Rayita';

  @override
  String get signIn => 'Sign in';

  @override
  String get createYourAccount => 'Create your account';

  @override
  String get name => 'Name';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get validationName => 'Enter your name.';

  @override
  String get validationEmail => 'Enter a valid email.';

  @override
  String get validationPassword => 'At least 8 characters.';

  @override
  String get register => 'Sign up';

  @override
  String get enter => 'Sign in';

  @override
  String get haveAccount => 'I already have an account';

  @override
  String get createAccount => 'Create an account';

  @override
  String get myHabits => 'My habits';

  @override
  String get logout => 'Sign out';

  @override
  String get newHabit => 'New habit';

  @override
  String get noHabits =>
      'You don\'t have any habits yet.\nCreate the first one with the button below.';

  @override
  String get retry => 'Retry';

  @override
  String get editHabit => 'Edit habit';

  @override
  String get deleteHabit => 'Delete habit';

  @override
  String get deleteHabitTitle => 'Delete habit?';

  @override
  String deleteHabitBody(String name) {
    return '\"$name\" will be deleted along with all its marks.';
  }

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get save => 'Save';

  @override
  String get create => 'Create';

  @override
  String get habitNameLabel => 'Name (e.g. Go to the gym)';

  @override
  String get color => 'Color';

  @override
  String get iconOptional => 'Icon (optional)';

  @override
  String iconSemantic(String name) {
    return 'Icon $name';
  }

  @override
  String get previousMonth => 'Previous month';

  @override
  String get nextMonth => 'Next month';

  @override
  String get tapDayHint => 'Tap a day to mark it: done, partial or none.';

  @override
  String get currentStreak => 'Current streak';

  @override
  String get longestStreak => 'Longest streak';

  @override
  String get thisMonth => 'This month';

  @override
  String get total => 'Total';

  @override
  String doneCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count done',
      one: '1 done',
    );
    return '$_temp0';
  }

  @override
  String partialCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count partial',
      one: '1 partial',
    );
    return '$_temp0';
  }

  @override
  String get noMarks => 'No marks';

  @override
  String marksCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count marks',
      one: '1 mark',
    );
    return '$_temp0';
  }

  @override
  String get statusNone => 'no mark';

  @override
  String get statusDone => 'done';

  @override
  String get statusPartial => 'partial';

  @override
  String get weekdayInitials => 'M,T,W,T,F,S,S';

  @override
  String get errorConnection => 'Could not connect to the server.';

  @override
  String get errorUnexpected => 'An unexpected error occurred.';

  @override
  String get language => 'Language';

  @override
  String get languageSystem => 'System';

  @override
  String get tagline => 'Build habits, one day at a time.';

  @override
  String get todayLabel => 'Today';

  @override
  String todayProgress(int done, int total) {
    return '$done of $total done';
  }

  @override
  String streakDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String get markToday => 'Mark today';

  @override
  String get unmarkToday => 'Remove today\'s mark';

  @override
  String doneWord(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'done',
      one: 'done',
    );
    return '$_temp0';
  }

  @override
  String get confirmPassword => 'Confirm password';

  @override
  String get validationPasswordMatch => 'Passwords don\'t match.';

  @override
  String get verifyTitle => 'Verify your email';

  @override
  String verifySubtitle(String email) {
    return 'We sent a 6-digit code to $email.';
  }

  @override
  String get codeLabel => 'Verification code';

  @override
  String get validationCode => 'Enter the 6-digit code.';

  @override
  String get verifyButton => 'Verify';

  @override
  String get resendCode => 'Resend code';

  @override
  String resendIn(int seconds) {
    return 'Resend in $seconds s';
  }

  @override
  String get codeSent => 'We sent you a new code.';

  @override
  String get useAnotherAccount => 'Use another account';

  @override
  String get checkSpam => 'If you don\'t see it, check your spam folder.';

  @override
  String get goalSection => 'Goal (optional)';

  @override
  String get goalEnable => 'Set a goal';

  @override
  String get goalByDays => 'By days';

  @override
  String get goalByDates => 'By dates';

  @override
  String get goalDaysLabel => 'Number of days';

  @override
  String get goalStartLabel => 'Start';

  @override
  String get goalEndLabel => 'End';

  @override
  String get goalOnFail => 'If you miss a day';

  @override
  String get goalReset => 'Restart';

  @override
  String get goalAccumulate => 'Keep counting';

  @override
  String get goalResetHint => 'The count starts over from 0.';

  @override
  String get goalAccumulateHint =>
      'Done days count, even if they aren\'t consecutive.';

  @override
  String goalProgress(int progress, int target) {
    return '$progress / $target days';
  }

  @override
  String get goalAchieved => 'Goal achieved! 🎉';

  @override
  String get goalFailed => 'Goal not reached';

  @override
  String goalDaysLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days left',
      one: '1 day left',
      zero: 'Last day',
    );
    return '$_temp0';
  }

  @override
  String get goalTitle => 'Goal';

  @override
  String get validationGoalDays => 'Enter the days (1 to 3650).';

  @override
  String get validationGoalDates => 'Pick the start and end dates.';

  @override
  String get validationGoalRange => 'The end must be on or after the start.';

  @override
  String get pickDate => 'Pick a date';

  @override
  String get activeDays => 'Active days';

  @override
  String get activeDaysHint =>
      'Only these days count; the others don\'t break the streak.';

  @override
  String get inactiveDayHint =>
      'That day isn\'t active for this habit. Change its days in Edit to mark it.';

  @override
  String get notToday => 'Not today';

  @override
  String habitSince(String date) {
    return 'Since $date';
  }

  @override
  String goalPeriodFrom(String date) {
    return 'Since $date';
  }

  @override
  String goalPeriodRange(String start, String end) {
    return '$start to $end';
  }

  @override
  String goalRemaining(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days to go',
      one: '1 day to go',
    );
    return '$_temp0';
  }

  @override
  String get doneToday => 'Done today';

  @override
  String get bestStreak => 'Best streak';

  @override
  String streakLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'day streak',
      one: 'day streak',
    );
    return '$_temp0';
  }

  @override
  String get welcome => 'Welcome';

  @override
  String get haveAccountQuestion => 'Already have an account?';

  @override
  String get noAccountQuestion => 'Don\'t have an account?';

  @override
  String get welcomeSubtitle =>
      'Check off each day, watch your tally marks grow and build habits that last.';

  @override
  String get viewCards => 'Cards view';

  @override
  String get viewList => 'List view';

  @override
  String get inviteCode => 'Invitation code';

  @override
  String get validationInviteCode => 'Enter the invitation code.';

  @override
  String get continueWithGoogle => 'Continue with Google';

  @override
  String get orDivider => 'or';

  @override
  String get googleInviteBody =>
      'To create your account with Google you need an invitation code.';

  @override
  String get continueLabel => 'Continue';

  @override
  String get googleFailed => 'Couldn\'t sign in with Google.';

  @override
  String get goalRestartFromStreak =>
      'Count from the start of my current streak';

  @override
  String get account => 'Account';

  @override
  String get deleteAccount => 'Delete account';

  @override
  String get deleteAccountTitle => 'Delete your account?';

  @override
  String get deleteAccountBody =>
      'Your account, habits and all your marks will be permanently deleted. This can\'t be undone.';

  @override
  String deleteAccountConfirm(String email) {
    return 'Type your email ($email) to confirm';
  }

  @override
  String get deleteAccountButton => 'Delete forever';

  @override
  String get accountDeleted => 'Your account has been deleted.';

  @override
  String get dangerZone => 'Danger zone';

  @override
  String get deleteAccountHint =>
      'Permanently delete your account and all your data.';

  @override
  String memberSince(String date) {
    return 'Member since $date';
  }

  @override
  String habitsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count habits',
      one: '1 habit',
      zero: 'No habits',
    );
    return '$_temp0';
  }

  @override
  String get privacyPolicy => 'Privacy policy';

  @override
  String get termsOfService => 'Terms and conditions';

  @override
  String get contactSupport => 'Contact and help';

  @override
  String get couldNotOpenLink => 'Couldn\'t open the link.';

  @override
  String get verifiedEmail => 'Email verified';

  @override
  String get legalSection => 'Information';
}
