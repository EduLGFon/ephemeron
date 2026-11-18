// Calendar screen strings. Each feature owns its small strings class so
// localization can grow per screen without churning the shared ARB files.
// English is the only locale for now.
import 'package:material_ui/material_ui.dart';

class CalendarStrings {
  const CalendarStrings._();

  /// Reads the active locale so adding translations only changes this class.
  static CalendarStrings of(BuildContext context) {
    final _ = Localizations.localeOf(context);
    return const CalendarStrings._();
  }

  String get title => 'Calendar';
  String get today => 'Today';
  String get previous => 'Previous';
  String get next => 'Next';
  String get view => 'View';
  String get calendarSettings => 'Calendar settings';
  String get syncNow => 'Sync now';
  String get newEvent => 'New event';
  String get loadErrorTitle => 'Could not load calendar';
  String get loadErrorMessage => 'The calendar range failed to load.';

  String get monthView => 'Month';
  String get dayView => 'Day';
  String get agendaView => 'Agenda';
  String get yearView => 'Year';

  String multiDayView(int days) => days == 1 ? '1 day' : '$days days';
}
