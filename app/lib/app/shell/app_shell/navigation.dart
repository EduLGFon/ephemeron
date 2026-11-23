part of '../app_shell.dart';

extension _AppShellNavigation on _AppShellState {
  /// Handles a tap on a branch destination. Double-tapping Calendar jumps
  /// back to today, the only hidden gesture in the shell.
  void _onDestinationSelected(int branchIndex) {
    final now = DateTime.now();
    final isDoubleTap =
        _lastTabTapIndex == branchIndex &&
        _lastTabTapAt != null &&
        now.difference(_lastTabTapAt!) <= const Duration(milliseconds: 350);
    _lastTabTapIndex = branchIndex;
    _lastTabTapAt = now;
    if (isDoubleTap && branchIndex == AppDestination.calendar.branch) {
      AppFeedback.selection();
      ref.read(calendarStateProvider.notifier).goToday();
      return;
    }
    _onTabSelected(branchIndex);
  }

  Future<void> _onTabSelected(int branchIndex) async {
    var target = branchIndex.clamp(0, AppDestination.all.length - 1).toInt();
    SettingsRepository? repo;
    try {
      repo = await ref.read(settingsRepositoryProvider.future);
    } catch (_) {}
    // Stream is opt-in. A stale shortcut, widget action or restored route
    // must never open it while disabled.
    final enabled = repo?.streamEnabled ?? false;
    if (target == AppDestination.stream.branch && !enabled) {
      target = AppDestination.today.branch;
    }
    if (!mounted) return;
    if (widget.navigationShell.currentIndex != target) {
      AppFeedback.selection();
    }
    widget.navigationShell.goBranch(target);
    if (target == AppDestination.calendar.branch) {
      ref.read(timelineNowControllerProvider).refresh();
    }
    try {
      final SettingsRepository settingsRepo;
      if (repo != null) {
        settingsRepo = repo;
      } else {
        settingsRepo = await ref.read(settingsRepositoryProvider.future);
      }
      await settingsRepo.setNavVersion(2);
      await settingsRepo.setLastTabIndex(target);
      await settingsRepo.setLastRoute(AppDestination.pathForBranch(target));
    } catch (_) {}
  }

  void _openSettings() {
    context.push('/settings');
    Future.microtask(() async {
      try {
        final repo = await ref.read(settingsRepositoryProvider.future);
        await repo.setLastRoute('/settings');
      } catch (_) {}
    });
  }

  void _openSearch() {
    context.push('/search');
    Future.microtask(() async {
      try {
        final repo = await ref.read(settingsRepositoryProvider.future);
        await repo.setLastRoute('/search');
      } catch (_) {}
    });
  }

  void _showMore(
    BuildContext context,
    List<int> secondary, [
    // ignore: avoid_unused_parameters
    List<int>? navOrder,
  ]) {
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
          secondary: secondary,
          onSelected: (idx) {
            Navigator.of(ctx).pop();
            _onDestinationSelected(idx);
          },
          onReorder: () async {
            Navigator.of(ctx).pop();
            await _reorderSheet(context);
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
        } catch (e) {
          debugPrint('[more] note creation failed: $e');
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

  Future<void> _reorderSheet(BuildContext context) async {
    SettingsRepository repo;
    try {
      repo = await ref.read(settingsRepositoryProvider.future);
    } catch (_) {
      return;
    }
    final current = List<int>.from(repo.navOrderV2);
    if (!context.mounted) return;
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
                      'Customize navigation order',
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
                        for (final id in current)
                          ListTile(
                            key: ValueKey<int>(id),
                            leading: Icon(AppDestination.byId(id).icon),
                            title: Text(AppDestination.byId(id).title),
                            trailing: const Icon(Icons.drag_handle),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: FilledButton(
                      onPressed: () async {
                        final saveRepo = await ref.read(
                          settingsRepositoryProvider.future,
                        );
                        await saveRepo.setNavOrderV2(current);
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
