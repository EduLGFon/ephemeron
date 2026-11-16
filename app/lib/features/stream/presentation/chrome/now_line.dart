import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:material_ui/material_ui.dart';

import '../../design/stream_tokens.dart';

/// A horizontal "now" hairline with a pinned live time label.
///
/// The label text comes from [label]; this widget has no clock of its own.
/// The accent color is taken from the theme's color scheme.
class NowLine extends StatelessWidget {
  const NowLine({super.key, required this.label, this.liveRegion = false});

  final ValueListenable<String> label;

  /// Whether the label is exposed as a live region to assistive tech.
  final bool liveRegion;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = scheme.primary;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        RepaintBoundary(
          child: ValueListenableBuilder<String>(
            valueListenable: label,
            builder: (context, text, _) {
              return Semantics(
                liveRegion: liveRegion,
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: StreamTypeScale.sm,
                    fontWeight: FontWeight(StreamFontWeight.medium),
                    color: accent,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: StreamSpacing.x2),
        Expanded(
          child: Container(height: 1, color: accent.withValues(alpha: 0.85)),
        ),
      ],
    );
  }
}
