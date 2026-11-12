part of '../timeline_view.dart';

extension _TimelineViewBuild on _TimelineViewState {
  Widget _buildTimeline(BuildContext context) {
    final range = ref.watch(calendarCacheRangeProvider);
    final built = ref.watch(calendarBuiltRangeProvider);
    final ready = built == range;
    // Subscribe only after CalendarScreen materializes this range, so the
    // first frame of a range never shows a partial pre-rebuild snapshot.
    final occAsync = ready ? ref.watch(windowOccurrencesProvider(range)) : null;
    final habitAsync = ready
        ? ref.watch(calendarHabitEntriesProvider(range))
        : null;
    final loading =
        !ready ||
        occAsync == null ||
        occAsync.isLoading ||
        habitAsync == null ||
        habitAsync.isLoading;
    final occs = occAsync?.value ?? const <OccurrenceCacheData>[];
    final habitEntries = habitAsync?.value ?? const <HabitCalendarEntry>[];
    final stripAnchor = timelineStripAnchor(widget.anchor);
    final stripCount = timelineStripCount(widget.dayCount);
    final timed = <OccurrenceCacheData>[];
    final allDay = <OccurrenceCacheData>[];
    for (final o in occs) {
      if (!timelineIsVisibleDay(stripAnchor, stripCount, o.dayKey)) {
        continue;
      }
      if (timelineIsAllDay(o)) {
        allDay.add(o);
      } else {
        timed.add(o);
      }
    }
    final timedHabits = <HabitCalendarEntry>[];
    final allDayHabits = <HabitCalendarEntry>[];
    for (final h in habitEntries) {
      if (!timelineIsVisibleDay(stripAnchor, stripCount, h.dayKey)) continue;
      if (h.isTimed) {
        timedHabits.add(h);
      } else {
        allDayHabits.add(h);
      }
    }
    timedHabits.sort((a, b) {
      final byTime = a.timeMinutes!.compareTo(b.timeMinutes!);
      if (byTime != 0) return byTime;
      final byName = a.habitName.compareTo(b.habitName);
      if (byName != 0) return byName;
      return a.habitId.compareTo(b.habitId);
    });

    return Focus(
      autofocus: true,
      onKeyEvent: onTimelineKeyEvent,
      child: Listener(
        onPointerDown: onTimelinePointerDown,
        onPointerMove: onTimelinePointerMove,
        onPointerUp: onTimelinePointerEnd,
        onPointerCancel: onTimelinePointerEnd,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragStart: onSwipeStart,
          onHorizontalDragUpdate: onSwipeUpdate,
          onHorizontalDragEnd: onSwipeEnd,
          onHorizontalDragCancel: onSwipeCancel,
          child: Column(
            children: [
              TimelineDayHeader(
                anchor: widget.anchor,
                dayCount: widget.dayCount,
                gutterWidth: timelineGutterWidth,
                swipeOffset: swipeOffset,
                onDayTap: widget.dayCount == 7
                    ? (day) {
                        final notifier = ref.read(
                          calendarStateProvider.notifier,
                        );
                        notifier.setView(CalendarViewKind.day);
                        notifier.goTo(day);
                      }
                    : null,
              ),
              if (loading) const LinearProgressIndicator(minHeight: 2),
              if (allDay.isNotEmpty || allDayHabits.isNotEmpty)
                TimelineAllDayStrip(
                  occs: allDay,
                  habits: allDayHabits,
                  anchor: widget.anchor,
                  dayCount: widget.dayCount,
                  gutterWidth: timelineGutterWidth,
                  swipeOffset: swipeOffset,
                  onTap: (o) {
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
              Expanded(
                child: _buildGrid(
                  context,
                  timed: timed,
                  timedHabits: timedHabits,
                  stripAnchor: stripAnchor,
                  stripCount: stripCount,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
