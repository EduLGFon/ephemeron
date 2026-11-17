// Agenda host for the Stream surface.
//
// Presentation only: the caller supplies the marks, labels and callbacks, and
// the existing [AgendaLens] renders the list. The host adds only the theme
// background and padding so the lens can drop into a surface slot without
// introducing a screen, route or nested scrollable. Labels are never
// hard-coded here: empty state, headings, time and semantics come from the
// caller so the active locale stays with the app shell.
import 'package:material_ui/material_ui.dart';

import '../../application/stream_day_mark.dart';
import '../agenda/agenda_lens.dart';

class StreamAgendaHost extends StatelessWidget {
  const StreamAgendaHost({
    super.key,
    required this.marks,
    required this.emptyLabel,
    required this.formatTime,
    required this.semanticLabel,
    required this.dayHeadingBuilder,
    required this.onMarkTap,
  });

  final List<StreamDayMark> marks;

  /// Caller-localized text shown when [marks] is empty.
  final String emptyLabel;

  /// Formats an epoch-ms start time (local) for the row time label.
  final String Function(int startMs) formatTime;

  /// Caller-localized semantics label for one mark.
  final String Function(StreamDayMark mark) semanticLabel;

  /// Caller-localized heading for a local day.
  final String Function(DateTime day) dayHeadingBuilder;

  final void Function(String id) onMarkTap;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: AgendaLens(
          marks: marks,
          onMarkTap: onMarkTap,
          emptyLabel: emptyLabel,
          formatTime: (mark) => formatTime(mark.startMs),
          semanticLabel: semanticLabel,
          dayHeadingBuilder: dayHeadingBuilder,
        ),
      ),
    );
  }
}
