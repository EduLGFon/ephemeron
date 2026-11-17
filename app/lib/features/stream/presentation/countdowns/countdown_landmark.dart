import 'package:material_ui/material_ui.dart';

import '../../design/stream_tokens.dart';
import 'countdown_landmark_item.dart';

/// In-stream countdown landmark: a 1px hairline with a big tabular label,
/// title, and a small dot. Presentation only; data is injected.
class CountdownLandmark extends StatelessWidget {
  const CountdownLandmark({
    super.key,
    required this.id,
    required this.title,
    this.y,
    this.targetY,
    this.label,
    this.daysLabel,
    this.labelBuilder,
    this.onTap,
    this.colorArgb,
    this.value,
  });

  final String id;
  final String title;
  final double? y;
  final double? targetY;
  final String? label;
  final String? daysLabel;
  final String Function(CountdownLandmarkItem item)? labelBuilder;
  final void Function(String id)? onTap;
  final int? colorArgb;
  final num? value;

  String get _resolvedLabel {
    if (label != null) return label!;
    if (daysLabel != null) return daysLabel!;
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final lineColor = colorArgb != null
        ? Color(colorArgb!)
        : scheme.outlineVariant;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final duration = reduceMotion ? Duration.zero : StreamMotion.fast;
    final resolvedLabel = _resolvedLabel;
    return Semantics(
      label: '$title, $resolvedLabel',
      button: onTap != null,
      onTap: onTap == null ? null : () => onTap!(id),
      child: GestureDetector(
        onTap: onTap == null ? null : () => onTap!(id),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(height: 1, color: lineColor),
            const SizedBox(height: StreamSpacing.x1),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: lineColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: StreamSpacing.x2),
                Flexible(
                  child: TweenAnimationBuilder<double>(
                    key: ValueKey<String>(resolvedLabel),
                    tween: Tween<double>(begin: 0, end: 1),
                    duration: duration,
                    curve: StreamMotion.standard,
                    builder: (context, v, child) {
                      return Opacity(opacity: v, child: child);
                    },
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        resolvedLabel,
                        style: TextStyle(
                          fontSize: StreamTypeScale.xxl,
                          fontWeight: FontWeight(StreamFontWeight.light),
                          fontFeatures: const [FontFeature.tabularFigures()],
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: StreamSpacing.x2),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: StreamTypeScale.sm,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
