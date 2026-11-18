// Calendar view switcher. Every existing view stays reachable: month, agenda,
// year and the 3/4/5/7-day timelines.
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ui/app_feedback.dart';
import '../../application/calendar_providers.dart';
import '../../application/calendar_state.dart';
import '../calendar_strings.dart';

class CalendarViewChoice {
  const CalendarViewChoice(this.view, {this.dayCount = 1});

  final CalendarViewKind view;
  final int dayCount;

  String label(CalendarStrings strings) => switch (view) {
    CalendarViewKind.month => strings.monthView,
    CalendarViewKind.multiDay => strings.multiDayView(dayCount),
    CalendarViewKind.day => strings.dayView,
    CalendarViewKind.agenda => strings.agendaView,
    CalendarViewKind.year => strings.yearView,
  };

  bool isSelected(CalendarWindow window) => isCalendarViewChoiceSelected(
    view: view,
    dayCount: dayCount,
    window: window,
  );
}

const List<CalendarViewChoice> calendarViewChoices = <CalendarViewChoice>[
  CalendarViewChoice(CalendarViewKind.month),
  CalendarViewChoice(CalendarViewKind.multiDay, dayCount: 3),
  CalendarViewChoice(CalendarViewKind.multiDay, dayCount: 4),
  CalendarViewChoice(CalendarViewKind.multiDay, dayCount: 5),
  CalendarViewChoice(CalendarViewKind.multiDay, dayCount: 7),
  CalendarViewChoice(CalendarViewKind.day),
  CalendarViewChoice(CalendarViewKind.agenda),
  CalendarViewChoice(CalendarViewKind.year),
];

/// True when [window] already shows the view represented by [view]/[dayCount].
bool isCalendarViewChoiceSelected({
  required CalendarViewKind view,
  required int dayCount,
  required CalendarWindow window,
}) {
  if (window.view != view) return false;
  if (view == CalendarViewKind.multiDay) return window.dayCount == dayCount;
  return true;
}

class CalendarViewMenu extends ConsumerWidget {
  const CalendarViewMenu({super.key, required this.window});

  final CalendarWindow window;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = CalendarStrings.of(context);
    return PopupMenuButton<CalendarViewChoice>(
      key: const Key('calendar-view-menu'),
      tooltip: strings.view,
      icon: const Icon(Icons.view_agenda_outlined),
      onSelected: (choice) {
        AppFeedback.selection();
        ref
            .read(calendarStateProvider.notifier)
            .setView(choice.view, dayCount: choice.dayCount);
      },
      itemBuilder: (context) => <PopupMenuEntry<CalendarViewChoice>>[
        for (final choice in calendarViewChoices)
          CheckedPopupMenuItem<CalendarViewChoice>(
            value: choice,
            checked: choice.isSelected(window),
            child: Text(choice.label(strings)),
          ),
      ],
    );
  }
}
