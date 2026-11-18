// Calendar screen: page chrome, adaptive first-run view and occurrence cache
// gating.
//
// Rebuilds go through the single-flight coordinator. The first frame renders
// whatever the previous session materialized (offline-first); a new range is
// only marked built after `ensureRange` materialized it, so month, timeline,
// agenda and year views never render a range that is still being rebuilt.
// `calendarRangeOccurrencesProvider` exposes the coordinator-backed rows and
// surfaces rebuild failures; `occurrenceDirtyProvider` invalidates coordinator
// coverage before re-ensuring the range.
import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/session/session_restore.dart';
import '../../../core/design/components/app_page.dart';
import '../../../core/design/components/app_states.dart';
import '../../../core/design/layout.dart';
import '../../settings/application/settings_providers.dart';
import '../../tasks/application/tasks_providers.dart';
import '../application/calendar_cache_coordinator.dart';
import '../application/calendar_providers.dart';
import '../application/calendar_state.dart';
import 'agenda_view.dart';
import 'calendar_screen/calendar_defaults.dart';
import 'calendar_screen/calendar_header.dart';
import 'calendar_strings.dart';
import 'calendar_swipe.dart';
import 'event_editor_sheet.dart';
import 'month_view.dart';
import 'timeline/timeline_view.dart';
import 'year_view.dart';

export 'calendar_screen/calendar_view_menu.dart'
    show CalendarViewChoice, isCalendarViewChoiceSelected;

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  CalendarRange? _builtRange;
  CalendarRange? _failedRange;
  CalendarWindow? _persisted;
  Timer? _restoreFallback;
  AppLayout _layout = AppLayout.compact;
  bool _disposed = false;
  bool _rebuilding = false;
  bool _rebuildAgain = false;
  bool _rebuildScheduled = false;
  bool _defaultsReady = false;
  bool _defaultCheckStarted = false;

  @override
  void initState() {
    super.initState();
    // The cache starts dirty (a fresh app has no materialized window). Reset
    // coordinator coverage whenever something invalidates the cache so the
    // next ensureRange rebuilds even when its own range looks covered.
    ref.listenManual<bool>(occurrenceDirtyProvider, (previous, next) {
      if (next) ref.invalidate(calendarCacheCoordinatorProvider);
    }, fireImmediately: true);
    _scheduleRebuild();
    // Safety net: if session restore never reports completion, unblock the
    // normal rebuild path instead of leaving the calendar empty. The build is
    // scheduled (not run directly) so a restore completing in the same frame
    // is coalesced into a single initial cache build.
    _restoreFallback = Timer(const Duration(seconds: 2), () {
      if (_disposed || !mounted) return;
      if (ref.read(initialRestoreDoneProvider)) return;
      ref.read(initialRestoreDoneProvider.notifier).markDone();
      _scheduleRebuild();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _layout = AppLayoutScope.maybeOf(context) ?? AppLayout.compact;
  }

  @override
  void dispose() {
    _disposed = true;
    _restoreFallback?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final window = ref.watch(calendarStateProvider);
    final restored = ref.watch(initialRestoreDoneProvider);
    // Watching the dirty flag lets an edit made during a rebuild queue one
    // more pass instead of being lost.
    ref.watch(occurrenceDirtyProvider);
    final range = ref.watch(calendarCacheRangeProvider);
    // A fresh install restores the month fallback first. Do not materialize it
    // only to switch to the adaptive day/week view: wait for the one-time
    // preference check. Restored windows that cannot be defaulted render
    // immediately.
    final waitForDefault =
        restored && !_defaultsReady && canApplyFreshInstallDefault(window);
    final rangeAsync = restored && !waitForDefault
        ? ref.watch(calendarRangeOccurrencesProvider(range))
        : null;
    if (restored) {
      _scheduleDefaultCheck();
      _persistWindow(window);
    }
    _scheduleRebuild();

    final strings = CalendarStrings.of(context);
    final failed = _failedRange == range || (rangeAsync?.hasError ?? false);
    return AppPage(
      // The calendar grids own their internal insets; a page gutter would
      // shrink month cells and timeline day columns.
      padding: EdgeInsets.zero,
      header: CalendarHeader(window: window),
      fab: FloatingActionButton(
        heroTag: 'calendarFab',
        tooltip: strings.newEvent,
        onPressed: () =>
            showEventEditor(context, initialDay: window.anchor, initialHour: 9),
        child: const Icon(Icons.add),
      ),
      child: failed
          ? AppErrorState(
              title: strings.loadErrorTitle,
              message: strings.loadErrorMessage,
              onRetry: () {
                setState(() => _failedRange = null);
                _builtRange = null;
                ref.invalidate(calendarCacheCoordinatorProvider);
                ref.invalidate(calendarRangeOccurrencesProvider(range));
                _scheduleRebuild();
              },
            )
          : _viewFor(window),
    );
  }

  Widget _viewFor(CalendarWindow window) {
    switch (window.view) {
      case CalendarViewKind.month:
        return CalendarSwipe(
          enabled: true,
          onShift: (direction) =>
              ref.read(calendarStateProvider.notifier).shiftMonths(direction),
          child: const MonthView(),
        );
      case CalendarViewKind.multiDay:
        return TimelineView(anchor: window.anchor, dayCount: window.dayCount);
      case CalendarViewKind.day:
        return TimelineView(anchor: window.anchor, dayCount: 1);
      case CalendarViewKind.agenda:
        return const AgendaView();
      case CalendarViewKind.year:
        return CalendarSwipe(
          enabled: true,
          onShift: (direction) => ref
              .read(calendarStateProvider.notifier)
              .shiftMonths(direction * 12),
          child: const YearView(),
        );
    }
  }

  void _scheduleRebuild() {
    if (_disposed || _rebuildScheduled) return;
    _rebuildScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _rebuildScheduled = false;
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
    // A fresh install has to resolve its adaptive default before the first
    // materialization; otherwise the month fallback and the day/week view
    // would both rebuild the cache.
    if (!_defaultsReady && canApplyFreshInstallDefault(window)) return;

    // A failed range keeps its error state until the user retries or the
    // window moves; rebuilding on every build would spin on the same failure.
    if (_failedRange == ref.read(calendarCacheRangeProvider)) return;

    // Persist every window change (including day selection in the month
    // view) without forcing a cache rebuild for it.
    _persistWindow(window);

    _rebuilding = true;
    var didRebuild = false;
    try {
      do {
        _rebuildAgain = false;
        if (_disposed || !mounted) break;
        final dirty = ref.read(occurrenceDirtyProvider);
        final range = ref.read(calendarCacheRangeProvider);
        if (!dirty && _builtRange == range) break;
        // The dirty listener already dropped coordinator coverage for a stale
        // cache. Re-ensuring here joins the same single-flight chain as the
        // range stream instead of starting a second coordinator.
        final building = ref.read(calendarCacheBuildingProvider.notifier);
        building.set(true);
        try {
          await ref.read(calendarCacheCoordinatorProvider).ensureRange(range);
          // The screen may have been replaced while the cache was building.
          if (_disposed || !mounted) return;
          _builtRange = range;
          _failedRange = null;
          didRebuild = true;
          // Only expose the new range once the whole window is materialized.
          ref.read(calendarBuiltRangeProvider.notifier).markBuilt(range);
          if (ref.read(occurrenceDirtyProvider)) {
            ref.read(occurrenceDirtyProvider.notifier).clear();
          }
        } catch (_) {
          // Keep the previous built range so the next frame retries, and let
          // the error state offer an explicit retry.
          _failedRange = range;
        } finally {
          if (!_disposed && mounted) building.set(false);
        }
      } while (_rebuildAgain && !_disposed && mounted);
    } finally {
      _rebuilding = false;
    }
    if (!_disposed && mounted && (didRebuild || _failedRange != null)) {
      setState(() {});
    }
  }

  /// Persists every window change, including month day selection.
  void _persistWindow(CalendarWindow window) {
    if (_persisted == window) return;
    // The restored month fallback must not be written before the one-time
    // fresh-install check decides whether a different default applies.
    if (!_defaultsReady && canApplyFreshInstallDefault(window)) return;
    _persisted = window;
    Future.microtask(() async {
      try {
        if (_disposed || !mounted) return;
        await persistCalendarView(ref);
      } catch (_) {
        // Persistence is best effort and must never block the calendar.
      }
    });
  }

  void _scheduleDefaultCheck() {
    if (_defaultsReady || _defaultCheckStarted) return;
    if (!ref.read(initialRestoreDoneProvider)) return;
    _defaultCheckStarted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed || !mounted) return;
      unawaited(_resolveFreshInstallDefault());
    });
  }

  Future<void> _resolveFreshInstallDefault() async {
    try {
      final prefs = await ref.read(sharedPreferencesProvider.future);
      if (_disposed || !mounted) return;
      if (!prefs.containsKey(calendarViewPreferenceKey)) {
        final next = freshInstallCalendarWindow(
          _layout,
          ref.read(calendarStateProvider),
        );
        if (next != null) {
          ref
              .read(calendarStateProvider.notifier)
              .restore(next.view, next.anchor, dayCount: next.dayCount);
        }
      }
    } catch (_) {
      // Preferences are best effort; the restored window still renders.
    }
    if (_disposed || !mounted) return;
    setState(() => _defaultsReady = true);
    _persistWindow(ref.read(calendarStateProvider));
    _scheduleRebuild();
  }
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
