import 'package:material_ui/material_ui.dart';

import '../design/stream_tokens.dart';

/// Small "Now" pill shown when the viewport is away from the current time.
class NowPill extends StatelessWidget {
  const NowPill({super.key, required this.label, required this.onReturnToNow});

  final String label;
  final VoidCallback onReturnToNow;

  @override
  Widget build(BuildContext context) {
    // Visibility is gated by the parent (StreamDayBody) so this widget stays
    // a pure presentation element.
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onReturnToNow,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Container(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: StreamSpacing.x4,
              vertical: StreamSpacing.x2,
            ),
            decoration: BoxDecoration(
              color: scheme.primary,
              borderRadius: BorderRadius.circular(StreamRadii.full),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: StreamTypeScale.sm,
                fontWeight: FontWeight(StreamFontWeight.medium),
                color: scheme.onPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
