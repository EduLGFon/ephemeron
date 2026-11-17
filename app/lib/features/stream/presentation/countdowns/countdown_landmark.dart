import 'package:material_ui/material_ui.dart';

import '../../design/stream_tokens.dart';

/// In-stream countdown landmark: a 1px hairline with a big tabular label,
/// title, and a small dot. Presentation only; data is injected.
class CountdownLandmark extends StatelessWidget {
  const CountdownLandmark({
    super.key,
    required this.id,
    required this.title,
    this.label,
    this.daysLabel,
    this.days,
    this.value,
    this.onTap,
    this.colorArgb,
  }) : assert(label != null || daysLabel != null);

  final String id;
  final String title;
  final String? label;
  final String? daysLabel;
  final int? days;
  final num? value;
  final void Function(String id)? onTap;
  final int? colorArgb;

  String get _resolvedLabel => label ?? daysLabel ?? '';

  num? get _tweenValue => days ?? value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final lineColor = colorArgb != null
        ? Color(colorArgb!)
        : scheme.outlineVariant;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final duration = reduceMotion ? Duration.zero : StreamMotion.fast;
    final resolvedLabel = _resolvedLabel;
    final tweenKey = _tweenValue ?? resolvedLabel;
    return Semantics(
      label: '$title, $resolvedLabel',
      button: onTap != null,
      excludeSemantics: true,
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
                    key: ValueKey<Object>(tweenKey),
                    tween: Tween<double>(begin: 0, end: 1),
                    duration: duration,
                    curve: StreamMotion.standard,
                    builder: (context, v, child) {
                      return FadeTransition(
                        opacity: AlwaysStoppedAnimation<double>(v),
                        child: child,
                      );
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
