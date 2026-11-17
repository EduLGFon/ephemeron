// Minimal tabular timer shown at the Now label during focus mode.
// Only the digits repaint per second; the parent is not rebuilt.
import 'package:material_ui/material_ui.dart';

import 'focus_clock.dart';

class FocusTimerControls extends StatelessWidget {
  const FocusTimerControls({
    super.key,
    required this.clock,
    required this.pauseLabel,
    required this.resumeLabel,
    required this.stopLabel,
    this.onPause,
    this.onResume,
    this.onPauseResume,
    this.onStop,
    this.formatElapsed,
    this.pauseSemanticsLabel,
    this.resumeSemanticsLabel,
    this.stopSemanticsLabel,
  });

  final FocusClock clock;
  final String pauseLabel;
  final String resumeLabel;
  final String stopLabel;
  final VoidCallback? onPause;
  final VoidCallback? onResume;
  final VoidCallback? onPauseResume;
  final VoidCallback? onStop;
  final String Function(Duration)? formatElapsed;
  final String? pauseSemanticsLabel;
  final String? resumeSemanticsLabel;
  final String? stopSemanticsLabel;

  String _format(Duration d) {
    if (formatElapsed != null) return formatElapsed!(d);
    final totalSec = d.inSeconds < 0 ? 0 : d.inSeconds;
    final h = totalSec ~/ 3600;
    final m = (totalSec % 3600) ~/ 60;
    final s = totalSec % 60;
    final mm = m.toString().padLeft(2, '0');
    final ss = s.toString().padLeft(2, '0');
    return h > 0 ? '${h.toString().padLeft(2, '0')}:$mm:$ss' : '$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        RepaintBoundary(
          child: ValueListenableBuilder<Duration>(
            valueListenable: clock.elapsed,
            builder: (context, value, _) {
              return Text(
                _format(value),
                style: TextStyle(
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: accent,
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 8),
        ValueListenableBuilder<Duration>(
          valueListenable: clock.elapsed,
          builder: (context, _, child) {
            final running = clock.isRunning;
            final label = running ? pauseLabel : resumeLabel;
            final semantics = running
                ? (pauseSemanticsLabel ?? pauseLabel)
                : (resumeSemanticsLabel ?? resumeLabel);
            return Semantics(
              button: true,
              label: semantics,
              child: IconButton(
                icon: Icon(running ? Icons.pause : Icons.play_arrow),
                tooltip: label,
                onPressed: () {
                  if (running) {
                    onPause?.call();
                  } else {
                    onResume?.call();
                  }
                  onPauseResume?.call();
                },
              ),
            );
          },
        ),
        Semantics(
          button: true,
          label: stopSemanticsLabel ?? stopLabel,
          child: IconButton(
            icon: const Icon(Icons.stop),
            tooltip: stopLabel,
            onPressed: onStop,
          ),
        ),
      ],
    );
  }
}
