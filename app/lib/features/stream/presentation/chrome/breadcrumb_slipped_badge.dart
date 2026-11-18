import 'package:material_ui/material_ui.dart';

import '../../design/stream_tokens.dart';

class BreadcrumbSlippedBadge extends StatelessWidget {
  const BreadcrumbSlippedBadge({
    super.key,
    required this.count,
    required this.scheme,
  });

  final int count;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: StreamSpacing.x1,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(StreamRadii.full),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          fontSize: StreamTypeScale.xs,
          fontFeatures: const [FontFeature.tabularFigures()],
          color: scheme.onTertiaryContainer,
        ),
      ),
    );
  }
}
