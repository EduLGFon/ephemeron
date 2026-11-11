part of '../app_shell.dart';

extension _AppShellNavigation on _AppShellState {
  void _onDestinationSelected(
    int selected,
    List<int> pinned,
    List<int> more,
    List<int> order,
  ) {
    if (selected >= 5) {
      _showMore(context, more, order);
      return;
    }
    final branchIndex = pinned[selected];
    final now = DateTime.now();
    final isDoubleTap =
        _lastTabTapIndex == branchIndex &&
        _lastTabTapAt != null &&
        now.difference(_lastTabTapAt!) <= const Duration(milliseconds: 350);
    _lastTabTapIndex = branchIndex;
    _lastTabTapAt = now;
    // Double-tapping the active Calendar tab is the only hidden gesture:
    // it jumps back to today.
    if (isDoubleTap && branchIndex == AppSection.calendar.index) {
      AppFeedback.selection();
      ref.read(calendarStateProvider.notifier).goToday();
      return;
    }
    _onTabSelected(branchIndex);
  }

  Future<void> _onTabSelected(int branchIndex) async {
    if (widget.navigationShell.currentIndex != branchIndex) {
      AppFeedback.selection();
    }
    widget.navigationShell.goBranch(branchIndex);
    if (branchIndex == AppSection.calendar.index) {
      ref.read(timelineNowControllerProvider).refresh();
    }
    try {
      final repo = await ref.read(settingsRepositoryProvider.future);
      await repo.setLastTabIndex(branchIndex);
      await repo.setLastRoute('/tab$branchIndex');
    } catch (_) {}
  }

  void _showMore(BuildContext context, List<int> more, List<int> order) {
    final navigator = Navigator.of(context);

    Future<void> record(String route) async {
      try {
        final repo = await ref.read(settingsRepositoryProvider.future);
        await repo.setLastRoute(route);
      } catch (_) {}
    }

    showAppSheet<void>(
      context,
      builder: (ctx) => EscapeToClose(
        child: MoreSheet(
          more: more,
          onSelected: (idx) {
            Navigator.of(ctx).pop();
            _onTabSelected(idx);
          },
          onReorder: () async {
            Navigator.of(ctx).pop();
            await _reorderSheet(context, order);
          },
          onSearch: () {
            Navigator.of(ctx).pop();
            context.push('/search');
            record('/search');
          },
          onSettings: () {
            Navigator.of(ctx).pop();
            context.push('/settings');
            record('/settings');
          },
          onCreate: (action) {
            Navigator.of(ctx).pop();
            // Use the navigator captured before the sheet mounted: the sheet
            // context is gone once the pop animation starts.
            unawaited(_createFromMore(action, navigator.context));
          },
        ),
      ),
    );
  }

  Future<void> _createFromMore(
    MoreCreateAction action,
    BuildContext context,
  ) async {
    switch (action) {
      case MoreCreateAction.task:
        await showQuickAdd(context);
        return;
      case MoreCreateAction.event:
        await showEventEditor(context, initialDay: DateTime.now());
        return;
      case MoreCreateAction.note:
        try {
          final id = await ref
              .read(noteRepositoryProvider)
              .createNote(title: '');
          if (!context.mounted) return;
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => NoteEditorScreen(noteId: id),
            ),
          );
        } catch (_) {
          if (context.mounted) {
            showErrorSnackBar(context, 'Could not create a note.');
          }
        }
        return;
      case MoreCreateAction.habit:
        await showHabitEditor(context);
        return;
      case MoreCreateAction.countdown:
        await showCountdownEditor(context);
        return;
    }
  }

  Future<void> _reorderSheet(BuildContext context, List<int> order) async {
    final current = List<int>.from(order);
    await showAppSheet<void>(
      context,
      builder: (ctx) => EscapeToClose(
        child: StatefulBuilder(
          builder: (ctx, setSt) => SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.7,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Reorder sections',
                      style: Theme.of(ctx).textTheme.titleMedium,
                    ),
                  ),
                  Flexible(
                    child: ReorderableListView(
                      shrinkWrap: true,
                      onReorderItem: (oldIndex, newIndex) {
                        setSt(() {
                          final item = current.removeAt(oldIndex);
                          current.insert(newIndex, item);
                        });
                      },
                      children: [
                        for (final idx in current)
                          ListTile(
                            key: ValueKey(idx),
                            leading: Icon(AppSection.values[idx].icon),
                            title: Text(AppSection.values[idx].title),
                            trailing: const Icon(Icons.drag_handle),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: FilledButton(
                      onPressed: () async {
                        final repo = await ref.read(
                          settingsRepositoryProvider.future,
                        );
                        await repo.setNavOrder(current);
                        ref.invalidate(settingsRepositoryProvider);
                        if (ctx.mounted) Navigator.of(ctx).pop();
                      },
                      child: const Text('Save'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
