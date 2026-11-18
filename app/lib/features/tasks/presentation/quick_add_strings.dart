// User-visible strings for Quick Add. English only for now; the locale lookup
// is the single place a future translation table plugs in (see the
// localization contract in the UI rebirth plan).
import 'package:material_ui/material_ui.dart';

class QuickAddStrings {
  const QuickAddStrings._();

  static const Map<String, QuickAddStrings> _byLanguage =
      <String, QuickAddStrings>{};

  static QuickAddStrings of(BuildContext context) {
    final language = Localizations.localeOf(context).languageCode;
    return _byLanguage[language] ?? const QuickAddStrings._();
  }

  String get title => 'Quick add';
  String get close => 'Close quick add';
  String get sectionType => 'Type';
  String get sectionDate => 'Date';
  String get sectionList => 'List';
  String get sectionPriority => 'Priority';

  String get typeTask => 'Task';
  String get typeEvent => 'Event';
  String get typeHabit => 'Habit';
  String get typeCountdown => 'Countdown';

  String get today => 'Today';
  String get tomorrow => 'Tomorrow';
  String get pickDate => 'Pick';
  String get pickDateHelp => 'Pick a date';

  String get priorityNone => 'None';
  String priorityLabel(int visual) => 'P$visual';

  String get addAnother => 'Add another';
  String get addTask => 'Add task';
  String get addEvent => 'Add event';
  String get addHabit => 'Add habit';
  String get addCountdown => 'Add countdown';

  String get fieldHintTask => 'Buy milk #tag ~list -p1 tomorrow 9h';
  String get fieldHintEvent => 'Dentist tomorrow 14h';
  String get fieldHintHabit => 'Meditate every day';
  String get fieldHintCountdown => 'Trip in 30 days';

  String get previewAddTitle => 'Add a title';
  String get dailyFromToday => 'Daily from today';
  String get countdownDefault => 'In 30 days';
  String countdownInDays(int days) => days == 1 ? 'In 1 day' : 'In $days days';
  String get repeats => 'Repeats';
  String timeRange(String start, String end) => '$start - $end';

  String get saveFailed => 'Could not add. Try again.';
  String get taskAdded => 'Task added';
}
