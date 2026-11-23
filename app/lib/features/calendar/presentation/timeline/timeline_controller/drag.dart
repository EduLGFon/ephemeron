part of '../timeline_controller.dart';

mixin TimelineDrag on TimelineInteraction {
  // Tracks what is being dragged so the drop persists to the right repo.
  String dragSourceType = 'event';
  int? dragTaskStartMs;
  int? dragTaskEndMs;

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

  void beginDrag(
    String eventId, {
    String sourceType = 'event',
    int? startUtcMs,
    int? endUtcMs,
  }) {
    final generation = ++_dragBeginGeneration;
    unawaited(
      _beginDragIfWritable(
        eventId,
        generation,
        sourceType: sourceType,
        startUtcMs: startUtcMs,
        endUtcMs: endUtcMs,
      ),
    );
  }

  int _dragBeginGeneration = 0;

  Future<void> _beginDragIfWritable(
    String eventId,
    int generation, {
    required String sourceType,
    int? startUtcMs,
    int? endUtcMs,
  }) async {
    // Tasks have no calendar read-only flag; only events can be locked.
    if (sourceType != 'task' && await _isReadOnlySource(eventId)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Calendar is read-only. Event not moved.'),
          ),
        );
      }
      return;
    }
    if (!mounted || generation != _dragBeginGeneration) return;
    setState(() {
      dragId = eventId;
      dragDy = 0;
      dragDayDelta = 0;
      dragSourceType = sourceType;
      dragTaskStartMs = startUtcMs;
      dragTaskEndMs = endUtcMs;
    });
  }

  Future<bool> _isReadOnlySource(String eventId) async {
    try {
      final repo = ref.read(eventRepositoryProvider);
      final event = await repo.getEvent(eventId);
      if (event == null) return false;
      return await repo.isEventReadOnly(event);
    } catch (_) {
      return false;
    }
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
    _dragBeginGeneration++;
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
    final sourceType = dragSourceType;
    final startMs = dragTaskStartMs;
    final endMs = dragTaskEndMs;
    setState(() {
      dragId = null;
      dragDy = 0;
      dragDayDelta = 0;
      dragSourceType = 'event';
      dragTaskStartMs = null;
      dragTaskEndMs = null;
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
    if (sourceType == 'task') {
      await _endTaskDrag(
        id,
        snapped: snapped,
        dayDelta: dayDelta,
        startMs: startMs,
        endMs: endMs,
      );
      return;
    }
    final repo = ref.read(eventRepositoryProvider);
    final master = await (repo.dbSelect()..where((e) => e.id.equals(id)))
        .getSingleOrNull();
    if (master == null || !context.mounted) {
      _clearPending();
      return;
    }
    if (await repo.isEventReadOnly(master)) {
      _clearPending();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Calendar is read-only. Event not moved.'),
          ),
        );
      }
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
    if (!context.mounted) {
      _clearPending();
      return;
    }
    try {
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
    } on SourceMoveException catch (e) {
      _clearPending();
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
      return;
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
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Event moved')));
      }
    }
  }

  /// Persists a dropped task block. The cache stores task times as local wall
  /// clock converted to UTC ms, so reading them back as local restores the
  /// exact values the task editor wrote.
  Future<void> _endTaskDrag(
    String taskId, {
    required int snapped,
    required int dayDelta,
    required int? startMs,
    required int? endMs,
  }) async {
    if (startMs == null || endMs == null) {
      _clearPending();
      return;
    }
    // Look up by id directly: watchOpen() filters out subtasks
    // (parentId != null), so a timed subtask block would otherwise fail the
    // lookup and silently lose its drop. A by-id query includes subtasks.
    final db = ref.read(appDatabaseProvider);
    final task = await (db.select(
      db.tasks,
    )..where((t) => t.id.equals(taskId))).getSingleOrNull();
    if (!context.mounted) {
      _clearPending();
      return;
    }
    if (task == null || task.deletedAt != null) {
      _clearPending();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Task move was not applied (task not found)'),
        ),
      );
      return;
    }
    if (task.rrule != null && task.rrule!.isNotEmpty) {
      // Recurring-task occurrence drags must not write plannedStart/End on the
      // master without updating recurrence metadata; that shifts occurrences
      // and can make them vanish. Decline explicitly until task scope editing
      // matches the event path.
      _clearPending();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Recurring tasks cannot be moved by dragging'),
          ),
        );
      }
      return;
    }
    final baseStart = DateTime.fromMillisecondsSinceEpoch(startMs);
    final baseEnd = DateTime.fromMillisecondsSinceEpoch(endMs);
    // Preserve wall-clock time across day moves and DST boundaries by
    // constructing local DateTimes from components instead of adding a
    // Duration(days: ...), which shifts by 24h and can move the clock hour.
    final newStart = DateTime(
      baseStart.year,
      baseStart.month,
      baseStart.day + dayDelta,
      baseStart.hour,
      baseStart.minute + snapped,
    );
    final newEnd = DateTime(
      baseEnd.year,
      baseEnd.month,
      baseEnd.day + dayDelta,
      baseEnd.hour,
      baseEnd.minute + snapped,
    );
    final repo = ref.read(taskRepositoryProvider);
    try {
      if (task.plannedStart != null && task.plannedStart!.isNotEmpty) {
        await repo.updateTask(
          taskId,
          plannedStart: () => _localMinuteIso(newStart),
          plannedEnd: () => _localMinuteIso(newEnd),
        );
      } else {
        // A due-time drop only moves the due timestamp. Leave plannedDate as
        // stored: updateTask writes Value.absent() when it is omitted, so an
        // existing planned day is preserved instead of being cleared.
        await repo.updateTask(
          taskId,
          dueDate: () => _dateKey(newStart),
          dueTime: () => newStart.hour * 60 + newStart.minute,
        );
      }
    } catch (_) {
      _clearPending();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task could not be moved')),
        );
      }
      return;
    }
    if (!context.mounted) {
      _clearPending();
      return;
    }
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
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Task moved')));
    }
  }

  static String _localMinuteIso(DateTime dt) =>
      '${dt.year.toString().padLeft(4, '0')}-'
      '${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')}T'
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}';

  static String _dateKey(DateTime dt) =>
      '${dt.year.toString().padLeft(4, '0')}-'
      '${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')}';
}
