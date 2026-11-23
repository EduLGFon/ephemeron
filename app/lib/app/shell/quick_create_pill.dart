// Centered floating quick-create pill. Tap expands an inline textbox with
// entity, priority and date/time selectors. Creation reuses the quick-add
// repositories and parser so behavior stays at parity with the sheet.
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/design/components/app_wheel.dart';
import '../../core/design/tokens.dart';
import '../../core/time/picker_memory.dart';
import '../../core/ui/app_feedback.dart';
import '../../data/drift/app_database.dart';
import '../../domain/parsing/quick_add_parser.dart';
import '../../features/calendar/application/calendar_providers.dart';
import '../../features/calendar/presentation/event_editor_sheet.dart';
import '../../features/countdowns/application/countdowns_providers.dart';
import '../../features/habits/application/habits_providers.dart';
import '../../features/settings/application/settings_providers.dart';
import '../../features/tasks/application/tasks_providers.dart';
import '../../features/tasks/presentation/quick_add_strings.dart';

/// Shell-level signal to open the pill. Increment to request open.
final quickCreatePillRequestProvider = StateProvider<int>((ref) => 0);

enum QuickCreateKind { task, event, habit, countdown }

/// Icons mirror the quick-add sheet so both entry points read the same way.
extension _QuickCreateKindView on QuickCreateKind {
  IconData get icon => switch (this) {
    QuickCreateKind.task => Icons.task_alt,
    QuickCreateKind.event => Icons.event_outlined,
    QuickCreateKind.habit => Icons.repeat,
    QuickCreateKind.countdown => Icons.timer_outlined,
  };
}

/// Date shortcuts shown in the pill's vertical date wheel.
enum _PillDate { today, tomorrow, pickDate }

class QuickCreatePill extends ConsumerStatefulWidget {
  const QuickCreatePill({super.key});

  @override
  ConsumerState<QuickCreatePill> createState() => _QuickCreatePillState();
}

class _QuickCreatePillState extends ConsumerState<QuickCreatePill> {
  static QuickCreateKind _lastKind = QuickCreateKind.task;

  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _expanded = false;
  bool _busy = false;
  bool _fullscreen = false;
  double _dragDy = 0;
  QuickCreateKind _kind = _lastKind;
  QuickAddParsed? _parsed;
  DateTime? _pickedDate;
  TimeOfDay? _pickedTime;
  String? _selectedListId;

  @override
  void initState() {
    super.initState();
    _kind = _lastKind;
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _open() {
    if (_expanded) {
      _focusNode.requestFocus();
      return;
    }
    setState(() => _expanded = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  void _close({bool clear = false}) {
    if (!_expanded && !clear) return;
    setState(() {
      _expanded = false;
      _busy = false;
      _fullscreen = false;
      _dragDy = 0;
      if (clear) {
        _controller.clear();
        _parsed = null;
        _pickedDate = null;
        _pickedTime = null;
        _selectedListId = null;
      }
    });
  }

  void _onChanged(String value) {
    setState(() {
      _parsed = value.trim().isEmpty ? null : parseQuickAdd(value);
    });
  }

  /// Switching the entity never clears the typed text; only the active kind
  /// (and the remembered default) changes.
  void _selectKind(QuickCreateKind kind) {
    if (_kind == kind) return;
    setState(() {
      _kind = kind;
      _lastKind = kind;
    });
  }

  _PillDate? get _selectedDateChoice {
    if (_isToday(_effectiveDue)) return _PillDate.today;
    if (_isTomorrow(_effectiveDue)) return _PillDate.tomorrow;
    if (_isPickedOtherDay) return _PillDate.pickDate;
    return null;
  }

  bool get _isPickedOtherDay {
    final picked = _pickedDate;
    return picked != null && !_isToday(picked) && !_isTomorrow(picked);
  }

  void _setPickedDate(DateTime date) {
    final current = _effectiveDue;
    setState(() {
      _pickedDate = DateTime(
        date.year,
        date.month,
        date.day,
        current?.hour ?? 0,
        current?.minute ?? 0,
      );
    });
  }

  void _selectDate(_PillDate? choice) {
    switch (choice) {
      case _PillDate.today:
        _setPickedDate(DateTime.now());
      case _PillDate.tomorrow:
        _setPickedDate(DateTime.now().add(const Duration(days: 1)));
      case _PillDate.pickDate:
        unawaited(_pickDate());
      case null:
        break;
    }
  }

  DateTime? get _effectiveDue {
    final base = _pickedDate ?? _parsed?.due;
    if (base == null) return null;
    final time = _pickedTime;
    if (time != null) {
      return DateTime(base.year, base.month, base.day, time.hour, time.minute);
    }
    if (_pickedDate != null && _parsed?.due != null) {
      final p = _parsed!.due!;
      if (p.hour != 0 || p.minute != 0) {
        return DateTime(base.year, base.month, base.day, p.hour, p.minute);
      }
    }
    return base;
  }

  /// Visual priority (0 none, 1 = P1 .. 4 = P4) is derived from the parsed
  /// "-pN" token, the same way quick_add_sheet derives its wheel value. The
  /// typed text stays the single source of truth, so the wheel can never
  /// disagree with the priority that will actually be saved.
  int get _visualPriority {
    final priority = _parsed?.priority ?? 0;
    return priority == 0 ? 0 : 5 - priority;
  }

  int get _effectivePriority => _parsed?.priority ?? 0;

  /// Rewrites the "-pN" token to [visual] (0 clears it) and reparses. Selecting
  /// None therefore removes the parsed priority instead of only hiding a
  /// separate wheel state, so the effective priority becomes None as well.
  void _setPriority(int visual) {
    final pattern = RegExp(
      r'(?<![\p{L}\p{N}_-])-p[1-4](?![\p{L}\p{N}_-])',
      unicode: true,
      caseSensitive: false,
    );
    var text = _controller.text
        .replaceAll(pattern, ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (visual > 0) {
      text = text.isEmpty ? '-p$visual' : '$text -p$visual';
    }
    if (text == _controller.text) return;
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    _onChanged(text);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initial = _effectiveDue ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 10, 12, 31),
    );
    if (picked == null || !mounted) return;
    setState(() => _pickedDate = picked);
  }

  Future<void> _pickTime() async {
    final initial =
        _pickedTime ?? TimeOfDay.fromDateTime(_effectiveDue ?? DateTime.now());
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null || !mounted) return;
    setState(() => _pickedTime = picked);
  }

  Future<void> _save() async {
    if (_busy) return;
    final parsed = _parsed;
    if (parsed == null || parsed.title.trim().isEmpty) return;
    final strings = QuickAddStrings.of(context);
    setState(() => _busy = true);
    var openedEditor = false;
    try {
      switch (_kind) {
        case QuickCreateKind.task:
          await _createTask(parsed);
        case QuickCreateKind.event:
          openedEditor = await _createEvent(parsed);
        case QuickCreateKind.habit:
          await _createHabit(parsed);
        case QuickCreateKind.countdown:
          await _createCountdown(parsed);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.maybeOf(context)
          ?.showSnackBar(SnackBar(content: Text(strings.saveFailed)));
      return;
    }
    if (!mounted) return;
    _lastKind = _kind;
    if (openedEditor) {
      _close(clear: true);
      return;
    }
    AppFeedback.success();
    _close(clear: true);
  }

  Future<void> _createTask(QuickAddParsed parsed) async {
    final repo = ref.read(taskRepositoryProvider);
    final listId = await _resolveTaskList(parsed);
    final due = _effectiveDue;
    await repo.createTask(
      title: parsed.title,
      listId: listId,
      priority: _effectivePriority,
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
        final settings = await ref.read(settingsRepositoryProvider.future);
        await settings.setSelectedTaskListId(listId);
      } catch (_) {}
    }
  }

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
      final settings = await ref.read(settingsRepositoryProvider.future);
      final last = settings.selectedTaskListId;
      if (last != null &&
          lists.any((l) => l.id == last && l.deletedAt == null)) {
        return last;
      }
    } catch (_) {}
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
      if (!mounted) return true;
      await showEventEditor(
        context,
        initialStart: start,
        restoredDraft: <String, dynamic>{'title': parsed.title},
      );
      return true;
    }
    final settings = await ref.read(settingsRepositoryProvider.future);
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
    } catch (_) {}
    return false;
  }

  Future<void> _createHabit(QuickAddParsed parsed) async {
    await ref
        .read(habitRepositoryProvider)
        .createHabit(
          name: parsed.title,
          frequency: 'daily',
          startDate: formatYmd(DateTime.now()),
        );
  }

  Future<void> _createCountdown(QuickAddParsed parsed) async {
    final target =
        _effectiveDue ?? DateTime.now().add(const Duration(days: 30));
    await ref
        .read(countdownRepositoryProvider)
        .createCountdown(title: parsed.title, targetDate: formatYmd(target));
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(quickCreatePillRequestProvider, (_, _) => _open());
    final scheme = Theme.of(context).colorScheme;
    final canSubmit =
        !_busy && _parsed != null && _parsed!.title.trim().isNotEmpty;
    return _expanded
        ? _buildExpandedLayer(context, scheme, canSubmit)
        : _buildCollapsed(context, scheme);
  }

  Widget _buildCollapsed(BuildContext context, ColorScheme scheme) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: DsSpace.x16),
        child: AnimatedContainer(
          duration: DsMotion.normal,
          curve: DsMotion.standard,
          constraints: const BoxConstraints(maxWidth: 220),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(DsRadius.pill),
            // An outline (not outlineVariant) keeps the capsule edge legible
            // on both light and dark surfaces at large text scales.
            border: Border.all(color: scheme.outline),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: scheme.shadow.withValues(alpha: 0.14),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              key: const ValueKey<String>('quick-create-pill'),
              borderRadius: BorderRadius.circular(DsRadius.pill),
              onTap: _open,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Icon(Icons.add, size: DsIcon.md, color: scheme.primary),
                    const SizedBox(width: DsSpace.x8),
                    Flexible(
                      child: Text(
                        'Quick create',
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelLarge
                            ?.copyWith(color: scheme.onSurface),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Expanded pill: a full-bleed dismiss barrier with the card floating above
  /// it. Both live inside the shell route, so any entity sheet pushed later
  /// paints on top of the pill (N8); no separate high overlay is created.
  Widget _buildExpandedLayer(
    BuildContext context,
    ColorScheme scheme,
    bool canSubmit,
  ) {
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final topPadding = MediaQuery.paddingOf(context).top;
    final available =
        MediaQuery.sizeOf(context).height - viewInsets.bottom - topPadding;
    final maxHeight = _fullscreen
        ? available
        : (available - 96).clamp(160.0, 420.0);
    return Stack(
      key: const ValueKey<String>('quick-create-layer'),
      children: <Widget>[
        Positioned.fill(
          child: GestureDetector(
            key: const ValueKey<String>('quick-create-barrier'),
            behavior: HitTestBehavior.opaque,
            onTap: () => _close(),
          ),
        ),
        Align(
          alignment: _fullscreen ? Alignment.topCenter : Alignment.bottomCenter,
          child: Padding(
            padding: EdgeInsets.only(
              left: DsSpace.x16,
              right: DsSpace.x16,
              top: _fullscreen ? topPadding : 0,
              bottom: _fullscreen ? 0 : DsSpace.x8,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 560, maxHeight: maxHeight),
              child: _buildExpandedCard(
                context,
                scheme,
                canSubmit,
                fullscreenHeight: _fullscreen ? available : null,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExpandedCard(
    BuildContext context,
    ColorScheme scheme,
    bool canSubmit, {
    double? fullscreenHeight,
  }) {
    return Material(
      type: MaterialType.transparency,
      child: AnimatedContainer(
        key: const ValueKey<String>('quick-create-card'),
        duration: DsMotion.normal,
        curve: DsMotion.standard,
        // In fullscreen the card fills the available height; the Flexible
        // selector area absorbs the extra space instead of leaving a gap.
        constraints: fullscreenHeight == null
            ? null
            : BoxConstraints(minHeight: fullscreenHeight),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(DsRadius.r24),
          border: Border.all(color: scheme.outline),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: scheme.shadow.withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _buildDragHandle(context),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                DsSpace.x12,
                0,
                DsSpace.x8,
                10,
              ),
              child: _buildInputRow(context, scheme, canSubmit),
            ),
            Flexible(
              child: SingleChildScrollView(
                child: _buildSelectors(context, scheme),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDragHandle(BuildContext context) {
    return Semantics(
      button: true,
      label: _fullscreen ? 'Collapse quick create' : 'Expand quick create',
      child: GestureDetector(
        key: const ValueKey<String>('quick-create-drag-handle'),
        behavior: HitTestBehavior.opaque,
        // Tap-to-toggle keeps the affordance usable without a drag gesture.
        onTap: () => setState(() => _fullscreen = !_fullscreen),
        onVerticalDragStart: (_) => _dragDy = 0,
        onVerticalDragUpdate: (details) => _dragDy += details.delta.dy,
        onVerticalDragEnd: (_) {
          if (_dragDy < -40 && !_fullscreen) {
            setState(() => _fullscreen = true);
          } else if (_dragDy > 40 && _fullscreen) {
            setState(() => _fullscreen = false);
          }
          _dragDy = 0;
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: DsSpace.x8),
          child: Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurfaceVariant
                    .withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(DsRadius.pill),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputRow(
    BuildContext context,
    ColorScheme scheme,
    bool canSubmit,
  ) {
    final strings = QuickAddStrings.of(context);
    return Row(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(right: DsSpace.x8),
          child: Icon(_kind.icon, size: DsIcon.md, color: scheme.primary),
        ),
        Expanded(
          child: TextField(
            key: const ValueKey<String>('quick-create-input'),
            controller: _controller,
            focusNode: _focusNode,
            onChanged: _onChanged,
            onSubmitted: (_) => _save(),
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              isDense: true,
              border: InputBorder.none,
              hintText: _hint(strings),
            ),
          ),
        ),
        IconButton(
          key: const ValueKey<String>('quick-create-close'),
          icon: const Icon(Icons.close, size: DsIcon.sm),
          onPressed: () => _close(),
          tooltip: strings.close,
          visualDensity: VisualDensity.compact,
        ),
        IconButton.filled(
          key: const ValueKey<String>('quick-create-submit'),
          icon: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.arrow_upward, size: DsIcon.sm),
          onPressed: canSubmit ? _save : null,
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }

  /// Selector wheels sit side by side around the input, each with its icon
  /// above the label and a vertical [WheelSelector] below, so every option
  /// stays visible without wrapping.
  Widget _buildSelectors(BuildContext context, ColorScheme scheme) {
    final strings = QuickAddStrings.of(context);
    final brightness = Theme.of(context).brightness;
    final lists = (ref.watch(taskListsProvider).value ?? const <TaskList>[])
        .where((list) => list.deletedAt == null)
        .toList(growable: false);
    final flagStyle = styleForVisualPriority(_visualPriority);
    final columns = <Widget>[
      _wheelColumn(
        iconKey: const ValueKey<String>('quick-create-kind-icon'),
        label: strings.sectionType,
        icon: _kind.icon,
        iconColor: scheme.primary,
        wheel: WheelSelector<QuickCreateKind>(
          items: <WheelItem<QuickCreateKind>>[
            for (final kind in QuickCreateKind.values)
              WheelItem<QuickCreateKind>(
                value: kind,
                label: _kindLabel(strings, kind),
                icon: kind.icon,
                key: ValueKey<String>('quick-create-kind-${kind.name}'),
              ),
          ],
          value: _kind,
          onChanged: _selectKind,
          itemExtent: 40,
          height: 160,
          semanticsLabel: strings.sectionType,
        ),
      ),
    ];
    if (_kind != QuickCreateKind.habit) {
      columns.add(
        _wheelColumn(
          iconKey: const ValueKey<String>('quick-create-date-icon'),
          label: strings.sectionDate,
          icon: Icons.calendar_month_outlined,
          iconColor: scheme.primary,
          wheel: WheelSelector<_PillDate?>(
            items: <WheelItem<_PillDate?>>[
              WheelItem<_PillDate?>(
                value: _PillDate.today,
                label: strings.today,
                icon: Icons.today_outlined,
                key: const ValueKey<String>('quick-create-date-today'),
              ),
              WheelItem<_PillDate?>(
                value: _PillDate.tomorrow,
                label: strings.tomorrow,
                icon: Icons.event_available_outlined,
                key: const ValueKey<String>('quick-create-date-tomorrow'),
              ),
              WheelItem<_PillDate?>(
                value: _PillDate.pickDate,
                label: strings.pickDate,
                icon: Icons.calendar_month_outlined,
                key: const ValueKey<String>('quick-create-date-pick'),
              ),
            ],
            value: _selectedDateChoice,
            onChanged: _selectDate,
            itemExtent: 40,
            height: 120,
            semanticsLabel: strings.sectionDate,
          ),
          footer: TextButton.icon(
            key: const ValueKey<String>('quick-create-time'),
            onPressed: _pickTime,
            icon: const Icon(Icons.schedule, size: DsIcon.sm),
            label: Text(
              _pickedTime == null ? 'Time' : _pickedTime!.format(context),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      );
    }
    if (_kind == QuickCreateKind.task) {
      columns.add(
        _wheelColumn(
          iconKey: const ValueKey<String>('quick-create-prio-icon'),
          label: strings.sectionPriority,
          icon: flagStyle.icon,
          iconColor: flagStyle.foreground(brightness),
          wheel: WheelSelector<int>(
            items: <WheelItem<int>>[
              for (var visual = 0; visual <= 4; visual++)
                WheelItem<int>(
                  value: visual,
                  label: visual == 0
                      ? strings.priorityNone
                      : strings.priorityLabel(visual),
                  icon: styleForVisualPriority(visual).icon,
                  color: visual == 0
                      ? null
                      : styleForVisualPriority(visual).color,
                  key: ValueKey<String>('quick-create-prio-$visual'),
                ),
            ],
            value: _visualPriority,
            onChanged: _setPriority,
            itemExtent: 40,
            height: 200,
            semanticsLabel: strings.sectionPriority,
          ),
        ),
      );
      if (lists.isNotEmpty) {
        columns.add(
          _wheelColumn(
            iconKey: const ValueKey<String>('quick-create-list-icon'),
            label: strings.sectionList,
            icon: Icons.list_alt_outlined,
            iconColor: scheme.primary,
            wheel: WheelSelector<String?>(
              items: <WheelItem<String?>>[
                WheelItem<String?>(
                  value: null,
                  label: 'No list',
                  key: const ValueKey<String>('quick-create-list-none'),
                ),
                for (final list in lists)
                  WheelItem<String?>(
                    value: list.id,
                    label: list.name,
                    key: ValueKey<String>('quick-create-list-${list.id}'),
                  ),
              ],
              value: _selectedListId,
              onChanged: (id) => setState(() {
                _selectedListId = _selectedListId == id ? null : id;
              }),
              itemExtent: 40,
              height: 160,
              semanticsLabel: strings.sectionList,
            ),
          ),
        );
      }
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DsSpace.x12,
        0,
        DsSpace.x12,
        DsSpace.x8,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            for (var i = 0; i < columns.length; i++) ...<Widget>[
              if (i > 0) const SizedBox(width: DsSpace.x8),
              columns[i],
            ],
          ],
        ),
      ),
    );
  }

  Widget _wheelColumn({
    required Key iconKey,
    required IconData icon,
    required Color iconColor,
    required String label,
    required Widget wheel,
    Widget? footer,
  }) {
    return SizedBox(
      width: 104,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Icon(icon, key: iconKey, size: DsIcon.md, color: iconColor),
          const SizedBox(height: DsSpace.x4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: (Theme.of(context).textTheme.labelSmall ?? const TextStyle())
                .copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: DsSpace.x4),
          wheel,
          ?footer,
        ],
      ),
    );
  }

  String _kindLabel(QuickAddStrings strings, QuickCreateKind kind) =>
      switch (kind) {
        QuickCreateKind.task => strings.typeTask,
        QuickCreateKind.event => strings.typeEvent,
        QuickCreateKind.habit => strings.typeHabit,
        QuickCreateKind.countdown => strings.typeCountdown,
      };

  String _hint(QuickAddStrings strings) => switch (_kind) {
    QuickCreateKind.task => strings.fieldHintTask,
    QuickCreateKind.event => strings.fieldHintEvent,
    QuickCreateKind.habit => strings.fieldHintHabit,
    QuickCreateKind.countdown => strings.fieldHintCountdown,
  };

  bool _isToday(DateTime? d) => _isDay(d, DateTime.now());
  bool _isTomorrow(DateTime? d) =>
      _isDay(d, DateTime.now().add(const Duration(days: 1)));
  bool _isDay(DateTime? d, DateTime day) =>
      d != null &&
      d.year == day.year &&
      d.month == day.month &&
      d.day == day.day;
}

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
