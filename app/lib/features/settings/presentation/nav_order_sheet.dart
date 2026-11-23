// Bottom sheet used by Settings to reorder all destinations.
// The adaptive shell splits this order into bar slots and More overflow.
import 'package:material_ui/material_ui.dart';

import '../../../app/shell/destinations.dart';
import '../../../core/design/components/app_buttons.dart';
import '../../../core/design/components/app_overlays.dart';
import '../../../core/design/tokens.dart';
import '../../../core/ui/app_sheet.dart';
import '../../../core/ui/escape_to_close.dart';
import '../data/settings_repository.dart';
import 'settings_strings.dart';

Future<void> showNavOrderSheet(
  BuildContext context,
  SettingsRepository repo, {
  required VoidCallback onSaved,
}) async {
  final strings = SettingsStrings.of(context);
  final current = List<int>.from(repo.navOrderV2);
  await showAppSheet<void>(
    context,
    builder: (ctx) => EscapeToClose(
      child: StatefulBuilder(
        builder: (ctx, setSt) => SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.75,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                AppSheetHeader(
                  title: strings.reorderSheetTitle,
                  subtitle: strings.reorderSheetDescription,
                ),
                Flexible(
                  child: ReorderableListView(
                    shrinkWrap: true,
                    buildDefaultDragHandles: false,
                    padding: const EdgeInsets.symmetric(horizontal: DsSpace.x8),
                    onReorderItem: (oldIndex, newIndex) {
                      setSt(() {
                        final item = current.removeAt(oldIndex);
                        current.insert(newIndex, item);
                      });
                    },
                    children: <Widget>[
                      for (var i = 0; i < current.length; i++)
                        ListTile(
                          key: ValueKey('nav-order-item-${current[i]}'),
                          title: Text(AppDestination.byId(current[i]).title),
                          trailing: ReorderableDragStartListener(
                            index: i,
                            child: Semantics(
                              label: strings.dragHandle,
                              child: const Icon(Icons.drag_handle),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    DsSpace.x16,
                    DsSpace.x8,
                    DsSpace.x16,
                    DsSpace.x16,
                  ),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: AppButton(
                          key: const ValueKey('nav-order-reset'),
                          label: strings.reset,
                          variant: AppButtonVariant.ghost,
                          onPressed: () => setSt(() {
                            current
                              ..clear()
                              ..addAll(SettingsRepository.defaultNavOrderV2);
                          }),
                        ),
                      ),
                      const SizedBox(width: DsSpace.x8),
                      Expanded(
                        child: AppButton(
                          key: const ValueKey('nav-order-save'),
                          label: strings.save,
                          expand: true,
                          onPressed: () async {
                            await repo.setNavOrderV2(current);
                            onSaved();
                            if (ctx.mounted) Navigator.of(ctx).pop();
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
