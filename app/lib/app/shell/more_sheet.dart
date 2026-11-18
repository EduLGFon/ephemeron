// "More" sheet: search, quick creation, secondary destinations and settings in
// one scrollable command center. The primary destinations live in the
// adaptive navigation; this sheet only lists secondary destinations so the
// five primary slots stay the user's daily path.
import 'package:material_ui/material_ui.dart';

import '../../core/design/components/app_chips.dart';
import '../../core/design/components/app_headers.dart';
import '../../core/design/components/app_overlays.dart';
import '../../core/design/tokens.dart';
import 'destinations.dart';

enum MoreCreateAction { task, event, note, habit, countdown }

class MoreSheet extends StatelessWidget {
  const MoreSheet({
    super.key,
    required this.secondary,
    required this.onSelected,
    required this.onReorder,
    required this.onSearch,
    required this.onSettings,
    required this.onCreate,
  });

  /// Secondary destination ids (5..7, plus 8 only when Stream is enabled).
  final List<int> secondary;
  final ValueChanged<int> onSelected;
  final VoidCallback onReorder;
  final VoidCallback onSearch;
  final VoidCallback onSettings;
  final ValueChanged<MoreCreateAction> onCreate;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.82,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: DsSpace.x24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const AppSheetHeader(
                title: 'More',
                subtitle: 'Search, create and jump anywhere.',
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: DsSpace.x16),
                child: AppChip(
                  key: const ValueKey<String>('more-search'),
                  label: 'Search everything',
                  icon: Icons.search,
                  onTap: onSearch,
                  tooltip: 'Search everything (/)',
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: DsSpace.x16),
                child: SectionTitle(
                  title: 'Create',
                  description: 'Start something in one tap.',
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: DsSpace.x16),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // Three columns on narrow phones keeps all five actions
                    // readable instead of wrapping 4 + 1.
                    final columns = constraints.maxWidth < 420 ? 3 : 5;
                    final tileWidth =
                        (constraints.maxWidth - DsSpace.x8 * (columns - 1)) /
                        columns;
                    return Wrap(
                      spacing: DsSpace.x8,
                      runSpacing: DsSpace.x8,
                      children: <Widget>[
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
              if (secondary.isNotEmpty) ...<Widget>[
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: DsSpace.x16),
                  child: SectionTitle(title: 'Go to'),
                ),
                for (final id in secondary)
                  _DestinationTile(
                    destination: AppDestination.byId(id),
                    onTap: () => onSelected(id),
                  ),
              ],
              const Divider(height: DsSpace.x24),
              ListTile(
                key: const ValueKey<String>('more-settings'),
                leading: const Icon(Icons.settings_outlined),
                title: const Text('Settings'),
                onTap: onSettings,
              ),
              ListTile(
                key: const ValueKey<String>('more-reorder'),
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

class _DestinationTile extends StatelessWidget {
  const _DestinationTile({required this.destination, required this.onTap});

  final AppDestination destination;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final stream = destination.id == AppDestination.stream.id;
    return ListTile(
      key: ValueKey<String>(
        stream ? 'more-stream' : 'more-dest-${destination.id}',
      ),
      leading: Icon(destination.icon),
      title: Text(destination.title),
      trailing: const Icon(Icons.chevron_right, size: DsIcon.sm),
      onTap: onTap,
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
      color: scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(DsRadius.r12),
      child: InkWell(
        key: ValueKey<String>('more-create-${action.name}'),
        borderRadius: BorderRadius.circular(DsRadius.r12),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: DsSpace.x4,
              vertical: DsSpace.x8,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(_icons[action], size: DsIcon.md, color: scheme.primary),
                const SizedBox(height: DsSpace.x4),
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
      ),
    );
  }
}
