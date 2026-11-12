part of '../timeline_controller.dart';

mixin TimelineDrag on TimelineInteraction {
  void tapEmptyAt(
    Offset pos,
    double colW,
    DateTime stripAnchor,
    int stripCount,
  ) {
    final dayIdx = (pos.dx / colW).floor().clamp(0, stripCount - 1);
    final slotMin = ((pos.dy / hourHeight * 60) / 30).floor() * 30;
    final min = slotMin.clamp(0, 1380).toInt();
    final start = timelineDayStart(
      stripAnchor,
      dayIdx,
    ).add(Duration(minutes: min));
    final end = start.add(const Duration(hours: 1));
    showEventEditor(context, initialStart: start, initialEnd: end);
  }

  // Empty-grid long-press selection state.
  int selStartDay = 0;
  int selStartMin = 0;
  int selEndDay = 0;
  int selEndMin = 30;
  // Immutable gesture anchor; never mutated by updateSelection.
  int anchorSelDay = 0;
  int anchorSelMin = 0;
  DateTime? selectionStripAnchor;
  int selectionStripCount = 1;

  void beginSelection(
    Offset pos,
    double colW,
    DateTime stripAnchor,
    int stripCount,
  ) {
    final day = (pos.dx / colW).floor().clamp(0, stripCount - 1);
    final slot = ((pos.dy / hourHeight * 60) / 30).floor().clamp(0, 47).toInt();
    final min = slot * 30;
    swipeDisabled = true;
    swipeAbort();
    setState(() {
      isSelecting = true;
      anchorSelDay = day;
      anchorSelMin = min;
      selStartDay = day;
      selStartMin = min;
      selEndDay = day;
      selEndMin = (min + 30).clamp(0, 1440);
      selectionStripAnchor = stripAnchor;
      selectionStripCount = stripCount;
    });
  }

  void updateSelection(
    Offset pos,
    double colW,
    DateTime stripAnchor,
    int stripCount,
  ) {
    if (!isSelecting) return;
    final day = (pos.dx / colW).floor().clamp(0, stripCount - 1);
    final slot = ((pos.dy / hourHeight * 60) / 30).floor().clamp(0, 47).toInt();
    final pointMin = slot * 30;
    final b = timelineSelectionBounds(
      anchorDay: anchorSelDay,
      anchorMin: anchorSelMin,
      pointerDay: day,
      pointerMin: pointMin,
      stripCount: stripCount,
    );
    setState(() {
      selStartDay = b.startDay;
      selStartMin = b.startMin;
      selEndDay = b.endDay;
      selEndMin = b.endMin;
      selectionStripAnchor = stripAnchor;
      selectionStripCount = stripCount;
    });
  }

  void cancelSelection() {
    if (!isSelecting) return;
    setState(() => isSelecting = false);
    swipeDisabled = false;
  }

  void endSelection() {
    if (!isSelecting) return;
    swipeDisabled = false;
    final anchor = selectionStripAnchor;
    if (anchor == null) {
      setState(() => isSelecting = false);
      return;
    }
    final start = timelineDayStart(
      anchor,
      selStartDay,
    ).add(Duration(minutes: selStartMin));
    final totalMin =
        (selEndDay - selStartDay) * 1440 + (selEndMin - selStartMin);
    final dur = totalMin <= 0 ? 30 : totalMin;
    final end = start.add(Duration(minutes: dur));
    setState(() => isSelecting = false);
    showEventEditor(context, initialStart: start, initialEnd: end);
  }

  void beginDrag(String eventId) {
    setState(() {
      dragId = eventId;
      dragDy = 0;
      dragDayDelta = 0;
    });
  }

  void updateDrag(String eventId, LongPressMoveUpdateDetails d) {
    if (dragId != eventId) return;
    final dayDelta = (d.offsetFromOrigin.dx / lastColW).round();
    final snap =
        (d.offsetFromOrigin.dy / hourHeight * 60 / 15).round() *
        15 /
        60 *
        hourHeight;
    setState(() {
      dragDy = snap;
      dragDayDelta = dayDelta;
    });
  }

  void endDrag(String eventId) {
    if (dragId == eventId) {
      unawaited(_dragEnd());
    }
  }

  void _clearPending() {
    if (!mounted) return;
    setState(() {
      dragOffset = 0;
      dragXOffset = 0;
      pendingMovedId = null;
    });
  }

  Future<void> _dragEnd() async {
    final id = dragId;
    final dy = dragDy;
    final dayDelta = dragDayDelta;
    setState(() {
      dragId = null;
      dragDy = 0;
      dragDayDelta = 0;
      pendingMovedId = id;
      dragOffset = dy;
      dragXOffset = dayDelta * lastColW;
    });
    if (id == null) return;
    final snapMin = (dy / hourHeight * 60).round();
    final snapped = (snapMin / 15).round() * 15;
    if (snapped == 0 && dayDelta == 0) {
      _clearPending();
      return;
    }
    final repo = ref.read(eventRepositoryProvider);
    final master = await (repo.dbSelect()..where((e) => e.id.equals(id)))
        .getSingleOrNull();
    if (master == null || !context.mounted) {
      _clearPending();
      return;
    }
    if (master.isAllDay || master.startUtc == null) {
      _clearPending();
      return;
    }
    final orig = DateTime.fromMillisecondsSinceEpoch(
      master.startUtc!,
      isUtc: true,
    );
    final newStart = orig
        .add(Duration(minutes: snapped))
        .add(Duration(days: dayDelta));
    final newEnd = DateTime.fromMillisecondsSinceEpoch(
      master.endUtc ?? master.startUtc!,
      isUtc: true,
    ).add(Duration(minutes: snapped)).add(Duration(days: dayDelta));
    if (master.rrule != null && master.rrule!.isNotEmpty) {
      final scope = await showScopeSheet(context);
      if (scope == null || !context.mounted) {
        _clearPending();
        return;
      }
      await repo.editOccurrence(
        id,
        orig,
        scope: scope,
        startUtc: newStart,
        endUtc: newEnd,
      );
    } else {
      await repo.editOccurrence(
        id,
        orig,
        scope: EditScope.all,
        startUtc: newStart,
        endUtc: newEnd,
      );
    }
    if (context.mounted) {
      try {
        final range = ref.read(calendarCacheRangeProvider);
        await ref
            .read(occurrenceRepositoryProvider)
            .rebuildWindow(
              windowStartUtc: range.fromUtc,
              windowEndUtc: range.toUtc,
            );
      } catch (_) {}
      if (context.mounted) {
        setState(() {
          dragOffset = 0;
          pendingMovedId = null;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Event moved')));
      }
    }
  }
}
