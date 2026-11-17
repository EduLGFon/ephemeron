// Agenda lens: a plain, accessible list of the same marks for a range.
//
// Presentation only: data is injected. Input path: raw marks plus a day
// heading builder; grouping happens inside via groupMarksByDay. Semantic
// labels are supplied by the caller so no locale-specific text leaks in.
import 'package:material_ui/material_ui.dart';

import '../../application/stream_day_mark.dart';
import 'agenda_section.dart';

const double kAgendaRowExtent = 144;

class AgendaLens extends StatelessWidget {
  const AgendaLens({
    super.key,
    required this.marks,
    required this.onMarkTap,
    required this.emptyLabel,
    required this.formatTime,
    required this.semanticLabel,
    required this.dayHeadingBuilder,
  });

  final List<StreamDayMark> marks;
  final void Function(String id) onMarkTap;
  final String emptyLabel;
  final String Function(StreamDayMark mark) formatTime;
  final String Function(StreamDayMark mark) semanticLabel;
  final String Function(DateTime day) dayHeadingBuilder;

  @override
  Widget build(BuildContext context) {
    final sections = groupMarksByDay(marks, headingFor: dayHeadingBuilder);
    if (sections.isEmpty) {
      return Center(child: Text(emptyLabel));
    }
    return CustomScrollView(
      slivers: [
        for (final section in sections) ...[
          SliverToBoxAdapter(
            child: Semantics(
              header: true,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                  section.heading,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
            ),
          ),
          SliverFixedExtentList(
            itemExtent: kAgendaRowExtent,
            delegate: SliverChildBuilderDelegate((context, index) {
              final mark = section.items[index];
              return _AgendaRow(
                key: ValueKey<String>(mark.id),
                mark: mark,
                timeLabel: formatTime(mark),
                semanticLabelText: semanticLabel(mark),
                onMarkTap: onMarkTap,
              );
            }, childCount: section.items.length),
          ),
        ],
      ],
    );
  }
}

class _AgendaRow extends StatelessWidget {
  const _AgendaRow({
    super.key,
    required this.mark,
    required this.timeLabel,
    required this.semanticLabelText,
    required this.onMarkTap,
  });

  final StreamDayMark mark;
  final String timeLabel;
  final String semanticLabelText;
  final void Function(String id) onMarkTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final glyph = mark.kind == StreamDayMarkKind.event
        ? Icons.event_outlined
        : Icons.task_alt_outlined;
    return Semantics(
      button: true,
      label: semanticLabelText,
      onTap: () => onMarkTap(mark.id),
      child: InkWell(
        onTap: () => onMarkTap(mark.id),
        child: SizedBox(
          height: kAgendaRowExtent,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: double.infinity,
                  color: Color(mark.colorArgb),
                ),
                const SizedBox(width: 12),
                Icon(glyph, size: 20, color: scheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        timeLabel,
                        style: Theme.of(context).textTheme.labelMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        mark.title,
                        style: Theme.of(context).textTheme.bodyMedium,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
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
