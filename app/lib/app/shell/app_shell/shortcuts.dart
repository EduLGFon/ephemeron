part of '../app_shell.dart';

const List<LogicalKeyboardKey> _digitKeys = <LogicalKeyboardKey>[
  LogicalKeyboardKey.digit1,
  LogicalKeyboardKey.digit2,
  LogicalKeyboardKey.digit3,
  LogicalKeyboardKey.digit4,
  LogicalKeyboardKey.digit5,
];

extension _AppShellShortcuts on _AppShellState {
  /// Keyboard shortcuts active on every route. Rebuilt with [build] so the
  /// callbacks always see the current widget/riverpod state.
  Map<ShortcutActivator, VoidCallback> _buildShortcuts(
    List<int> primary,
    List<int> secondary,
  ) {
    void openSearch() {
      if (!mounted) return;
      _openSearch();
    }

    return <ShortcutActivator, VoidCallback>{
      SingleActivator(LogicalKeyboardKey.keyN): () {
        if (!mounted) return;
        showQuickAdd(context);
      },
      SingleActivator(LogicalKeyboardKey.keyC): () {
        if (!mounted) return;
        _showMore(context, secondary, primary);
      },
      SingleActivator(LogicalKeyboardKey.keyT): () {
        if (!mounted) return;
        _onTabSelected(AppDestination.today.branch);
      },
      SingleActivator(LogicalKeyboardKey.slash): openSearch,
      SingleActivator(LogicalKeyboardKey.keyK, control: true): openSearch,
      SingleActivator(LogicalKeyboardKey.keyK, meta: true): openSearch,
      SingleActivator(LogicalKeyboardKey.escape): () {
        if (!mounted) return;
        final nav = Navigator.of(context);
        if (nav.canPop()) nav.pop();
      },
      SingleActivator(LogicalKeyboardKey.arrowLeft): () {
        if (!mounted) return;
        if (widget.navigationShell.currentIndex !=
            AppDestination.calendar.branch) {
          return;
        }
        final w = ref.read(calendarStateProvider);
        final step = switch (w.view) {
          CalendarViewKind.month => 30,
          CalendarViewKind.year => 365,
          CalendarViewKind.multiDay => w.dayCount,
          _ => 1,
        };
        ref.read(calendarStateProvider.notifier).shift(-step);
      },
      SingleActivator(LogicalKeyboardKey.arrowRight): () {
        if (!mounted) return;
        if (widget.navigationShell.currentIndex !=
            AppDestination.calendar.branch) {
          return;
        }
        final w = ref.read(calendarStateProvider);
        final step = switch (w.view) {
          CalendarViewKind.month => 30,
          CalendarViewKind.year => 365,
          CalendarViewKind.multiDay => w.dayCount,
          _ => 1,
        };
        ref.read(calendarStateProvider.notifier).shift(step);
      },
      for (var i = 0; i < primary.length && i < _digitKeys.length; i++)
        SingleActivator(_digitKeys[i]): () {
          if (!mounted) return;
          _onDestinationSelected(primary[i]);
        },
    };
  }

  bool _isEditingText() {
    final node = FocusManager.instance.primaryFocus;
    final ctx = node?.context;
    if (ctx == null) return false;
    if (ctx.widget is EditableText) return true;
    if (ctx.findAncestorWidgetOfExactType<EditableText>() != null) return true;
    return false;
  }

  bool _handleGlobalKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (_isEditingText()) return false;
    var handled = false;
    for (final activator in _shortcuts.keys) {
      if (activator.accepts(event, HardwareKeyboard.instance)) {
        _shortcuts[activator]!();
        handled = true;
      }
    }
    return handled;
  }
}
