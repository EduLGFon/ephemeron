part of '../quick_add_sheet.dart';

mixin _QuickAddLifecycle on _QuickAddSheetStateBase {
  @override
  void initState() {
    super.initState();
    final restored = widget.restoredDraft?['text'] as String?;
    final initial = widget.initialText ?? restored ?? '';
    if (initial.isNotEmpty) {
      _controller.text = initial;
      _parsed = parseQuickAdd(initial);
    }
    if (restored == null) {
      // Preload a leftover draft for fresh opens (e.g. dismissed sheet).
      Future.microtask(_preloadDraft);
    }
  }

  Future<void> _preloadDraft() async {
    if (!mounted || _controller.text.isNotEmpty) return;
    try {
      final draft = await ref.read(draftStoreProvider).load('quick_add', null);
      if (draft == null || !mounted || _controller.text.isNotEmpty) return;
      final text = draft.json['text'] as String?;
      if (text == null || text.isEmpty) return;
      if (draftIsExpired(
        draft.updatedAtMs,
        DateTime.now().toUtc().millisecondsSinceEpoch,
      )) {
        return;
      }
      setState(() {
        _controller.text = text;
        _parsed = parseQuickAdd(text);
      });
    } catch (_) {}
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _saver ??= DraftAutosaver(ref.read(draftStoreProvider), 'quick_add', null);
    // Track the open sheet so a kill mid-typing restores it.
    // (dispose never runs on process kill, so the value survives kills
    // but is cleared on normal close in dispose below.)
    Future.microtask(() async {
      try {
        final repo = await ref.read(settingsRepositoryProvider.future);
        _settings = repo;
        await repo.setOpenSheet('quick_add');
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    if (!_saved) {
      _saver?.changed(() => {'text': _controller.text});
    }
    _saver?.dispose();
    final settings = _settings;
    // Normal close: clear the marker but keep the draft for preload.
    // Process kill skips dispose, so the marker survives kills.
    if (settings != null) {
      Future.microtask(() async {
        try {
          if (settings.openSheet == 'quick_add') {
            await settings.setOpenSheet(null);
          }
        } catch (_) {}
      });
    }
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  // ignore: unused_element
  void _onChanged(String v) {
    setState(() {
      _parsed = v.trim().isEmpty ? null : parseQuickAdd(v);
      _justAdded = false;
    });
    _saver?.changed(() => {'text': v});
  }
}
