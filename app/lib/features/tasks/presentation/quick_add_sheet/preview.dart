part of '../quick_add_sheet.dart';

/// Fixed-height parse preview. The height never depends on how many chips are
/// visible, so typing and chip changes cannot move the field or the actions.
class _QuickAddPreview extends StatelessWidget {
  const _QuickAddPreview({
    required this.parsed,
    required this.kind,
    required this.pickedDate,
    required this.selectedListId,
    required this.lists,
  });

  final QuickAddParsed? parsed;
  final _QuickAddKind kind;
  final DateTime? pickedDate;
  final String? selectedListId;
  final List<TaskList> lists;

  @override
  Widget build(BuildContext context) {
    final strings = QuickAddStrings.of(context);
    final p = parsed;
    final title = p?.title.trim() ?? '';
    final chips = <Widget>[];
    void add(
      IconData icon,
      String label, {
      bool muted = false,
      Color? iconColor,
    }) {
      chips.add(
        Padding(
          padding: const EdgeInsets.only(right: DsSpace.x8),
          child: _PreviewChip(
            icon: icon,
            label: label,
            muted: muted,
            iconColor: iconColor,
          ),
        ),
      );
    }

    if (title.isEmpty) {
      add(Icons.title, strings.previewAddTitle, muted: true);
    } else {
      add(Icons.title, title);
    }
    final due = pickedDate ?? p?.due;
    switch (kind) {
      case _QuickAddKind.task:
        if (due != null) {
          add(Icons.event_outlined, _relativeDay(context, strings, due));
          if (due.hour != 0 || due.minute != 0) {
            add(Icons.schedule, DeviceDateFormat.time(context, due));
          }
        }
        final listName = _selectedListName() ?? p?.list;
        if (listName != null) add(Icons.list_alt, listName);
        if (p != null && p.priority > 0) {
          final style = styleForStoredPriority(p.priority);
          add(
            style.icon,
            strings.priorityLabel(5 - p.priority),
            iconColor: style.color,
          );
        }
        if (p != null && p.tags.isNotEmpty) {
          add(Icons.sell_outlined, p.tags.map((tag) => '#$tag').join(' '));
        }
        if (p?.rrule != null) {
          add(Icons.repeat, quickAddRepeatLabel(p!.rrule!));
        }
      case _QuickAddKind.event:
        final start = _eventStartFor(DateTime.now(), due);
        add(Icons.event_outlined, _relativeDay(context, strings, start));
        add(
          Icons.schedule,
          strings.timeRange(
            DeviceDateFormat.time(context, start),
            DeviceDateFormat.time(context, start.add(const Duration(hours: 1))),
          ),
        );
        if (p?.rrule != null) {
          add(Icons.repeat, quickAddRepeatLabel(p!.rrule!));
        }
      case _QuickAddKind.habit:
        add(Icons.repeat, strings.dailyFromToday);
      case _QuickAddKind.countdown:
        if (due == null) {
          add(Icons.event_outlined, strings.countdownDefault);
        } else {
          final now = DateTime.now();
          final days = DateTime(
            due.year,
            due.month,
            due.day,
          ).difference(DateTime(now.year, now.month, now.day)).inDays;
          add(
            Icons.event_outlined,
            days > 1
                ? strings.countdownInDays(days)
                : _relativeDay(context, strings, due),
          );
        }
    }

    return SizedBox(
      key: const ValueKey<String>('quick_add_preview'),
      height: 48,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const SizedBox(width: DsSpace.x4),
            ...chips,
            const SizedBox(width: DsSpace.x4),
          ],
        ),
      ),
    );
  }

  String? _selectedListName() {
    final id = selectedListId;
    if (id == null) return null;
    for (final list in lists) {
      if (list.id == id) return list.name;
    }
    return null;
  }
}

class _PreviewChip extends StatelessWidget {
  const _PreviewChip({
    required this.icon,
    required this.label,
    this.muted = false,
    this.iconColor,
  });

  final IconData icon;
  final String label;
  final bool muted;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = muted ? scheme.onSurfaceVariant : scheme.onSurface;
    return Container(
      constraints: const BoxConstraints(minHeight: 32),
      padding: const EdgeInsets.symmetric(
        horizontal: DsSpace.x8,
        vertical: DsSpace.x4,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(DsRadius.pill),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            icon,
            size: DsIcon.sm,
            color: iconColor ?? scheme.onSurfaceVariant,
          ),
          const SizedBox(width: DsSpace.x4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

String _relativeDay(
  BuildContext context,
  QuickAddStrings strings,
  DateTime date,
) {
  final now = DateTime.now();
  final day = DateTime(date.year, date.month, date.day);
  final today = DateTime(now.year, now.month, now.day);
  final diff = day.difference(today).inDays;
  if (diff == 0) return strings.today;
  if (diff == 1) return strings.tomorrow;
  return DeviceDateFormat.date(context, date);
}
