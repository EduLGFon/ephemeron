part of '../task_editor_sheet.dart';

mixin _TaskEditorSections on _TaskEditorStateBase {
  void _queueDraft();
  Widget _dateRow(
    BuildContext context, {
    required String label,
    required String? value,
    required ValueChanged<String?> onChanged,
    required String pickerKey,
  });
  String _fmtDue(DateTime d);
  bool get _isMicrosoftTask;
  Future<void> _save();
  Widget _plannedIntervalSection(BuildContext context);
  Widget _repeatSection(BuildContext context);
  String _pad(int v);
  DateTime _nextWeekday(DateTime now, int weekday);
  @override
  Widget build(BuildContext context) {
    final listsAsync = ref.watch(taskListsProvider);
    return SafeArea(
      child: Padding(
        padding: sheetPadding(context),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _title,
                autofocus: widget.task == null,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _save(),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _notes,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 8),
              listsAsync.maybeWhen(
                data: (lists) {
                  final list = _listId == null
                      ? null
                      : lists.where((l) => l.id == _listId).firstOrNull;
                  final source = list == null
                      ? 'No list'
                      : sourceLabel(
                              name: list.name,
                              account: accountForSource(
                                googleAccount: list.googleAccount,
                                microsoftAccount: list.microsoftAccount,
                              ),
                              isLocal:
                                  list.googleAccount == null &&
                                  list.microsoftAccount == null,
                            ) ??
                            list.name;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.list_alt_outlined),
                    title: Text(source),
                    subtitle: const Text('List source'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_listId != null)
                          IconButton(
                            icon: const Icon(Icons.clear),
                            tooltip: 'No list',
                            onPressed: () {
                              setState(() => _listId = null);
                              _queueDraft();
                            },
                          ),
                        const Icon(Icons.swap_horiz),
                      ],
                    ),
                    onTap: () async {
                      final picked = await showTaskListSourcePicker(
                        context,
                        ref,
                        selectedId: _listId,
                      );
                      if (picked == null) return;
                      setState(() => _listId = picked);
                      _queueDraft();
                    },
                  );
                },
                orElse: () => const SizedBox.shrink(),
              ),
              const SizedBox(height: 8),
              const Text('Priority'),
              const SizedBox(height: 4),
              _PriorityWheel(
                value: _priority,
                onChanged: (value) {
                  setState(() => _priority = value);
                  _queueDraft();
                },
              ),
              const SizedBox(height: 8),
              _dateRow(
                context,
                label: 'Planned date',
                value: _plannedDate,
                pickerKey: PickerMemoryKeys.taskPlannedDate,
                onChanged: (v) {
                  setState(() {
                    _plannedDate = v;
                    if (v != null) {
                      _plannedStart = null;
                      _plannedEnd = null;
                    }
                  });
                  _queueDraft();
                },
              ),
              const SizedBox(height: 8),
              _plannedIntervalSection(context),
              const SizedBox(height: 8),
              _repeatSection(context),
              const SizedBox(height: 8),
              _dateRow(
                context,
                label: 'Due date',
                value: _dueDate,
                pickerKey: PickerMemoryKeys.taskDueDate,
                onChanged: (v) {
                  setState(() => _dueDate = v);
                  _queueDraft();
                },
              ),
              const SizedBox(height: 4),
              _DueWheel(
                value: _dueDate,
                options: <_DueOption>[
                  _DueOption(null, 'No due date'),
                  _DueOption(_fmtDue(DateTime.now()), 'Today'),
                  _DueOption(
                    _fmtDue(DateTime.now().add(const Duration(days: 1))),
                    'Tomorrow',
                  ),
                  _DueOption(
                    _fmtDue(_nextWeekday(DateTime.now(), DateTime.monday)),
                    'Next Mon',
                  ),
                ],
                onChanged: (value) {
                  setState(() => _dueDate = value);
                  _queueDraft();
                },
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _tags,
                decoration: const InputDecoration(
                  labelText: 'Tags (space separated)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _dueTime == null
                          ? 'No time (9:00 reminder)'
                          : 'Time ${_pad(_dueTime! ~/ 60)}:${_pad(_dueTime! % 60)}',
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      SettingsRepository? settings;
                      try {
                        settings = await ref.read(
                          settingsRepositoryProvider.future,
                        );
                      } catch (_) {}
                      if (!context.mounted) return;
                      final minutes = resolvePickerTimeMinutes(
                        currentMinutes: _dueTime,
                        rememberedHhmm: settings?.getPickerTime(
                          PickerMemoryKeys.taskDueTime,
                        ),
                        fallbackMinutes: 540,
                      );
                      final t = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay(
                          hour: minutes ~/ 60,
                          minute: minutes % 60,
                        ),
                      );
                      if (t != null) {
                        final hhmm = formatHhmm(t.hour, t.minute);
                        try {
                          await settings?.setPickerTime(
                            PickerMemoryKeys.taskDueTime,
                            hhmm,
                          );
                        } catch (_) {}
                        setState(() => _dueTime = t.hour * 60 + t.minute);
                        _queueDraft();
                      }
                    },
                    child: const Text('Set time'),
                  ),
                  if (_dueTime != null)
                    IconButton(
                      icon: const Icon(Icons.clear),
                      tooltip: 'Clear time',
                      onPressed: () {
                        setState(() => _dueTime = null);
                        _queueDraft();
                      },
                    ),
                ],
              ),
              const SizedBox(height: 8),
              ReminderPicker(
                offsets: _reminders,
                onChanged: (v) {
                  setState(() => _reminders = v.isEmpty ? const [0] : v);
                  _queueDraft();
                },
              ),
              const SizedBox(height: 8),
              AlarmPresetPicker(
                value: _alarmPreset,
                onChanged: (v) {
                  setState(() => _alarmPreset = v);
                  _queueDraft();
                },
              ),
              const SizedBox(height: 4),
              const Text(
                'Tasks always notify at the due time. The alarm adds a stronger alert.',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                value: _pinned,
                onChanged: (v) {
                  setState(() => _pinned = v);
                  _queueDraft();
                },
                title: const Text('Pinned'),
                contentPadding: EdgeInsets.zero,
              ),
              if (widget.task != null) _SubtaskSection(task: widget.task!),
              FilledButton(
                onPressed: (widget.task != null && _isMicrosoftTask)
                    ? null
                    : _save,
                child: Text(widget.task == null ? 'Create' : 'Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Vertical wheels for the editor. Dart part files cannot add imports and the
// parent library file is outside this unit's ownership, so these use only
// widgets already in scope. The priority palette is the single in-file source
// mirroring priorityFlagStyles in core/design/components/app_wheel.dart; both
// show a label beside each colour so status never depends on colour alone.
class _PriorityOption {
  const _PriorityOption(
    this.value,
    this.label,
    this.color,
    this.icon, {
    required this.lightForeground,
    required this.darkForeground,
  });

  final int value;
  final String label;
  final Color color;
  final IconData icon;
  final Color lightForeground;
  final Color darkForeground;

  Color foreground(Brightness brightness) =>
      brightness == Brightness.dark ? darkForeground : lightForeground;
}

class _DueOption {
  const _DueOption(this.value, this.label);

  final String? value;
  final String label;
}

List<_PriorityOption> _priorityOptions() => const <_PriorityOption>[
  _PriorityOption(
    0,
    'None',
    Color(0xFF9E9E9E),
    Icons.flag_outlined,
    lightForeground: Color(0xFF616161),
    darkForeground: Color(0xFFBDBDBD),
  ),
  _PriorityOption(
    1,
    'P4',
    Color(0xFF388E3C),
    Icons.flag,
    lightForeground: Color(0xFF2E7D32),
    darkForeground: Color(0xFFA5D6A7),
  ),
  _PriorityOption(
    2,
    'P3',
    Color(0xFFFBC02D),
    Icons.flag,
    lightForeground: Color(0xFF8A5A00),
    darkForeground: Color(0xFFFFE082),
  ),
  _PriorityOption(
    3,
    'P2',
    Color(0xFFF57C00),
    Icons.flag,
    lightForeground: Color(0xFFB45309),
    darkForeground: Color(0xFFFFCC80),
  ),
  _PriorityOption(
    4,
    'P1',
    Color(0xFFD32F2F),
    Icons.flag,
    lightForeground: Color(0xFFC62828),
    darkForeground: Color(0xFFEF9A9A),
  ),
];

class _PriorityWheel extends StatelessWidget {
  const _PriorityWheel({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    final options = _priorityOptions();
    return SizedBox(
      height: 48.0 * options.length,
      child: ListView.builder(
        itemExtent: 48,
        itemCount: options.length,
        itemBuilder: (context, index) {
          final option = options[index];
          final selected = option.value == value;
          final fg = option.foreground(brightness);
          return Semantics(
            button: true,
            selected: selected,
            label: option.label,
            child: InkWell(
              key: ValueKey('task-editor-priority-${option.value}'),
              onTap: () => onChanged(option.value),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: selected
                      ? scheme.secondaryContainer
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(option.icon, size: 18, color: fg),
                    const Spacer(),
                    if (selected)
                      Icon(Icons.check, size: 18, color: scheme.primary),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DueWheel extends StatelessWidget {
  const _DueWheel({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String? value;
  final List<_DueOption> options;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 48.0 * options.length,
      child: ListView.builder(
        itemExtent: 48,
        itemCount: options.length,
        itemBuilder: (context, index) {
          final option = options[index];
          final selected = option.value == value;
          return Semantics(
            button: true,
            selected: selected,
            label: option.label,
            child: InkWell(
              key: ValueKey('task-editor-due-$index'),
              onTap: () => onChanged(option.value),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: selected
                      ? scheme.secondaryContainer
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.event_outlined, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(option.label)),
                    if (selected)
                      Icon(Icons.check, size: 18, color: scheme.primary),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
