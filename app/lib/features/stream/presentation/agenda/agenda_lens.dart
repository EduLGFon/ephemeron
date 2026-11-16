// Agenda lens: a plain, accessible list of the same marks for a range.
//
// Presentation only: data is injected. No providers, data, domain or router.
import 'package:material_ui/material_ui.dart';

import '../../application/stream_day_mark.dart';
import 'agenda_section.dart';

/// Fixed row height used for [itemExtent]. Large enough for two lines of
/// title at text scale 2.0 without clipping.
const double kAgendaRowExtent = 144;

class AgendaLens extends StatelessWidget {
  const AgendaLens({
    super.key,
    this.marks,
    this.sections,
    required this.onMarkTap,
    required this.emptyLabel,
    required this.formatTime,
    this.semanticLabel,
    this.dayHeadingBuilder,
  });

  /// Raw marks; grouped internally when [sections] is null.
  final List<StreamDayMark>? marks;

  /// Pre-grouped sections. Takes precedence over [marks].
  final List<AgendaSection>? sections;

  final void Function(String id) onMarkTap;
  final String emptyLabel;
  final String Function(StreamDayMark mark) formatTime;

  /// Composed semantics label (time, title, kind). Falls back to a neutral
  /// combination of [formatTime], title and kind name.
  final String Function(StreamDayMark mark)? semanticLabel;

  /// Heading label builder used when grouping [marks] internally.
  final String Function(DateTime day)? dayHeadingBuilder;

  List<AgendaSection> get _sections {
    if (sections != null) return sections!;
    return groupMarksByDay(
      marks ?? const <StreamDayMark>[],
      headingFor: dayHeadingBuilder,
    );
  }

  @override
  Widget build(BuildContext context) {
    final secs = _sections;
    if (secs.isEmpty) {
      return Center(child: Text(emptyLabel));
    }
    return CustomScrollView(
      slivers: [
        for (final section in secs) ...[
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
              final label = semanticLabel != null
                  ? semanticLabel!(mark)
                  : '${formatTime(mark)} ${mark.title} ${mark.kind.name}';
              return _AgendaRow(
                key: ValueKey<String>(mark.id),
                mark: mark,
                timeLabel: formatTime(mark),
                semanticLabelText: label,
                onMarkTap: onMarkTap,
              );
            }, childCount: section.items.length),
          ),
        ],
      ],
    );
  }
}

// SliverList has no itemExtent param directly? It does via delegate? Actually
// SliverList constructor accepts itemExtent? In newer Flutter, SliverList has
// `itemExtent`? Let's check. SliverFixedExtentList is the one. Need use
// SliverFixedExtentList instead. We'll fix below by editing.
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
