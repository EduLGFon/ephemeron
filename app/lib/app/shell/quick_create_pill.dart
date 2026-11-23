// Centered floating quick-create pill. Tap expands an inline textbox with
// entity, priority and date/time selectors. Creation reuses the quick-add
// repositories and parser so behavior stays at parity with the sheet.
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/design/tokens.dart';
import '../../core/time/picker_memory.dart';
import '../../core/ui/app_feedback.dart';
import '../../data/drift/app_database.dart';
import '../../domain/parsing/quick_add_parser.dart';
import '../../features/calendar/application/calendar_providers.dart';
import '../../features/countdowns/application/countdowns_providers.dart';
import '../../features/habits/application/habits_providers.dart';
import '../../features/settings/application/settings_providers.dart';
import '../../features/tasks/application/tasks_providers.dart';
import '../../features/tasks/presentation/quick_add_strings.dart';

/// Shell-level signal to open the pill. Increment to request open.
final quickCreatePillRequestProvider = StateProvider<int>((ref) => 0);

enum QuickCreateKind { task, event, habit, countdown }

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
  QuickCreateKind _kind = _lastKind;
  QuickAddParsed? _parsed;
  DateTime? _pickedDate;
  TimeOfDay? _pickedTime;
  String? _selectedListId;
  int _priority = 0; // visual 0-4, 0 none

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
      if (clear) {
        _controller.clear();
        _parsed = null;
        _pickedDate = null;
        _pickedTime = null;
        _priority = 0;
        _selectedListId = null;
      }
    });
  }

  void _onChanged(String value) {
    setState(() {
      _parsed = value.trim().isEmpty ? null : parseQuickAdd(value);
    });
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

  int get _effectivePriority {
    if (_priority > 0) return 5 - _priority;
    return _parsed?.priority ?? 0;
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
    try {
      switch (_kind) {
        case QuickCreateKind.task:
          await _createTask(parsed);
        case QuickCreateKind.event:
          await _createEvent(parsed);
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

  Future<void> _createEvent(QuickAddParsed parsed) async {
    final calendars = await ref.read(calendarsProvider.future);
    final writable = calendars
        .where((c) => c.deletedAt == null && !c.readOnly)
        .toList();
    final start = _eventStartFor(DateTime.now(), _effectiveDue);
    if (writable.isEmpty) return;
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
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          constraints: BoxConstraints(maxWidth: _expanded ? 560 : 220),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(DsRadius.pill),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: _expanded
                ? _buildExpanded(context, scheme, canSubmit)
                : _buildCollapsed(context, scheme),
          ),
        ),
      ),
    );
  }

  Widget _buildCollapsed(BuildContext context, ColorScheme scheme) {
    return InkWell(
      key: const ValueKey<String>('quick-create-pill'),
      borderRadius: BorderRadius.circular(DsRadius.pill),
      onTap: _open,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add, size: 20, color: scheme.primary),
            const SizedBox(width: 8),
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
    );
  }

  Widget _buildExpanded(
    BuildContext context,
    ColorScheme scheme,
    bool canSubmit,
  ) {
    final strings = QuickAddStrings.of(context);
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final screenHeight = MediaQuery.sizeOf(context).height;
    final topPadding = MediaQuery.paddingOf(context).top;
    final maxHeight = (screenHeight - viewInsets.bottom - topPadding - 96)
        .clamp(160.0, 420.0);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
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
                    icon: const Icon(Icons.close, size: 18),
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
                        : const Icon(Icons.arrow_upward, size: 18),
                    onPressed: canSubmit ? _save : null,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final kind in QuickCreateKind.values)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          key: ValueKey<String>(
                            'quick-create-kind-${kind.name}',
                          ),
                          tooltip: _kindLabel(strings, kind),
                          label: Text(_kindLabel(strings, kind)),
                          selected: _kind == kind,
                          onSelected: (_) => setState(() {
                            _kind = kind;
                            _lastKind = kind;
                          }),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                  ],
                ),
              ),
              if (_kind != QuickCreateKind.habit) ...[
                const SizedBox(height: 6),
                SizedBox(
                  height: 34,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _miniChip(
                        label: strings.today,
                        selected: _isToday(_effectiveDue),
                        onTap: () =>
                            setState(() => _pickedDate = DateTime.now()),
                      ),
                      _miniChip(
                        label: strings.tomorrow,
                        selected: _isTomorrow(_effectiveDue),
                        onTap: () => setState(
                          () => _pickedDate = DateTime.now().add(
                            const Duration(days: 1),
                          ),
                        ),
                      ),
                      _miniChip(
                        label: strings.pickDate,
                        selected:
                            _pickedDate != null &&
                            !_isToday(_effectiveDue) &&
                            !_isTomorrow(_effectiveDue),
                        onTap: _pickDate,
                        icon: Icons.calendar_month_outlined,
                      ),
                      _miniChip(
                        label: _pickedTime == null
                            ? 'Time'
                            : _pickedTime!.format(context),
                        selected: _pickedTime != null,
                        onTap: _pickTime,
                        icon: Icons.schedule,
                      ),
                    ],
                  ),
                ),
              ],
              if (_kind == QuickCreateKind.task) ...[
                const SizedBox(height: 6),
                SizedBox(
                  height: 34,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (var v = 0; v <= 4; v++)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            key: ValueKey<String>('quick-create-prio-$v'),
                            avatar: v == 0
                                ? null
                                : Icon(
                                    Icons.flag,
                                    size: 14,
                                    color: _priorityColor(v),
                                  ),
                            label: Text(v == 0 ? strings.priorityNone : 'P$v'),
                            selected: _priority == v,
                            onSelected: (_) => setState(() => _priority = v),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                    ],
                  ),
                ),
                _buildListSelector(strings),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListSelector(QuickAddStrings strings) {
    final lists = (ref.watch(taskListsProvider).value ?? const <TaskList>[])
        .where((list) => list.deletedAt == null)
        .toList(growable: false);
    if (lists.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: SizedBox(
        height: 34,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            for (final list in lists)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  key: ValueKey<String>('quick-create-list-${list.id}'),
                  label: Text(list.name),
                  selected: _selectedListId == list.id,
                  onSelected: (_) => setState(() {
                    _selectedListId = _selectedListId == list.id
                        ? null
                        : list.id;
                  }),
                  visualDensity: VisualDensity.compact,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _miniChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    IconData? icon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        avatar: icon == null ? null : Icon(icon, size: 14),
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  static Color _priorityColor(int visual) => switch (visual) {
    1 => const Color(0xFFD32F2F),
    2 => const Color(0xFFF57C00),
    3 => const Color(0xFFFBC02D),
    4 => const Color(0xFF388E3C),
    _ => Colors.grey,
  };

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
