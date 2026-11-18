part of '../quick_add_sheet.dart';

mixin _QuickAddSave on _QuickAddSheetStateBase {
  // ignore: unused_element
  Future<void> _save({required bool another}) async {
    if (_busy) return;
    final parsed = _parsed;
    if (parsed == null || parsed.title.trim().isEmpty) return;
    final strings = QuickAddStrings.of(context);
    setState(() => _busy = true);
    String? createdTaskId;
    try {
      switch (_kind) {
        case _QuickAddKind.task:
          createdTaskId = await _createTask(parsed);
        case _QuickAddKind.event:
          final openedEditor = await _createEvent(parsed);
          if (openedEditor) return;
        case _QuickAddKind.habit:
          await _createHabit(parsed);
        case _QuickAddKind.countdown:
          await _createCountdown(parsed);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      showErrorSnackBar(context, strings.saveFailed);
      return;
    }
    if (!mounted) return;
    _saved = true;
    await _clearDraftState();
    if (!mounted) return;
    AppFeedback.success();
    if (another) {
      setState(() {
        _busy = false;
        _controller.clear();
        _parsed = null;
        _pickedDate = null;
      });
      _saved = false;
      _focusNode.requestFocus();
      return;
    }
    final navigator = Navigator.of(context);
    final taskRepo = createdTaskId == null
        ? null
        : ref.read(taskRepositoryProvider);
    if (navigator.canPop()) navigator.pop();
    if (createdTaskId != null && taskRepo != null && navigator.mounted) {
      showUndoSnackBar(
        navigator.context,
        strings.taskAdded,
        onUndo: () => taskRepo.softDeleteTasks([createdTaskId!]),
      );
    }
  }

  Future<String> _createTask(QuickAddParsed parsed) async {
    final repo = ref.read(taskRepositoryProvider);
    final listId = await _resolveTaskList(parsed);
    final due = _effectiveDue;
    final id = await repo.createTask(
      title: parsed.title,
      listId: listId,
      priority: parsed.priority,
      dueDate: due == null ? null : formatYmd(due),
      dueTime: due == null || (due.hour == 0 && due.minute == 0)
          ? null
          : due.hour * 60 + due.minute,
      rrule: parsed.rrule,
      tags: parsed.tags,
    );
    ref.read(occurrenceDirtyProvider.notifier).markDirty();
    if (listId != null) {
      try {
        final SettingsRepository settings =
            _settings ?? await ref.read(settingsRepositoryProvider.future);
        _settings = settings;
        await settings.setSelectedTaskListId(listId);
      } catch (_) {
        // Best effort: the task itself is already saved locally.
      }
    }
    return id;
  }

  /// Explicit chip > parsed `~list` > last selected list > repository default.
  Future<String?> _resolveTaskList(QuickAddParsed parsed) async {
    final repo = ref.read(taskRepositoryProvider);
    final lists = await ref.read(taskListsProvider.future);
    final selected = _selectedListId;
    if (selected != null &&
        lists.any((l) => l.id == selected && l.deletedAt == null)) {
      return selected;
    }
    final parsedList = parsed.list;
    if (parsedList != null) {
      final match = lists
          .where(
            (l) =>
                l.deletedAt == null &&
                l.name.toLowerCase() == parsedList.toLowerCase(),
          )
          .firstOrNull;
      return match?.id ?? await repo.createList(parsedList);
    }
    try {
      final SettingsRepository settings =
          _settings ?? await ref.read(settingsRepositoryProvider.future);
      _settings = settings;
      final last = settings.selectedTaskListId;
      if (last != null &&
          lists.any((l) => l.id == last && l.deletedAt == null)) {
        return last;
      }
    } catch (_) {
      // Fall through to the repository default list.
    }
    return null;
  }

  /// Returns true when no writable calendar exists and the full event editor
  /// was opened with the parsed title and start instead.
  Future<bool> _createEvent(QuickAddParsed parsed) async {
    final calendars = await ref.read(calendarsProvider.future);
    final writable = calendars
        .where((c) => c.deletedAt == null && !c.readOnly)
        .toList();
    final start = _eventStartFor(DateTime.now(), _effectiveDue);
    if (writable.isEmpty) {
      await _openEventEditor(parsed, start);
      return true;
    }
    final SettingsRepository settings =
        _settings ?? await ref.read(settingsRepositoryProvider.future);
    _settings = settings;
    final defaultId = settings.defaultCalendarId;
    final calendar =
        writable.where((c) => c.id == defaultId).firstOrNull ?? writable.first;
    await ref
        .read(eventRepositoryProvider)
        .createEvent(
          calendarId: calendar.id,
          title: parsed.title,
          startUtc: start.toUtc(),
          endUtc: start.add(const Duration(hours: 1)).toUtc(),
          rrule: parsed.rrule,
        );
    ref.read(occurrenceDirtyProvider.notifier).markDirty();
    try {
      await settings.setDefaultCalendarId(calendar.id);
    } catch (_) {
      // Best effort: the event is already saved locally.
    }
    return false;
  }

  Future<void> _openEventEditor(QuickAddParsed parsed, DateTime start) async {
    final navigator = Navigator.of(context);
    _saved = true;
    await _clearDraftState();
    if (navigator.canPop()) navigator.pop();
    if (!navigator.mounted) return;
    await showEventEditor(
      navigator.context,
      initialStart: start,
      restoredDraft: <String, dynamic>{'title': parsed.title},
    );
  }

  Future<void> _createHabit(QuickAddParsed parsed) async {
    await ref
        .read(habitRepositoryProvider)
        .createHabit(
          name: parsed.title,
          frequency: 'daily',
          startDate: habitDateKey(DateTime.now()),
        );
  }

  Future<void> _createCountdown(QuickAddParsed parsed) async {
    final target =
        _effectiveDue ?? DateTime.now().add(const Duration(days: 30));
    await ref
        .read(countdownRepositoryProvider)
        .createCountdown(title: parsed.title, targetDate: formatYmd(target));
  }

  Future<void> _clearDraftState() async {
    try {
      await ref.read(draftStoreProvider).clear('quick_add', null);
    } catch (_) {
      // Best effort: the saved item is more important than draft cleanup.
    }
    try {
      final settings = _settings;
      if (settings != null && settings.openSheet == 'quick_add') {
        await settings.setOpenSheet(null);
      }
    } catch (_) {
      // Best effort: a stale marker is harmless.
    }
  }
}

/// Event smart default: an explicit parsed time wins, otherwise the next hour
/// on the parsed/picked day, or today's next hour.
DateTime _eventStartFor(DateTime now, DateTime? due) {
  final next = now.add(const Duration(hours: 1));
  final nextHour = DateTime(next.year, next.month, next.day, next.hour);
  if (due == null || (due.hour == 0 && due.minute == 0)) {
    if (due == null) return nextHour;
    final today = DateTime(now.year, now.month, now.day);
    final dueDay = DateTime(due.year, due.month, due.day);
    if (dueDay.isBefore(today)) return nextHour;
    return DateTime(due.year, due.month, due.day, next.hour);
  }
  return due;
}
