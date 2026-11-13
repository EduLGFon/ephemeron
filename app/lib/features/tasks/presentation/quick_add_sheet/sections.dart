part of '../quick_add_sheet.dart';

mixin _QuickAddSections on _QuickAddSheetStateBase {
  void _onChanged(String v);
  Future<void> _save({required bool another});

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
