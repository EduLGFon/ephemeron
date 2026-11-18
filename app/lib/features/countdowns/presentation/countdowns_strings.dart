// User-visible strings for the countdowns screen. English only for now.
import 'package:material_ui/material_ui.dart';

class CountdownsStrings {
  const CountdownsStrings(this.locale);

  final Locale locale;

  static CountdownsStrings of(BuildContext context) =>
      CountdownsStrings(Localizations.localeOf(context));

  String get title => 'Countdowns';
  String get addCountdown => 'Add countdown';
  String get emptyTitle => 'No countdowns yet.';
  String get emptyMessage =>
      'Track birthdays, trips and anything worth waiting for.';
  String get addAction => 'Add countdown';
  String get loadError => 'Could not load countdowns.';
  String get retry => 'Retry';
  String get upcoming => 'Upcoming';
  String get passed => 'Passed';
  String get noDate => 'No date';
  String get noDateLabel => 'No date set';
  String get moreOptions => 'More options';
  String get edit => 'Edit';
  String get delete => 'Delete';
  String get deletedMessage => 'Countdown deleted.';
  String get undo => 'Undo';
  String get linkedEvent => 'Event';
  String get linkedTask => 'Task';
  String get linkedHabit => 'Habit';
  String turnsAge(int age) => 'Turns $age';
  String count(int value) => value == 1 ? '1 countdown' : '$value countdowns';
  String dateLabel(String date, String? detail) =>
      detail == null ? date : '$detail · $date';
}
