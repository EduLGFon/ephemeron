import 'package:material_ui/material_ui.dart';

/// Locale-aware time label for the Stream surface.
///
/// Uses the platform locale via [MaterialLocalizations] and honours the
/// [MediaQueryData.alwaysUse24HourFormat] preference. No new package.
String formatStreamTimeOfDay(BuildContext context, DateTime dateTime) {
  final localizations = MaterialLocalizations.of(context);
  final timeOfDay = TimeOfDay.fromDateTime(dateTime);
  final use24Hour = MediaQuery.alwaysUse24HourFormatOf(context);
  return localizations.formatTimeOfDay(
    timeOfDay,
    alwaysUse24HourFormat: use24Hour,
  );
}
