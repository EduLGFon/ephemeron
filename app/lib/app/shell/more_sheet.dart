// "More" sheet: search, quick creation and secondary navigation in one
// scrollable command center.
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:material_ui/material_ui.dart';

import '../../core/theme/theme_tokens.dart';
import '../../core/ui/app_section_header.dart';
import 'app_sections.dart';

enum MoreCreateAction { task, event, note, habit, countdown }

class MoreSheet extends StatelessWidget {
  const MoreSheet({
    super.key,
    required this.more,
    required this.onSelected,
    required this.onReorder,
    required this.onSearch,
    required this.onSettings,
    required this.onCreate,
  });

  final List<int> more;
  final ValueChanged<int> onSelected;
  final VoidCallback onReorder;
  final VoidCallback onSearch;
  final VoidCallback onSettings;
  final ValueChanged<MoreCreateAction> onCreate;

  bool get _showShortcutHint =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.82,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: AppSpace.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.lg,
                  AppSpace.md,
                  AppSpace.lg,
                  AppSpace.sm,
                ),
                child: Material(
                  color: scheme.primaryContainer.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  child: InkWell(
                    key: const ValueKey('more-search'),
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    onTap: onSearch,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpace.lg,
                        vertical: AppSpace.md,
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.search, color: scheme.onPrimaryContainer),
                          const SizedBox(width: AppSpace.md),
                          Expanded(
                            child: Text(
                              'Search everything',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: scheme.onPrimaryContainer,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (_showShortcutHint) const _KeyHint('/'),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const AppSectionHeader(
                'Create',
                description: 'Start something in one tap.',
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // Three columns on narrow phones keeps all five actions
                    // readable instead of wrapping 4 + 1.
                    final columns = constraints.maxWidth < 420 ? 3 : 5;
                    final tileWidth =
                        (constraints.maxWidth - AppSpace.sm * (columns - 1)) /
                        columns;
                    return Wrap(
                      spacing: AppSpace.sm,
                      runSpacing: AppSpace.sm,
                      children: [
                        for (final action in MoreCreateAction.values)
                          SizedBox(
                            width: tileWidth,
                            child: _CreateTile(
                              action: action,
                              onTap: () => onCreate(action),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
              if (more.isNotEmpty) ...[
                const AppSectionHeader('More'),
                for (final idx in more)
                  ListTile(
                    leading: Icon(AppSection.values[idx].icon),
                    title: Text(AppSection.values[idx].title),
                    onTap: () => onSelected(idx),
                  ),
              ],
              const Divider(height: AppSpace.xl),
              ListTile(
                key: const ValueKey('more-settings'),
                leading: const Icon(Icons.settings_outlined),
                title: const Text('Settings'),
                onTap: onSettings,
              ),
              ListTile(
                leading: const Icon(Icons.reorder),
                title: const Text('Customize navigation'),
                onTap: onReorder,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KeyHint extends StatelessWidget {
  const _KeyHint(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.sm,
        vertical: AppSpace.xxs,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _CreateTile extends StatelessWidget {
  const _CreateTile({required this.action, required this.onTap});

  final MoreCreateAction action;
  final VoidCallback onTap;

  static const _labels = <MoreCreateAction, String>{
    MoreCreateAction.task: 'Task',
    MoreCreateAction.event: 'Event',
    MoreCreateAction.note: 'Note',
    MoreCreateAction.habit: 'Habit',
    MoreCreateAction.countdown: 'Countdown',
  };

  static const _icons = <MoreCreateAction, IconData>{
    MoreCreateAction.task: Icons.add_task,
    MoreCreateAction.event: Icons.event_outlined,
    MoreCreateAction.note: Icons.note_add_outlined,
    MoreCreateAction.habit: Icons.repeat,
    MoreCreateAction.countdown: Icons.hourglass_bottom_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        key: ValueKey('more-create-${action.name}'),
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.xs,
            vertical: AppSpace.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_icons[action], size: 24, color: scheme.primary),
              const SizedBox(height: AppSpace.xs),
              Text(
                _labels[action]!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
