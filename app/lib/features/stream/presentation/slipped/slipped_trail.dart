import 'package:material_ui/material_ui.dart';

import '../../design/stream_tokens.dart';

/// A single pill that clings to the Now line when tasks have slipped.
///
/// Presentation only: count and label are supplied by the caller.
class SlippedTrail extends StatelessWidget {
  const SlippedTrail({
    super.key,
    required this.count,
    required this.label,
    required this.onOpenTriage,
    this.color,
  });

  final int count;
  final String label;
  final VoidCallback onOpenTriage;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final warm = color ?? scheme.tertiary;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final duration = reduceMotion ? Duration.zero : StreamMotion.fast;
    return Semantics(
      button: true,
      label: label,
      onTap: onOpenTriage,
      child: GestureDetector(
        onTap: onOpenTriage,
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: 1),
          duration: duration,
          curve: StreamMotion.standard,
          builder: (context, value, child) {
            return Opacity(opacity: value, child: child);
          },
          child: SizedBox(
            height: StreamSpacing.x12,
            child: Container(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: StreamSpacing.x2,
                vertical: StreamSpacing.x1,
              ),
              decoration: BoxDecoration(
                color: warm.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(StreamRadii.full),
                border: Border.all(color: warm.withValues(alpha: 0.45)),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: StreamTypeScale.xs,
                  color: warm,
                  fontWeight: FontWeight(StreamFontWeight.medium),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
