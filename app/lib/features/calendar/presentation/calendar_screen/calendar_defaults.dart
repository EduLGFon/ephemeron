// Adaptive default view for a fresh install.
//
// The shell restores `calendar.view` before the calendar builds. When that key
// was never persisted the restore falls back to the month view, which is the
// wrong entry point on a phone: a single day is the useful first screen there
// while a wide layout benefits from a full week.
import '../../../../core/design/layout.dart';
import '../../application/calendar_state.dart';

/// Mirrors the private `SettingsRepository` preference key.
const String calendarViewPreferenceKey = 'calendar.view';

/// True when [current] is the untouched restored default that a fresh install
/// may replace. An explicit restored view, or a touched day count, always wins.
bool canApplyFreshInstallDefault(CalendarWindow current) =>
    current.view == CalendarViewKind.month && current.dayCount == 1;

/// Fresh-install window for [layout], or null when [current] is not the
/// untouched restored default.
///
/// Only the default month window is replaced: if the shell (or a test)
/// restored an explicit view, that choice wins even when the key is absent.
CalendarWindow? freshInstallCalendarWindow(
  AppLayout layout,
  CalendarWindow current,
) {
  if (!canApplyFreshInstallDefault(current)) return null;
  // Medium layouts behave like a large phone: one day is a better default
  // than a week squeezed next to a navigation rail.
  final week = layout == AppLayout.expanded;
  return CalendarWindow(
    anchor: current.anchor,
    view: week ? CalendarViewKind.multiDay : CalendarViewKind.day,
    dayCount: week ? 7 : 1,
  );
}
