// Left-edge habit gutter over the Stream day canvas.
//
// Presentation only: items come from [streamHabitGutterItemsProvider] and all
// actions/labels are injected. The layer owns no data and never writes.
//
// Geometry contract with [HabitGutter]:
// - The gutter reserves [StreamHabitLayer.allDaySlotHeight] at the top for
//   all-day habits and places a timed glyph at
//   `slotHeight + timeToY(minutes) - scrollOffset`.
// - [StreamTimeViewport.timeToPx], behind [StreamDayBodyController.timeToY],
//   already subtracts the scroll offset, so the mapping adds it back and
//   removes the slot once. Passing the raw controller value together with
//   `scrollOffset` would subtract the offset twice and push timed glyphs below
//   their day-canvas position.
//
// Net result: a habit at minute m renders at the canvas y for that local time,
// and all-day habits stay in the top slot.
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/stream_ambient.dart';
import '../habits/habit_gutter.dart';
import '../habits/habit_gutter_item.dart';
import '../stream_day_controller.dart';

/// Habit gutter overlay pinned to the leading edge of the day surface.
class StreamHabitLayer extends ConsumerStatefulWidget {
  const StreamHabitLayer({
    super.key,
    required this.controller,
    required this.day,
    required this.currentDayKey,
    required this.onToggle,
    required this.streakLabel,
    this.onLongPress,
    this.width = 56,
  });

  /// Height of the all-day slot at the top of the gutter.
  static const double allDaySlotHeight = 48;

  final StreamDayBodyController controller;

  /// Local day to render; only its date part is used.
  final DateTime day;

  /// Day key for done state; normally the same date as [day].
  final String currentDayKey;

  final void Function(String habitId) onToggle;

  /// `(id, current streak, best streak) -> tooltip label`.
  final String Function(String habitId, int current, int best) streakLabel;

  /// Optional long-press hook, normally used to reveal the streak.
  final void Function(String habitId)? onLongPress;

  final double width;

  @override
  ConsumerState<StreamHabitLayer> createState() => _StreamHabitLayerState();
}

class _StreamHabitLayerState extends ConsumerState<StreamHabitLayer> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(covariant StreamHabitLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  // Refreshes the animation below so it tracks the scroll listenable of a
  // newly attached viewport. Scroll ticks rebuild through the AnimatedBuilder.
  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final dayStart = DateTime(
      widget.day.year,
      widget.day.month,
      widget.day.day,
    );
    final dayKey = _dayKey(dayStart);
    final items = ref
        .watch(
          streamHabitGutterItemsProvider(
            StreamHabitRange(
              fromKey: dayKey,
              toKey: dayKey,
              currentDayKey: dayKey,
            ),
          ),
        )
        .when(
          data: (items) => items,
          loading: () => const <HabitGutterItem>[],
          error: (_, _) => const <HabitGutterItem>[],
        );

    return AnimatedBuilder(
      animation: Listenable.merge([controller, controller.scrollListenable]),
      builder: (context, _) {
        final viewport = controller.viewport;
        if (!controller.attached || viewport == null) {
          return const SizedBox.shrink();
        }
        final offset = viewport.offsetPx;
        return PositionedDirectional(
          start: 0,
          top: 0,
          bottom: 0,
          width: widget.width,
          child: HabitGutter(
            habits: items,
            currentDayKey: widget.currentDayKey,
            onToggle: widget.onToggle,
            timeToY: (minutes) =>
                _timedY(controller, dayStart, minutes, offset),
            hourHeight: 60.0 / viewport.minutesPerPixel,
            scrollOffset: offset,
            allDaySlotHeight: StreamHabitLayer.allDaySlotHeight,
            streakLabelFor: (item) => widget.streakLabel(
              item.id,
              item.streakCurrent,
              item.streakBest,
            ),
            onLongPress: widget.onLongPress == null
                ? null
                : (item) => widget.onLongPress!(item.id),
          ),
        );
      },
    );
  }
}

/// Marks-area y for [minutes] of wall-clock time past local midnight.
///
/// [HabitGutter] re-adds the all-day slot and subtracts `scrollOffset`, so this
/// mapping undoes both to keep the glyph on the day-canvas y for that time.
double _timedY(
  StreamDayBodyController controller,
  DateTime dayStart,
  int minutes,
  double scrollOffsetPx,
) {
  final localTime = DateTime(
    dayStart.year,
    dayStart.month,
    dayStart.day,
    0,
    minutes,
  );
  final y = controller.timeToY(localTime);
  if (y == null) return 0;
  return y + scrollOffsetPx - StreamHabitLayer.allDaySlotHeight;
}

String _dayKey(DateTime day) =>
    '${day.year.toString().padLeft(4, '0')}-'
    '${day.month.toString().padLeft(2, '0')}-'
    '${day.day.toString().padLeft(2, '0')}';
