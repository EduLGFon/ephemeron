// Quick-add bottom sheet: one field with shorthand and NLP parsing,
// live icon-led preview, save and save-and-add-another.
// Unsaved text autosaves (debounced) and restores after restart.
import 'package:flutter/material.dart';
import 'package:ephemeron/core/theme/theme_tokens.dart';
import 'package:ephemeron/core/time/device_date_format.dart';
import 'package:ephemeron/core/ui/app_feedback.dart';
import 'package:ephemeron/core/ui/app_sheet.dart';
import 'package:ephemeron/core/ui/sheet_padding.dart';
import 'package:ephemeron/core/ui/escape_to_close.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/session/session_restore.dart';
import '../../../data/drift/app_database.dart';
import '../../../domain/parsing/quick_add_parser.dart';
import '../../settings/application/settings_providers.dart';
import '../application/tasks_providers.dart';

/// Date shortcut exposed under the quick-add field. The token is plain text
/// understood by [parseQuickAdd], so editing the input stays the only source
/// of truth.
class QuickAddDateChoice {
  const QuickAddDateChoice(this.label, this.token);

  final String label;
  final String token;
}

const quickAddDateChoices = <QuickAddDateChoice>[
  QuickAddDateChoice('Today', 'today'),
  QuickAddDateChoice('Tomorrow', 'tomorrow'),
  QuickAddDateChoice('Next week', 'in 7 days'),
];

final _tokenBoundary = RegExp(r'\s+');

RegExp _tokenPattern(String token) => RegExp(
  r'(?<![\p{L}\p{N}_-])' + RegExp.escape(token) + r'(?![\p{L}\p{N}_-])',
  unicode: true,
  caseSensitive: false,
);

bool _hasToken(String text, String token) =>
    _tokenPattern(token).hasMatch(text);

/// Emits the shorthand form for [name], quoting names that contain spaces.
String quickAddListToken(String name) =>
    name.contains(RegExp(r'\s')) ? '~"$name"' : '~$name';

/// Emits the shorthand form for [name], quoting names that contain spaces.
String quickAddTagToken(String name) =>
    name.contains(RegExp(r'\s')) ? '#"$name"' : '#$name';

/// Appends [token] once, separated by a single space.
String appendQuickAddShorthand(String text, String token) {
  final trimmed = text.trimRight();
  if (_hasToken(trimmed, token)) return trimmed;
  return trimmed.isEmpty ? token : '$trimmed $token';
}

/// Adds [token] when absent or removes it when already present.
String toggleQuickAddShorthand(String text, String token) {
  final pattern = _tokenPattern(token);
  if (!pattern.hasMatch(text)) return appendQuickAddShorthand(text, token);
  return text.replaceAll(pattern, ' ').replaceAll(_tokenBoundary, ' ').trim();
}

/// User-facing repeat label. RRULEs are never shown raw in the preview.
String quickAddRepeatLabel(String rrule) {
  final freq = RegExp(r'FREQ=([A-Z]+)').firstMatch(rrule)?.group(1);
  if (freq == null) return 'Repeats';
  switch (freq) {
    case 'DAILY':
      return 'Daily';
    case 'WEEKLY':
      final byDay = RegExp(r'BYDAY=([A-Z,]+)').firstMatch(rrule)?.group(1);
      if (byDay == null) return 'Weekly';
      return 'Weekly on ${_weekdayNames(byDay)}';
    case 'MONTHLY':
      return 'Monthly';
    case 'YEARLY':
      return 'Yearly';
    default:
      return 'Custom repeat';
  }
}

String _weekdayNames(String codes) {
  const names = {
    'MO': 'Mon',
    'TU': 'Tue',
    'WE': 'Wed',
    'TH': 'Thu',
    'FR': 'Fri',
    'SA': 'Sat',
    'SU': 'Sun',
  };
  final labels = [for (final code in codes.split(',')) names[code] ?? code];
  return labels.join(', ');
}

Future<void> showQuickAdd(
  BuildContext context, {
  String? initialText,
  Map<String, dynamic>? restoredDraft,
}) {
  return showAppSheet<void>(
    context,
    builder: (_) => EscapeToClose(
      child: _QuickAddSheet(
        initialText: initialText,
        restoredDraft: restoredDraft,
      ),
    ),
  );
}

class _QuickAddSheet extends ConsumerStatefulWidget {
  const _QuickAddSheet({this.initialText, this.restoredDraft});

  final String? initialText;
  final Map<String, dynamic>? restoredDraft;

  @override
  ConsumerState<_QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends ConsumerState<_QuickAddSheet> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  QuickAddParsed? _parsed;
  DraftAutosaver? _saver;
  bool _saved = false;
  bool _justAdded = false;
  dynamic _settings;

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

  void _onChanged(String v) {
    setState(() {
      _parsed = v.trim().isEmpty ? null : parseQuickAdd(v);
      _justAdded = false;
    });
    _saver?.changed(() => {'text': v});
  }

  void _applyToken(String token, {bool toggle = false}) {
    final next = toggle
        ? toggleQuickAddShorthand(_controller.text, token)
        : appendQuickAddShorthand(_controller.text, token);
    if (next == _controller.text) return;
    _controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
    _onChanged(next);
  }

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

  @override
  Widget build(BuildContext context) {
    final p = _parsed;
    final lists = ref.watch(taskListsProvider).value ?? const <TaskList>[];
    final tags = ref.watch(tagsProvider).value ?? const <Tag>[];
    final theme = Theme.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: sheetPadding(context),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.bolt_rounded,
                  color: theme.colorScheme.primary,
                  size: 22,
                ),
                const SizedBox(width: AppSpace.sm),
                Text('Quick add', style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: AppSpace.xs),
            Text(
              'Use #tag, ~list, -p1 to -p4, and phrases like tomorrow 9h.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpace.md),
            TextField(
              controller: _controller,
              focusNode: _focusNode,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Buy milk #groceries ~home -p1 tomorrow 9h',
                border: OutlineInputBorder(),
              ),
              onChanged: _onChanged,
              onSubmitted: (_) => _save(another: false),
            ),
            const SizedBox(height: AppSpace.sm),
            Wrap(
              spacing: AppSpace.sm,
              runSpacing: AppSpace.xs,
              children: [
                for (final choice in quickAddDateChoices)
                  ActionChip(
                    label: Text(choice.label),
                    avatar: const Icon(Icons.event_outlined, size: 16),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onPressed: () => _applyToken(choice.token),
                  ),
              ],
            ),
            if (p != null) ...[
              const SizedBox(height: AppSpace.sm),
              _PreviewWrap(parsed: p),
            ],
            if (_justAdded) ...[
              const SizedBox(height: AppSpace.sm),
              Row(
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: AppSpace.xs),
                  Text(
                    'Added',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ],
            if (lists.isNotEmpty) ...[
              const SizedBox(height: AppSpace.sm),
              _SuggestionRow(
                label: 'Lists',
                children: [
                  for (final list in lists.take(4))
                    FilterChip(
                      label: Text('~${list.name}'),
                      selected:
                          p?.list?.toLowerCase() == list.name.toLowerCase(),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      onSelected: (_) => _applyToken(
                        quickAddListToken(list.name),
                        toggle: true,
                      ),
                    ),
                ],
              ),
            ],
            if (tags.isNotEmpty) ...[
              const SizedBox(height: AppSpace.sm),
              _SuggestionRow(
                label: 'Tags',
                children: [
                  for (final tag in tags.take(4))
                    FilterChip(
                      label: Text('#${tag.name}'),
                      selected:
                          p?.tags.contains(tag.name.toLowerCase()) ?? false,
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      onSelected: (_) =>
                          _applyToken(quickAddTagToken(tag.name), toggle: true),
                    ),
                ],
              ),
            ],
            const SizedBox(height: AppSpace.md),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: p == null ? null : () => _save(another: false),
                    child: const Text('Save'),
                  ),
                ),
                const SizedBox(width: AppSpace.sm),
                OutlinedButton(
                  onPressed: p == null ? null : () => _save(another: true),
                  child: const Text('Save + another'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewWrap extends StatelessWidget {
  const _PreviewWrap({required this.parsed});

  final QuickAddParsed parsed;

  @override
  Widget build(BuildContext context) {
    final title = parsed.title;
    final tags = parsed.tags.map((tag) => '#$tag').join(' ');
    return Wrap(
      spacing: AppSpace.sm,
      runSpacing: AppSpace.xs,
      children: [
        _PreviewChip(
          icon: title.isEmpty ? Icons.error_outline : Icons.title,
          label: title.isEmpty ? 'Add a title' : title,
          muted: title.isEmpty,
        ),
        if (parsed.due != null)
          _PreviewChip(
            icon: Icons.event,
            label: DeviceDateFormat.dateTime(context, parsed.due!),
          ),
        if (parsed.list != null)
          _PreviewChip(icon: Icons.list_alt, label: parsed.list!),
        if (parsed.priority > 0)
          _PreviewChip(icon: Icons.flag, label: 'P${5 - parsed.priority}'),
        if (tags.isNotEmpty)
          _PreviewChip(icon: Icons.sell_outlined, label: tags),
        if (parsed.rrule != null)
          _PreviewChip(
            icon: Icons.repeat,
            label: quickAddRepeatLabel(parsed.rrule!),
          ),
      ],
    );
  }
}

class _PreviewChip extends StatelessWidget {
  const _PreviewChip({
    required this.icon,
    required this.label,
    this.muted = false,
  });

  final IconData icon;
  final String label;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.sm,
        vertical: AppSpace.xs,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 220),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: muted ? scheme.error : scheme.onSurfaceVariant,
            ),
            const SizedBox(width: AppSpace.xs),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: muted ? scheme.error : scheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuggestionRow extends StatelessWidget {
  const _SuggestionRow({required this.label, required this.children});

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: AppSpace.sm),
        Expanded(
          child: Wrap(
            spacing: AppSpace.sm,
            runSpacing: AppSpace.xs,
            children: children,
          ),
        ),
      ],
    );
  }
}
