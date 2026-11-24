part of '../quick_add_sheet.dart';

/// Date shortcuts shown in the vertical date wheel.
enum _QuickAddDate { today, tomorrow, pickDate }

mixin _QuickAddSections on _QuickAddSheetStateBase {
  void _onChanged(String value);
  void _setText(String text);
  Future<void> _save({required bool another});

  void _selectKind(_QuickAddKind kind) {
    if (_kind == kind) return;
    setState(() => _kind = kind);
  }

  void _selectList(String? id) {
    setState(() => _selectedListId = id);
  }

  _QuickAddDate? get _selectedDateChoice {
    if (_isToday(_effectiveDue)) return _QuickAddDate.today;
    if (_isTomorrow(_effectiveDue)) return _QuickAddDate.tomorrow;
    if (_isPickedOtherDay) return _QuickAddDate.pickDate;
    return null;
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
    _saver?.changed(_snapshot);
  }

  Future<void> _pickDate(QuickAddStrings strings) async {
    final now = DateTime.now();
    final initial = _effectiveDue ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 10, 12, 31),
      helpText: strings.pickDateHelp,
    );
    if (picked == null || !mounted) return;
    _setPickedDate(picked);
  }

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
      text = appendQuickAddShorthand(text, '-p$visual');
    }
    if (text == _controller.text) return;
    _setText(text);
  }

  void _close() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final strings = QuickAddStrings.of(context);
    final lists = (ref.watch(taskListsProvider).value ?? const <TaskList>[])
        .where((list) => list.deletedAt == null)
        .toList(growable: false);
    final parsed = _parsed;
    final canSubmit =
        !_busy && parsed != null && parsed.title.trim().isNotEmpty;
    final bottomInset = widget.isDialog
        ? 0.0
        : MediaQuery.viewInsetsOf(context).bottom;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AppSheetHeader(
          title: strings.title,
          actions: <Widget>[
            AppIconButton(
              icon: Icons.close_rounded,
              tooltip: strings.close,
              semanticLabel: strings.close,
              onPressed: _close,
            ),
          ],
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              DsSpace.x16,
              0,
              DsSpace.x16,
              DsSpace.x16 + bottomInset,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                AppTextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  autofocus: true,
                  hintText: _kind.hint(strings),
                  textInputAction: TextInputAction.done,
                  prefixIcon: Icon(_kind.icon, size: DsIcon.sm),
                  onChanged: _onChanged,
                  onSubmitted: (_) => _save(another: false),
                ),
                const SizedBox(height: DsSpace.x8),
                _QuickAddPreview(
                  parsed: parsed,
                  kind: _kind,
                  pickedDate: _pickedDate,
                  selectedListId: _selectedListId,
                  lists: lists,
                ),
                const SizedBox(height: DsSpace.x12),
                _WheelGroup<_QuickAddKind>(
                  label: strings.sectionType,
                  items: <WheelItem<_QuickAddKind>>[
                    for (final kind in _QuickAddKind.values)
                      WheelItem<_QuickAddKind>(
                        value: kind,
                        label: kind.label(strings),
                        icon: kind.icon,
                        key: ValueKey('quick-add-kind-${kind.name}'),
                      ),
                  ],
                  value: _kind,
                  onChanged: _selectKind,
                ),
                if (_kind != _QuickAddKind.habit) ...<Widget>[
                  const SizedBox(height: DsSpace.x12),
                  _WheelGroup<_QuickAddDate?>(
                    label: strings.sectionDate,
                    items: <WheelItem<_QuickAddDate?>>[
                      WheelItem<_QuickAddDate?>(
                        value: _QuickAddDate.today,
                        label: strings.today,
                        icon: Icons.today_outlined,
                        key: const ValueKey('quick-add-date-today'),
                      ),
                      WheelItem<_QuickAddDate?>(
                        value: _QuickAddDate.tomorrow,
                        label: strings.tomorrow,
                        icon: Icons.event_available_outlined,
                        key: const ValueKey('quick-add-date-tomorrow'),
                      ),
                      WheelItem<_QuickAddDate?>(
                        value: _QuickAddDate.pickDate,
                        label: strings.pickDate,
                        icon: Icons.calendar_month_outlined,
                        key: const ValueKey('quick-add-date-pickDate'),
                      ),
                    ],
                    value: _selectedDateChoice,
                    onChanged: (choice) {
                      switch (choice) {
                        case _QuickAddDate.today:
                          _setPickedDate(DateTime.now());
                        case _QuickAddDate.tomorrow:
                          _setPickedDate(
                            DateTime.now().add(const Duration(days: 1)),
                          );
                        case _QuickAddDate.pickDate:
                          _pickDate(strings);
                        case null:
                          break;
                      }
                    },
                  ),
                ],
                if (_kind == _QuickAddKind.task &&
                    lists.isNotEmpty) ...<Widget>[
                  const SizedBox(height: DsSpace.x12),
                  _WheelGroup<String?>(
                    label: strings.sectionList,
                    items: <WheelItem<String?>>[
                      WheelItem<String?>(
                        value: null,
                        label: 'No list',
                        key: const ValueKey('quick-add-list-none'),
                      ),
                      for (final list in lists)
                        WheelItem<String?>(
                          value: list.id,
                          label: list.name,
                          color: _listColor(list),
                          key: ValueKey('quick-add-list-${list.id}'),
                        ),
                    ],
                    value: _selectedListId,
                    onChanged: (id) => _selectList(id),
                  ),
                ],
                if (_kind == _QuickAddKind.task) ...<Widget>[
                  const SizedBox(height: DsSpace.x12),
                  _WheelGroup<int>(
                    label: strings.sectionPriority,
                    items: <WheelItem<int>>[
                      WheelItem<int>(
                        value: 0,
                        label: strings.priorityNone,
                        icon: Icons.flag_outlined,
                        showLabel: false,
                        key: const ValueKey('quick-add-priority-0'),
                      ),
                      for (var visual = 1; visual <= 4; visual++)
                        WheelItem<int>(
                          value: visual,
                          label: strings.priorityLabel(visual),
                          icon: Icons.flag,
                          color: styleForVisualPriority(visual).color,
                          showLabel: false,
                          key: ValueKey('quick-add-priority-$visual'),
                        ),
                    ],
                    value: _visualPriority,
                    onChanged: _setPriority,
                  ),
                ],
                const SizedBox(height: DsSpace.x24),
                _buildActions(context, strings, canSubmit),
              ],
            ),
          ),
        ),
      ],
    );
  }

  int get _visualPriority {
    final priority = _parsed?.priority ?? 0;
    return priority == 0 ? 0 : 5 - priority;
  }

  bool get _isPickedOtherDay {
    final picked = _pickedDate;
    return picked != null && !_isToday(picked) && !_isTomorrow(picked);
  }

  bool _isToday(DateTime? date) => _isDay(date, DateTime.now());

  bool _isTomorrow(DateTime? date) =>
      _isDay(date, DateTime.now().add(const Duration(days: 1)));

  bool _isDay(DateTime? date, DateTime day) {
    if (date == null) return false;
    return date.year == day.year &&
        date.month == day.month &&
        date.day == day.day;
  }

  Color? _listColor(TaskList list) {
    final raw = list.color;
    if (raw == null || !isValidHex(raw)) return null;
    return parseHex(raw);
  }

  Widget _buildActions(
    BuildContext context,
    QuickAddStrings strings,
    bool canSubmit,
  ) {
    final primary = AppButton(
      label: _kind.addLabel(strings),
      icon: Icons.add,
      busy: _busy,
      expand: true,
      onPressed: canSubmit ? () => _save(another: false) : null,
    );
    final another = AppButton(
      label: strings.addAnother,
      variant: AppButtonVariant.secondary,
      expand: true,
      onPressed: canSubmit ? () => _save(another: true) : null,
    );
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final stack = MediaQuery.sizeOf(context).width < 420 || scale > 1.4;
    if (stack) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          primary,
          const SizedBox(height: DsSpace.x8),
          another,
        ],
      );
    }
    return Row(
      children: <Widget>[
        Expanded(child: primary),
        const SizedBox(width: DsSpace.x8),
        Expanded(child: another),
      ],
    );
  }
}
