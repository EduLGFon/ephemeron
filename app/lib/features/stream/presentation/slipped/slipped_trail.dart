import 'package:material_ui/material_ui.dart';

import '../../design/stream_tokens.dart';

/// A stack of small pills that cling to the Now line when tasks have slipped.
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
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final scheme = Theme.of(context).colorScheme;
    final warm = color ?? scheme.tertiary;
    final pillCount = count.clamp(1, 3);
    return Semantics(
      button: true,
      label: label,
      onTap: onOpenTriage,
      child: GestureDetector(
        onTap: onOpenTriage,
        child: AnimatedOpacity(
          opacity: 1,
          duration: reduceMotion ? Duration.zero : StreamMotion.fast,
          child: SizedBox(
            height: StreamSpacing.x12,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                for (int i = 0; i < pillCount; i++)
                  Positioned(
                    left: i * 6.0,
                    top: i * 2.0,
                    child: _Pill(
                      text: (i == pillCount - 1 && count > 3)
                          ? '+${count - 2}'
                          : label,
                      color: warm,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: StreamSpacing.x2,
        vertical: StreamSpacing.x1,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(StreamRadii.full),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: StreamTypeScale.xs,
          color: color,
          fontWeight: FontWeight(StreamFontWeight.medium),
        ),
      ),
    );
  }
}
