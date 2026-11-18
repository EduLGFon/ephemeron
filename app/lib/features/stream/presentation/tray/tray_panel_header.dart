import 'package:material_ui/material_ui.dart';

import '../../design/stream_tokens.dart';
import 'tray_panel_rows.dart';

class TrayPanelHeader extends StatelessWidget {
  const TrayPanelHeader({super.key, required this.row});

  final TrayPanelHeaderRow row;

  @override
  Widget build(BuildContext context) {
    final color = Color(row.colorArgb);
    return Semantics(
      header: true,
      excludeSemantics: true,
      label: '${row.listName}, ${row.count}',
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: StreamSpacing.x2,
          vertical: StreamSpacing.x1,
        ),
        child: Row(
          children: [
            Container(width: 3, height: 16, color: color),
            const SizedBox(width: StreamSpacing.x2),
            Expanded(
              child: Text(
                row.listName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            Text('${row.count}'),
          ],
        ),
      ),
    );
  }
}
