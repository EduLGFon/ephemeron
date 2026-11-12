// Agenda: list grouped by day over the loaded (cache) window, filtered to
// the visible agenda range. Habit entries appear above events for each day.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/time/device_date_format.dart';
import '../../../core/time/time.dart';
import '../../../core/ui/empty_state.dart';
import '../../../data/drift/app_database.dart';
import '../../../domain/habits/habit_calendar_entry.dart';
import '../application/calendar_providers.dart';
import '../application/calendar_state.dart';
import 'agenda_event_tile.dart';
import 'event_details_sheet.dart';
import 'event_editor_sheet.dart';
import 'task_action_sheet.dart';
import 'habit_calendar_marker.dart';

class AgendaView extends ConsumerStatefulWidget {
  const AgendaView({super.key});

  @override
  ConsumerState<AgendaView> createState() => _AgendaViewState();
}

class _AgendaViewState extends ConsumerState<AgendaView> {
  @override
  Widget build(BuildContext context) {
    final window = ref.watch(calendarStateProvider);
    final range = ref.watch(calendarCacheRangeProvider);
    final built = ref.watch(calendarBuiltRangeProvider);
    final ready = built == range;
    // Hold the list back until CalendarScreen materializes this range, so a
    // switch never flashes rows from the previous range or a partial set.
    final occAsync = ready ? ref.watch(windowOccurrencesProvider(range)) : null;
    final habitAsync = ready
        ? ref.watch(calendarHabitEntriesProvider(range))
        : null;
    if (occAsync == null || habitAsync == null) {
      return const Center(child: CircularProgressIndicator());
    }
    // Both streams gate the agenda; a habit failure must not render as an
    // empty day list either.
    if (occAsync.hasError || habitAsync.hasError) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Could not load agenda.'),
            OutlinedButton(
              onPressed: () {
                ref.invalidate(windowOccurrencesProvider(range));
                ref.invalidate(calendarHabitEntriesProvider(range));
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    final occs = occAsync.value;
    final habits = habitAsync.value;
    if (occs == null || habits == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return _body(
      context,
      _visible(window, occs),
      _visibleHabits(window, habits),
      window.anchor,
    );
  }

  List<OccurrenceCacheData> _visible(
    CalendarWindow window,
    List<OccurrenceCacheData> occs,
  ) {
    final (fromKey, toKey) = _visibleKeys(window);
    return [
      for (final o in occs)
        if (o.dayKey.compareTo(fromKey) >= 0 && o.dayKey.compareTo(toKey) <= 0)
          o,
    ];
  }

  List<HabitCalendarEntry> _visibleHabits(
    CalendarWindow window,
    List<HabitCalendarEntry> habits,
  ) {
    final (fromKey, toKey) = _visibleKeys(window);
    return [
      for (final h in habits)
        if (h.dayKey.compareTo(fromKey) >= 0 && h.dayKey.compareTo(toKey) <= 0)
          h,
    ];
  }

  (String, String) _visibleKeys(CalendarWindow window) {
    final visible = window.visibleRange;
    return (
      dateKey(visible.fromUtc),
      dateKey(visible.toUtc.subtract(const Duration(milliseconds: 1))),
    );
  }

  Widget _body(
    BuildContext context,
    List<OccurrenceCacheData> occs,
    List<HabitCalendarEntry> habits,
    DateTime anchor,
  ) {
    if (occs.isEmpty && habits.isEmpty) {
      return EmptyState(
        icon: Icons.event_available_outlined,
        title: 'Nothing scheduled',
        subtitle: 'Your agenda is clear.',
        actionLabel: 'Add event',
        onAction: () =>
            showEventEditor(context, initialDay: anchor, initialHour: 9),
      );
    }
    final occByDay = <String, List<OccurrenceCacheData>>{};
    for (final o in occs) {
      occByDay.putIfAbsent(o.dayKey, () => []).add(o);
    }
    final habitByDay = <String, List<HabitCalendarEntry>>{};
    for (final h in habits) {
      habitByDay.putIfAbsent(h.dayKey, () => []).add(h);
    }
    final days = {...occByDay.keys, ...habitByDay.keys}.toList()..sort();
    final today = DateTime.now();
    final items = <Widget>[];
    for (final d in days) {
      final day = DateTime.tryParse(d);
      final label = day == null
          ? d
          : agendaDayLabel(
              day,
              today: today,
              weekdayShort: DeviceDateFormat.weekday(context, day),
              monthShort: DeviceDateFormat.shortMonthName(context, day.month),
            );
      items.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Semantics(
            header: true,
            child: Text(label, style: Theme.of(context).textTheme.titleSmall),
          ),
        ),
      );
      final dayHabits = habitByDay[d] ?? const <HabitCalendarEntry>[];
      dayHabits.sort((a, b) => a.habitName.compareTo(b.habitName));
      for (final h in dayHabits) {
        items.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            child: HabitCalendarMarker(
              key: ValueKey('agenda-habit-${h.habitId}-${h.dayKey}'),
              entry: h,
            ),
          ),
        );
      }
      for (final o in occByDay[d] ?? const <OccurrenceCacheData>[]) {
        items.add(
          AgendaEventTile(
            key: ValueKey('agenda-${o.id}'),
            occurrence: o,
            onTap: () {
              if (o.sourceType == 'task') {
                showTaskActionSheet(
                  context,
                  taskId: o.eventId,
                  occurrenceDate: o.dayKey,
                );
              } else {
                showEventDetails(
                  context,
                  o.eventId,
                  occurrenceStartMs: o.startUtc,
                );
              }
            },
          ),
        );
      }
    }
    return RepaintBoundary(
      child: ListView.builder(
        itemCount: items.length,
        itemBuilder: (_, i) => items[i],
      ),
    );
  }
}

String agendaDayKey(DateTime d) => dateKey(d);

/// Human-friendly agenda group header.
///
/// [weekdayShort] and [monthShort] are passed in so the label stays pure and
/// unit testable; the widget resolves them with `DeviceDateFormat`.
String agendaDayLabel(
  DateTime day, {
  required DateTime today,
  required String weekdayShort,
  required String monthShort,
}) {
  final date = DateTime(day.year, day.month, day.day);
  final now = DateTime(today.year, today.month, today.day);
  final dateLabel = date.year == now.year
      ? '$monthShort ${date.day}'
      : '$monthShort ${date.day}, ${date.year}';
  final diff = date.difference(now).inDays;
  if (diff == 0) return 'Today, $dateLabel';
  if (diff == 1) return 'Tomorrow, $dateLabel';
  return '$weekdayShort, $dateLabel';
}
