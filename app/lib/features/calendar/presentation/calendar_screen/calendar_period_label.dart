// Human period label under the Calendar title.
//
// Month and year views show the period they scroll through; day and multi-day
// views show the exact visible dates.
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/time/device_date_format.dart';
import '../../application/calendar_state.dart';

String calendarPeriodLabel(BuildContext context, CalendarWindow window) {
  final locale = DeviceDateFormat.locale(context);
  final anchor = window.anchor;
  return switch (window.view) {
    CalendarViewKind.month ||
    CalendarViewKind.agenda => DateFormat.yMMM(locale).format(anchor),
    CalendarViewKind.year => DateFormat.y(locale).format(anchor),
    CalendarViewKind.day => DateFormat.yMMMMEEEEd(locale).format(anchor),
    CalendarViewKind.multiDay => _rangeLabel(locale, anchor, window.dayCount),
  };
}

String _rangeLabel(String locale, DateTime anchor, int dayCount) {
  final start = DateTime(anchor.year, anchor.month, anchor.day);
  final end = start.add(Duration(days: dayCount > 0 ? dayCount - 1 : 0));
  if (start.year != end.year) {
    return '${DateFormat.yMMMd(locale).format(start)} – '
        '${DateFormat.yMMMd(locale).format(end)}';
  }
  final from = DateFormat.MMMd(locale).format(start);
  final to = start.month == end.month
      ? DateFormat.d(locale).format(end)
      : DateFormat.MMMd(locale).format(end);
  return '$from – $to, ${DateFormat.y(locale).format(end)}';
}
