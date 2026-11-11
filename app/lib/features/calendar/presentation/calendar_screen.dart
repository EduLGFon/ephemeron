// Calendar screen: view switcher, navigation, rebuild-on-window-change.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ephemeron/core/time/device_date_format.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/session/session_restore.dart';
import '../../../core/ui/app_feedback.dart';
import '../../settings/application/settings_providers.dart';
import '../../sync/presentation/sync_title.dart';
import '../application/calendar_providers.dart';
import '../../tasks/application/tasks_providers.dart';
import '../application/calendar_state.dart';
import 'agenda_view.dart';
import 'calendar_settings_screen.dart';
import 'calendar_swipe.dart';
import 'event_editor_sheet.dart';
import 'month_view.dart';
import 'timeline/timeline_view.dart';
import 'year_view.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  CalendarRange? _builtRange;
  CalendarWindow? _persisted;
  bool _rebuilding = false;
  bool _rebuildAgain = false;
  bool _disposed = false;
  Timer? _restoreFallback;

  @override
  void initState() {
    super.initState();
    _scheduleRebuild();
    // Safety net: if session restore never reports completion, build the
    // default window instead of leaving the calendar empty.
    _restoreFallback = Timer(const Duration(seconds: 2), () {
      if (_disposed || !mounted) return;
      if (ref.read(initialRestoreDoneProvider)) return;
      ref.read(initialRestoreDoneProvider.notifier).markDone();
      _maybeRebuild();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _restoreFallback?.cancel();
    super.dispose();
  }

  void _scheduleRebuild() {
    if (_disposed) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed || !mounted) return;
      _maybeRebuild();
    });
  }

  Future<void> _maybeRebuild() async {
    if (_disposed || !mounted || _rebuilding) {
      if (_rebuilding) _rebuildAgain = true;
      return;
    }
    // Wait for session restore so the default window is not materialized
    // immediately before the saved view/anchor is applied.
    if (!ref.read(initialRestoreDoneProvider)) return;

    final window = ref.read(calendarStateProvider);
    // Persist every window change (including day selection in the month
    // view) without forcing a cache rebuild for it.
    if (_persisted != window) {
      _persisted = window;
      Future.microtask(() async {
        try {
          if (_disposed || !mounted) return;
          await persistCalendarView(ref);
        } catch (_) {}
      });
    }

    _rebuilding = true;
    var didRebuild = false;
    try {
      do {
        _rebuildAgain = false;
        if (_disposed || !mounted) break;
        final dirty = ref.read(occurrenceDirtyProvider);
        final range = ref.read(calendarCacheRangeProvider);
        if (!dirty && _builtRange == range) break;
        final building = ref.read(calendarCacheBuildingProvider.notifier);
        building.set(true);
        try {
          await ref
              .read(occurrenceRepositoryProvider)
              .rebuildWindow(
                windowStartUtc: range.fromUtc,
                windowEndUtc: range.toUtc,
              );
          // The screen may have been replaced while the cache was building.
          if (_disposed || !mounted) return;
          _builtRange = range;
          didRebuild = true;
          if (ref.read(occurrenceDirtyProvider)) {
            ref.read(occurrenceDirtyProvider.notifier).clear();
          }
        } catch (_) {
          // Keep the previous built range so the next frame retries.
        } finally {
          if (!_disposed && mounted) building.set(false);
        }
      } while (_rebuildAgain && !_disposed && mounted);
    } finally {
      _rebuilding = false;
    }
    if (!_disposed && mounted && didRebuild) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final window = ref.watch(calendarStateProvider);
    ref.watch(occurrenceDirtyProvider);
    ref.watch(initialRestoreDoneProvider);
    _scheduleRebuild();
    return Scaffold(
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Scale the sync target down instead of wrapping when the
            // toolbar is narrow (leading plus four actions).
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: const SyncTitle(text: 'Calendar'),
            ),
            Text(
              _title(context, window),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.today),
          tooltip: 'Today',
          onPressed: () {
            AppFeedback.tap();
            ref.read(calendarStateProvider.notifier).goToday();
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () =>
                ref.read(calendarStateProvider.notifier).shift(-_step(window)),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () =>
                ref.read(calendarStateProvider.notifier).shift(_step(window)),
          ),
          PopupMenuButton<_ViewChoice>(
            icon: const Icon(Icons.view_agenda_outlined),
            onSelected: (choice) {
              AppFeedback.selection();
              ref
                  .read(calendarStateProvider.notifier)
                  .setView(choice.view, dayCount: choice.dayCount);
            },
            itemBuilder: (ctx) => [
              for (final choice in _viewChoices)
                CheckedPopupMenuItem<_ViewChoice>(
                  value: choice,
                  checked: choice.isSelected(window),
                  child: Text(choice.label),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const CalendarSettingsScreen(),
              ),
            ),
          ),
        ],
      ),
      body: switch (window.view) {
        CalendarViewKind.month => CalendarSwipe(
          enabled: true,
          onShift: (direction) =>
              ref.read(calendarStateProvider.notifier).shiftMonths(direction),
          child: const MonthView(),
        ),
        CalendarViewKind.multiDay => TimelineView(
          anchor: window.anchor,
          dayCount: window.dayCount,
        ),
        CalendarViewKind.day => TimelineView(
          anchor: window.anchor,
          dayCount: 1,
        ),
        CalendarViewKind.agenda => const AgendaView(),
        CalendarViewKind.year => CalendarSwipe(
          enabled: true,
          onShift: (direction) => ref
              .read(calendarStateProvider.notifier)
              .shiftMonths(direction * 12),
          child: const YearView(),
        ),
      },
      floatingActionButton: FloatingActionButton(
        heroTag: 'calendarFab',
        onPressed: () =>
            showEventEditor(context, initialDay: window.anchor, initialHour: 9),
        child: const Icon(Icons.add),
      ),
    );
  }

  int _step(CalendarWindow w) => switch (w.view) {
    CalendarViewKind.month => 30,
    CalendarViewKind.year => 365,
    CalendarViewKind.multiDay => w.dayCount,
    _ => 1,
  };

  String _title(BuildContext context, CalendarWindow w) =>
      DeviceDateFormat.yMMM(context).format(w.anchor);
}

class _ViewChoice {
  const _ViewChoice(this.view, {this.dayCount = 1});

  final CalendarViewKind view;
  final int dayCount;

  String get label => switch (view) {
    CalendarViewKind.month => 'Month',
    CalendarViewKind.multiDay => '$dayCount days',
    CalendarViewKind.day => 'Day',
    CalendarViewKind.agenda => 'Agenda',
    CalendarViewKind.year => 'Year',
  };

  bool isSelected(CalendarWindow window) => isCalendarViewChoiceSelected(
    view: view,
    dayCount: dayCount,
    window: window,
  );
}

const List<_ViewChoice> _viewChoices = [
  _ViewChoice(CalendarViewKind.month),
  _ViewChoice(CalendarViewKind.multiDay, dayCount: 3),
  _ViewChoice(CalendarViewKind.multiDay, dayCount: 4),
  _ViewChoice(CalendarViewKind.multiDay, dayCount: 5),
  _ViewChoice(CalendarViewKind.multiDay, dayCount: 7),
  _ViewChoice(CalendarViewKind.day),
  _ViewChoice(CalendarViewKind.agenda),
  _ViewChoice(CalendarViewKind.year),
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

Future<void> persistCalendarView(WidgetRef ref) async {
  // Snapshot before the await so a disposed screen's ref is never read after
  // the settings repository resolves.
  final window = ref.read(calendarStateProvider);
  final repo = await ref.read(settingsRepositoryProvider.future);
  await repo.setCalendarView(window.view.name);
  await repo.setCalendarAnchorMs(
    DateTime.utc(
      window.anchor.year,
      window.anchor.month,
      window.anchor.day,
    ).millisecondsSinceEpoch,
  );
  await repo.setCalendarDayCount(window.dayCount);
}
