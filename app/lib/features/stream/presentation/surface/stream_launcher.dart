import 'package:ephemeron/l10n/src/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

import '../../design/stream_tokens.dart';

/// A destination reachable from the Stream surface launcher.
enum StreamLauncherDestination {
  calendar('/tab0', Icons.calendar_month_outlined),
  tasks('/tab1', Icons.checklist_outlined),
  matrix('/tab2', Icons.grid_view_outlined),
  habits('/tab3', Icons.repeat_outlined),
  countdowns('/tab4', Icons.hourglass_bottom_outlined),
  focus('/tab5', Icons.timer_outlined),
  notes('/tab6', Icons.note_outlined),
  search('/search', Icons.search, keepsStreamOnStack: true),
  settings('/settings', Icons.settings_outlined, keepsStreamOnStack: true);

  const StreamLauncherDestination(
    this.route,
    this.icon, {
    this.keepsStreamOnStack = false,
  });

  final String route;
  final IconData icon;

  /// Shell branches replace the Stream. Top-level screens push over it so the
  /// Stream stays on the back stack.
  final bool keepsStreamOnStack;
}

/// Modal sheet body listing every app section.
///
/// Navigation stays with the caller: [onSelected] receives the tapped
/// destination and [onClose] dismisses the sheet.
class StreamLauncher extends StatelessWidget {
  const StreamLauncher({
    super.key,
    required this.onSelected,
    required this.onClose,
  });

  final ValueChanged<StreamLauncherDestination> onSelected;
  final VoidCallback onClose;

  String _labelFor(StreamLauncherDestination destination, AppLocalizations l) {
    switch (destination) {
      case StreamLauncherDestination.calendar:
        return l.streamLauncherCalendar;
      case StreamLauncherDestination.tasks:
        return l.searchTasks;
      case StreamLauncherDestination.matrix:
        return l.streamLauncherMatrix;
      case StreamLauncherDestination.habits:
        return l.searchHabits;
      case StreamLauncherDestination.countdowns:
        return l.searchCountdowns;
      case StreamLauncherDestination.focus:
        return l.streamLauncherFocus;
      case StreamLauncherDestination.notes:
        return l.searchNotes;
      case StreamLauncherDestination.search:
        return l.searchTitle;
      case StreamLauncherDestination.settings:
        return l.streamSettings;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            StreamSpacing.x4,
            StreamSpacing.x1,
            StreamSpacing.x1,
            StreamSpacing.x1,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l.streamLauncherTitle,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Semantics(
                button: true,
                label: l.streamLauncherClose,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  child: IconButton(
                    key: const Key('streamLauncherClose'),
                    onPressed: onClose,
                    tooltip: l.streamLauncherClose,
                    icon: const Icon(Icons.close),
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsetsDirectional.symmetric(
              vertical: StreamSpacing.x1,
            ),
            children: [
              for (final destination in StreamLauncherDestination.values)
                _LauncherRow(
                  destination: destination,
                  label: _labelFor(destination, l),
                  onTap: () => onSelected(destination),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LauncherRow extends StatelessWidget {
  const _LauncherRow({
    required this.destination,
    required this.label,
    required this.onTap,
  });

  final StreamLauncherDestination destination;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: ListTile(
        key: Key('streamLauncherDestination-${destination.name}'),
        minTileHeight: 48,
        leading: Icon(destination.icon),
        title: Text(label),
        onTap: onTap,
      ),
    );
  }
}
