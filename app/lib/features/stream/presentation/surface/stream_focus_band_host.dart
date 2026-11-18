// Screen-level Stream focus control. Mounts the orphan focus widgets
// (FocusBand + FocusClock + FocusTimerControls) as an inline control in the
// chrome row under the header: the entry button starts a session and morphs
// into the elapsed pill (band + pause/resume + stop) in the same slot.
//
// History: the first version floated an overlay over the canvas top-end;
// after the tray-drag merge it intercepted the agenda toggle (the toggle row
// lives exactly there), and the day view's trailing scrubber rail plus the
// variable-height dock leave no occlusion-free floating anchor. The inline
// chrome-row slot has no overlap with any interactive chrome. See
// ARCHITECTURE.md section 2.
//
// The clock is in-memory only; a session survives screen rebuilds but is not
// persisted across restarts. Old FocusScreen stays reachable via the launcher.
import 'package:material_ui/material_ui.dart';

import '../../design/stream_tokens.dart';
import '../focus/focus_band.dart';
import '../focus/focus_clock.dart';
import '../focus/focus_timer_controls.dart';

// English literals: localized keys live in the l10n arb files, which are out
// of scope for this unit.
// TODO(focus-l10n): move these strings into the arb files and pass labels in.
const String _focusEntryLabel = 'Focus';
const String _pauseLabel = 'Pause';
const String _resumeLabel = 'Resume';
const String _stopLabel = 'Stop';

/// Focus control for the Stream chrome row. Place it after the agenda toggle
/// inside a [Flexible] so the active pill shrinks instead of overflowing on
/// narrow screens at maximum text scale.
///
/// Pass [clock] to inject a deterministic clock in tests; when null, the host
/// owns an in-memory [FocusClock] created lazily and disposed with the host.
class StreamFocusBandHost extends StatefulWidget {
  const StreamFocusBandHost({super.key, this.clock});

  final FocusClock? clock;

  @override
  State<StreamFocusBandHost> createState() => _StreamFocusBandHostState();
}

class _StreamFocusBandHostState extends State<StreamFocusBandHost> {
  FocusClock? _ownedClock;
  bool _sessionActive = false;

  FocusClock get _clock =>
      widget.clock ?? (_ownedClock ??= FocusClock(now: DateTime.now));

  @override
  void dispose() {
    _ownedClock?.dispose();
    super.dispose();
  }

  void _start() {
    setState(() {
      _clock.start();
      _sessionActive = true;
    });
  }

  void _stop() {
    setState(() {
      _clock.stop();
      _sessionActive = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _sessionActive ? _pill(scheme) : _entry(scheme);
  }

  Widget _entry(ColorScheme scheme) => Material(
    key: const Key('streamFocusEntry'),
    color: scheme.surface,
    elevation: 4,
    shape: const CircleBorder(),
    child: Semantics(
      button: true,
      label: _focusEntryLabel,
      child: IconButton(
        tooltip: _focusEntryLabel,
        onPressed: _start,
        icon: const Icon(Icons.timer_outlined),
      ),
    ),
  );

  Widget _pill(ColorScheme scheme) => Material(
    key: const Key('streamFocusBand'),
    color: scheme.surface,
    elevation: 4,
    borderRadius: BorderRadius.circular(StreamRadii.full),
    clipBehavior: Clip.antiAlias,
    // Scale down instead of overflowing on the narrowest screens at maximum
    // text scale; touch targets stay untouched at default scale.
    child: FittedBox(
      fit: BoxFit.scaleDown,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          StreamSpacing.x2,
          StreamSpacing.x1,
          StreamSpacing.x1,
          StreamSpacing.x1,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: StreamSpacing.x1,
              height: 40,
              // TODO(focus-palette): the band grows from session start to now
              // once the palette StartFocusCommand wiring defines a session
              // target; until then it renders as a static accent segment.
              child: FocusBand(
                mode: FocusBandMode.completed,
                segmentStart: 0,
                segmentEnd: 1,
                color: scheme.primary,
                semanticsLabel: _focusEntryLabel,
              ),
            ),
            const SizedBox(width: StreamSpacing.x1),
            FocusTimerControls(
              clock: _clock,
              pauseLabel: _pauseLabel,
              resumeLabel: _resumeLabel,
              stopLabel: _stopLabel,
              onPause: _clock.pause,
              onResume: _clock.resume,
              onStop: _stop,
            ),
          ],
        ),
      ),
    ),
  );
}
