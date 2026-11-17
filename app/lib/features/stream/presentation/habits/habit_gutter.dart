import 'package:material_ui/material_ui.dart';

import 'habit_glyph.dart';
import 'habit_gutter_item.dart';
import '../platform/stream_feedback.dart';

/// Gutter column of habit glyphs positioned by their time of day.
///
/// All-day habits (timeMinutes == null) go into a horizontal slot at the top.
/// Timed habits are positioned with the caller-supplied vertical mapping and
/// only those inside the visible viewport are built.
class HabitGutter extends StatelessWidget {
  const HabitGutter({
    super.key,
    required this.habits,
    required this.onToggle,
    this.timeToOffset,
    this.timeToY,
    this.hourHeight = 56,
    this.topOffset = 0,
    this.currentDayKey,
    this.scrollOffset = 0,
    this.allDaySlotHeight = 48,
    this.onLongPress,
    this.streakLabelFor,
    this.streakLabel,
  });

  final List<HabitGutterItem> habits;
  final void Function(String habitId) onToggle;
  final double Function(int timeMinutes)? timeToOffset;
  final double Function(int timeMinutes)? timeToY;
  final double hourHeight;
  final double topOffset;
  final String? currentDayKey;
  final double scrollOffset;
  final double allDaySlotHeight;
  final void Function(HabitGutterItem item)? onLongPress;
  final String Function(HabitGutterItem item)? streakLabelFor;
  final String Function(HabitGutterItem item)? streakLabel;

  double _yFor(int minutes) {
    final fn = timeToOffset ?? timeToY;
    if (fn != null) return fn(minutes);
    return (minutes / 60.0) * hourHeight + topOffset;
  }

  String? _streakText(HabitGutterItem item) {
    final f = streakLabelFor ?? streakLabel;
    return f?.call(item);
  }

  @override
  Widget build(BuildContext context) {
    final allDay = <HabitGutterItem>[];
    final timed = <HabitGutterItem>[];
    for (final h in habits) {
      if (h.timeMinutes == null) {
        allDay.add(h);
      } else {
        timed.add(h);
      }
    }
    timed.sort((a, b) => a.timeMinutes!.compareTo(b.timeMinutes!));

    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : 600.0;
        final visibleTimed = <HabitGutterItem>[];
        for (final h in timed) {
          final y = _yFor(h.timeMinutes!) - scrollOffset;
          if (y >= -48 && y <= height + 48) {
            visibleTimed.add(h);
            if (visibleTimed.length >= 48) break;
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: allDaySlotHeight,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: allDay.length,
                itemBuilder: (context, index) {
                  final item = allDay[index];
                  return _buildGlyph(context, item);
                },
              ),
            ),
            Expanded(
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  for (final item in visibleTimed)
                    PositionedDirectional(
                      top: _yFor(item.timeMinutes!) - scrollOffset,
                      start: 0,
                      child: _buildGlyph(context, item),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildGlyph(BuildContext context, HabitGutterItem item) {
    final streakText = _streakText(item);
    Widget glyph = HabitGlyph(
      done: _isDone(item),
      colorArgb: item.colorArgb,
      semanticsLabel: item.name,
      onTap: () {
        StreamFeedback.haptic(StreamHaptic.selection);
        onToggle(item.id);
      },
      onLongPress: onLongPress == null
          ? null
          : () {
              onLongPress!(item);
            },
    );
    if (streakText != null) {
      glyph = Tooltip(message: streakText, child: glyph);
    }
    return glyph;
  }

  bool _isDone(HabitGutterItem item) {
    if (currentDayKey != null) {
      return item.doneByDay[currentDayKey] ?? false;
    }
    if (item.doneByDay.length == 1) {
      return item.doneByDay.values.first;
    }
    final now = DateTime.now();
    final today =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    if (item.doneByDay.containsKey(today)) {
      return item.doneByDay[today] ?? false;
    }
    return item.doneByDay.values.any((v) => v);
  }
}
