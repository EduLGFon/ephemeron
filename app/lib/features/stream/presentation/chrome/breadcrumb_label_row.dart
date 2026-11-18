import 'package:material_ui/material_ui.dart';

import '../../design/stream_tokens.dart';
import 'breadcrumb_slipped_badge.dart';

class BreadcrumbLabelRow extends StatelessWidget {
  const BreadcrumbLabelRow({
    super.key,
    required this.dateLabel,
    required this.levelLabel,
    required this.slippedCount,
    required this.fg,
    required this.scheme,
  });

  final String dateLabel;
  final String levelLabel;
  final int? slippedCount;
  final Color fg;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            dateLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: StreamTypeScale.sm,
              fontWeight: FontWeight(StreamFontWeight.medium),
              color: fg,
            ),
          ),
        ),
        const SizedBox(width: StreamSpacing.x1),
        Flexible(
          child: Text(
            levelLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: StreamTypeScale.xs,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
        if (slippedCount != null && slippedCount! > 0) ...[
          const SizedBox(width: StreamSpacing.x1),
          BreadcrumbSlippedBadge(count: slippedCount!, scheme: scheme),
        ],
      ],
    );
  }
}
