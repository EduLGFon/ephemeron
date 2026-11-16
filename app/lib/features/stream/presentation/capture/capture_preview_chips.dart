import 'package:material_ui/material_ui.dart';

import '../../design/stream_tokens.dart';

/// Kind of a capture preview chip, used to report taps.
enum CaptureChipKind { kind, date, time, repeat, list, priority }

/// Caller-supplied data for one preview chip.
class CapturePreviewChip {
  const CapturePreviewChip({
    required this.kind,
    required this.label,
    this.semanticsLabel,
  });

  final CaptureChipKind kind;
  final String label;
  final String? semanticsLabel;
}

/// Compact row of preview chips. Wraps instead of overflowing.
class CapturePreviewChips extends StatelessWidget {
  const CapturePreviewChips({
    super.key,
    required this.chips,
    required this.onChipTapped,
  });

  final List<CapturePreviewChip> chips;
  final ValueChanged<CaptureChipKind> onChipTapped;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: StreamSpacing.x1,
      runSpacing: StreamSpacing.x1,
      children: <Widget>[
        for (final chip in chips)
          Semantics(
            label: chip.semanticsLabel ?? chip.label,
            button: true,
            child: ActionChip(
              label: Text(chip.label),
              onPressed: () => onChipTapped(chip.kind),
              backgroundColor: chip.kind == CaptureChipKind.kind
                  ? scheme.primaryContainer
                  : scheme.surfaceContainerHighest,
              labelStyle: TextStyle(
                color: chip.kind == CaptureChipKind.kind
                    ? scheme.onPrimaryContainer
                    : scheme.onSurface,
              ),
            ),
          ),
      ],
    );
  }
}
