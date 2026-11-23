// Adaptive navigation shell. One LayoutBuilder decides the layout for the
// whole navigation chrome, publishes it through AppLayoutScope, and never
// re-measures inside branch screens.
import 'package:material_ui/material_ui.dart';

import '../../core/design/layout.dart';
import '../../core/design/tokens.dart';
import '../../core/time/device_date_format.dart';
import 'destinations.dart';
import 'quick_create_pill.dart';

class AdaptiveShell extends StatelessWidget {
  const AdaptiveShell({
    super.key,
    required this.currentIndex,
    required this.content,
    required this.primary,
    required this.secondary,
    required this.onDestinationSelected,
    required this.onMore,
    required this.onSettings,
  });

  final int currentIndex;
  final Widget content;

  /// Primary destination ids (0..4) in persisted order.
  final List<int> primary;

  /// Secondary destination ids (5..7, plus 8 when Stream is enabled).
  final List<int> secondary;
  final ValueChanged<int> onDestinationSelected;
  final VoidCallback onMore;
  final VoidCallback onSettings;

  int get _primarySlot => primary.indexOf(currentIndex);

  /// Compact widths below this value cannot fit six labelled destinations.
  static const double _compactLabelMinWidth = 360;

  /// Compact text scaling above this value cannot fit six labelled
  /// destinations. The reference size is the label's 12dp base height.
  static const double _compactLabelMaxScaledHeight = 18;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = layoutForWidth(constraints.maxWidth);
        return AppLayoutScope(
          layout: layout,
          child: switch (layout) {
            AppLayout.compact => _buildCompact(context, constraints),
            AppLayout.medium => _buildMedium(context),
            AppLayout.expanded => _buildExpanded(context),
          },
        );
      },
    );
  }

  Widget _pill() => const QuickCreatePill();

  Widget _buildCompact(BuildContext context, BoxConstraints constraints) {
    final slot = _primarySlot;
    // Six destinations on a narrow screen or with large text cannot fit their
    // labels: hide them instead of wrapping or clipping. The destinations keep
    // their tooltips and semantics, so every tab stays identifiable.
    final scaledLabelHeight = MediaQuery.textScalerOf(context).scale(12);
    final labelBehavior =
        constraints.maxWidth < _compactLabelMinWidth ||
            scaledLabelHeight > _compactLabelMaxScaledHeight
        ? NavigationDestinationLabelBehavior.alwaysHide
        : NavigationDestinationLabelBehavior.alwaysShow;
    return Scaffold(
      body: content,
      floatingActionButton: _pill(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      // NavigationBar wraps its content in a bottom SafeArea, so the selection
      // indicator stays above the system gesture inset.
      bottomNavigationBar: NavigationBar(
        labelBehavior: labelBehavior,
        selectedIndex: slot >= 0 ? slot : primary.length,
        onDestinationSelected: (index) {
          if (index >= primary.length) {
            onMore();
          } else {
            onDestinationSelected(primary[index]);
          }
        },
        destinations: <Widget>[
          for (var i = 0; i < primary.length; i++)
            NavigationDestination(
              key: ValueKey<String>('shell-dest-${primary[i]}'),
              icon: Icon(AppDestination.byId(primary[i]).icon),
              label: AppDestination.byId(primary[i]).title,
              tooltip: '${AppDestination.byId(primary[i]).title} (${i + 1})',
            ),
          const NavigationDestination(
            key: ValueKey<String>('shell-more'),
            icon: Icon(Icons.more_horiz),
            label: 'More',
            tooltip: 'More (C)',
          ),
        ],
      ),
    );
  }

  Widget _buildMedium(BuildContext context) {
    final slot = _primarySlot;
    return Scaffold(
      body: Row(
        children: <Widget>[
          NavigationRail(
            selectedIndex: slot >= 0 ? slot : primary.length,
            labelType: NavigationRailLabelType.all,
            minWidth: 80,
            onDestinationSelected: (index) {
              if (index == primary.length) {
                onMore();
              } else if (index == primary.length + 1) {
                onSettings();
              } else {
                onDestinationSelected(primary[index]);
              }
            },
            destinations: <NavigationRailDestination>[
              for (final id in primary)
                NavigationRailDestination(
                  icon: Icon(AppDestination.byId(id).icon),
                  label: Text(AppDestination.byId(id).title),
                ),
              const NavigationRailDestination(
                icon: Icon(Icons.more_horiz),
                label: Text('More'),
              ),
              const NavigationRailDestination(
                icon: Icon(Icons.settings_outlined),
                label: Text('Settings'),
              ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: content),
        ],
      ),
      floatingActionButton: _pill(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildExpanded(BuildContext context) {
    return Scaffold(
      body: Row(
        children: <Widget>[
          SizedBox(
            width: 240,
            child: _Sidebar(
              currentIndex: currentIndex,
              primary: primary,
              secondary: secondary,
              onDestinationSelected: onDestinationSelected,
              onSettings: onSettings,
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(child: content),
        ],
      ),
      floatingActionButton: _pill(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.currentIndex,
    required this.primary,
    required this.secondary,
    required this.onDestinationSelected,
    required this.onSettings,
  });

  final int currentIndex;
  final List<int> primary;
  final List<int> secondary;
  final ValueChanged<int> onDestinationSelected;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return SafeArea(
      key: const ValueKey<String>('shell-sidebar'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              DsSpace.x16,
              DsSpace.x16,
              DsSpace.x16,
              DsSpace.x8,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Ephemeron',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: DsSpace.x4),
                Text(
                  DeviceDateFormat.date(context, DateTime.now()),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(
                horizontal: DsSpace.x8,
                vertical: DsSpace.x8,
              ),
              children: <Widget>[
                for (final id in primary)
                  _SidebarTile(
                    id: id,
                    selected: currentIndex == id,
                    shortcut: '${primary.indexOf(id) + 1}',
                    onTap: () => onDestinationSelected(id),
                  ),
                if (secondary.isNotEmpty) ...<Widget>[
                  const SizedBox(height: DsSpace.x8),
                  _SidebarLabel('More'),
                  for (final id in secondary)
                    _SidebarTile(
                      id: id,
                      selected: currentIndex == id,
                      onTap: () => onDestinationSelected(id),
                    ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(DsSpace.x8),
            child: _SidebarAction(
              key: const ValueKey<String>('shell-settings'),
              icon: Icons.settings_outlined,
              label: 'Settings',
              onTap: onSettings,
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarLabel extends StatelessWidget {
  const _SidebarLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DsSpace.x12,
        DsSpace.x8,
        DsSpace.x12,
        DsSpace.x4,
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _SidebarTile extends StatelessWidget {
  const _SidebarTile({
    required this.id,
    required this.selected,
    required this.onTap,
    this.shortcut,
  });

  final int id;
  final bool selected;
  final VoidCallback onTap;
  final String? shortcut;

  @override
  Widget build(BuildContext context) {
    final destination = AppDestination.byId(id);
    return _SidebarAction(
      key: ValueKey<String>('shell-dest-$id'),
      icon: destination.icon,
      label: destination.title,
      selected: selected,
      shortcut: shortcut,
      onTap: onTap,
    );
  }
}

class _SidebarAction extends StatelessWidget {
  const _SidebarAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.shortcut,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;
  final String? shortcut;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final foreground = selected
        ? scheme.onSecondaryContainer
        : scheme.onSurface;
    final tile = Material(
      color: selected ? scheme.secondaryContainer : Colors.transparent,
      borderRadius: BorderRadius.circular(DsRadius.r12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DsRadius.r12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: DsSpace.x12),
            child: Row(
              children: <Widget>[
                Icon(icon, size: DsIcon.md, color: foreground),
                const SizedBox(width: DsSpace.x12),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: foreground,
                    ),
                  ),
                ),
                if (shortcut != null)
                  Text(
                    shortcut!,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    return Tooltip(
      message: shortcut == null ? label : '$label ($shortcut)',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: tile,
      ),
    );
  }
}
