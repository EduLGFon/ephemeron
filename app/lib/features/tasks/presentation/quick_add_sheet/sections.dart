part of '../quick_add_sheet.dart';

mixin _QuickAddSections on _QuickAddSheetStateBase {
  void _onChanged(String value);
  void _setText(String text);
  Future<void> _save({required bool another});

  void _selectKind(_QuickAddKind kind) {
    if (_kind == kind) return;
    setState(() => _kind = kind);
  }

  void _toggleList(String id) {
    setState(() => _selectedListId = _selectedListId == id ? null : id);
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
                _ChipGroup(
                  label: strings.sectionType,
                  children: <Widget>[
                    for (final kind in _QuickAddKind.values)
                      AppChip(
                        label: kind.label(strings),
                        icon: kind.icon,
                        selected: _kind == kind,
                        onTap: () => _selectKind(kind),
                      ),
                  ],
                ),
                if (_kind != _QuickAddKind.habit) ...<Widget>[
                  const SizedBox(height: DsSpace.x12),
                  _ChipGroup(
                    label: strings.sectionDate,
                    children: <Widget>[
                      AppChip(
                        label: strings.today,
                        icon: Icons.today_outlined,
                        selected: _isToday(_effectiveDue),
                        onTap: () => _setPickedDate(DateTime.now()),
                      ),
                      AppChip(
                        label: strings.tomorrow,
                        icon: Icons.event_available_outlined,
                        selected: _isTomorrow(_effectiveDue),
                        onTap: () => _setPickedDate(
                          DateTime.now().add(const Duration(days: 1)),
                        ),
                      ),
                      AppChip(
                        label: strings.pickDate,
                        icon: Icons.calendar_month_outlined,
                        selected: _isPickedOtherDay,
                        onTap: () => _pickDate(strings),
                      ),
                    ],
                  ),
                ],
                if (_kind == _QuickAddKind.task &&
                    lists.isNotEmpty) ...<Widget>[
                  const SizedBox(height: DsSpace.x12),
                  _ChipGroup(
                    label: strings.sectionList,
                    children: <Widget>[
                      for (final list in lists)
                        AppChip(
                          label: list.name,
                          color: _listColor(list),
                          selected: _selectedListId == list.id,
                          onTap: () => _toggleList(list.id),
                        ),
                    ],
                  ),
                ],
                if (_kind == _QuickAddKind.task) ...<Widget>[
                  const SizedBox(height: DsSpace.x12),
                  _ChipGroup(
                    label: strings.sectionPriority,
                    children: <Widget>[
                      AppChip(
                        label: strings.priorityNone,
                        selected: _visualPriority == 0,
                        onTap: () => _setPriority(0),
                      ),
                      for (var visual = 1; visual <= 4; visual++)
                        AppChip(
                          label: strings.priorityLabel(visual),
                          selected: _visualPriority == visual,
                          onTap: () => _setPriority(visual),
                        ),
                    ],
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
