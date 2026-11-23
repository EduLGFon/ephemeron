// "More" sheet: overflow destinations and settings in one scrollable command
// center. The first bar slots live in the adaptive navigation; this sheet
// lists the remaining destinations.
import 'package:material_ui/material_ui.dart';

import '../../core/design/components/app_headers.dart';
import '../../core/design/components/app_overlays.dart';
import '../../core/design/tokens.dart';
import 'destinations.dart';

class MoreSheet extends StatelessWidget {
  const MoreSheet({
    super.key,
    required this.secondary,
    required this.onSelected,
    required this.onReorder,
    required this.onSettings,
  });

  /// Destination ids in the More overflow (the tail of the reordered nav
  /// order), excluding Stream when it is disabled.
  final List<int> secondary;
  final ValueChanged<int> onSelected;
  final VoidCallback onReorder;
  final VoidCallback onSettings;

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
              const AppSheetHeader(title: 'More', subtitle: 'Jump anywhere'),
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
      dense: true,
      visualDensity: const VisualDensity(horizontal: -2, vertical: -3),
      minTileHeight: 40,
      leading: Icon(destination.icon),
      title: Text(destination.title),
      trailing: const Icon(Icons.chevron_right, size: DsIcon.sm),
      onTap: onTap,
    );
  }
}
