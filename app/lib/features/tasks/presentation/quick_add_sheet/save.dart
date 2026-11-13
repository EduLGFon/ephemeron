part of '../quick_add_sheet.dart';

mixin _QuickAddSave on _QuickAddSheetStateBase {
  // ignore: unused_element
  Future<void> _save({required bool another}) async {
    final p = _parsed;
    if (p == null || p.title.isEmpty) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final navigator = Navigator.of(context);
    final repo = ref.read(taskRepositoryProvider);
    String? listId;
    if (p.list != null) {
      final lists = await ref.read(taskListsProvider.future);
      listId = lists
          .where((l) => l.name.toLowerCase() == p.list!.toLowerCase())
          .map((l) => l.id)
          .firstOrNull;
      listId ??= await repo.createList(p.list!);
    } else {
      try {
        final srepo = await ref.read(settingsRepositoryProvider.future);
        final last = srepo.selectedTaskListId;
        if (last != null) {
          final lists = await ref.read(taskListsProvider.future);
          if (lists.any((l) => l.id == last && l.deletedAt == null)) {
            listId = last;
          }
        }
      } catch (_) {}
    }
    final createdId = await repo.createTask(
      title: p.title,
      listId: listId,
      priority: p.priority,
      dueDate: p.due == null
          ? null
          : '${p.due!.year.toString().padLeft(4, '0')}-'
                '${p.due!.month.toString().padLeft(2, '0')}-'
                '${p.due!.day.toString().padLeft(2, '0')}',
      dueTime: p.due == null || (p.due!.hour == 0 && p.due!.minute == 0)
          ? null
          : p.due!.hour * 60 + p.due!.minute,
      rrule: p.rrule,
      tags: p.tags,
    );
    if (!mounted) return;
    try {
      ref.read(occurrenceDirtyProvider.notifier).markDirty();
    } catch (_) {}
    _saved = true;
    try {
      await ref.read(draftStoreProvider).clear('quick_add', null);
      final srepo = await ref.read(settingsRepositoryProvider.future);
      if (listId != null) await srepo.setSelectedTaskListId(listId);
      if (srepo.openSheet == 'quick_add') await srepo.setOpenSheet(null);
    } catch (_) {}
    if (!mounted) return;
    AppFeedback.success();
    if (another) {
      _justAdded = true;
      _saved = false;
      _controller.clear();
      setState(() => _parsed = null);
      _focusNode.requestFocus();
      return;
    }
    if (!mounted) return;
    if (navigator.canPop()) navigator.pop();
    if (messenger != null && navigator.mounted) {
      showUndoSnackBar(
        navigator.context,
        'Task added',
        onUndo: () => repo.softDeleteTasks([createdId]),
      );
    }
  }
}
