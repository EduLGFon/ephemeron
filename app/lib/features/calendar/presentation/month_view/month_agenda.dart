part of '../month_view.dart';

class _AgendaHeader extends StatelessWidget {
  const _AgendaHeader({required this.day, required this.count});

  final DateTime day;
  final int count;

  @override
  Widget build(BuildContext context) {
    final title =
        '${DeviceDateFormat.weekdayFull(context, day)}, '
        '${DeviceDateFormat.monthName(context, day.month)} ${day.day}';
    final subtitle = count == 0
        ? 'No events'
        : count == 1
        ? '1 event'
        : '$count events';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            key: const Key('month-agenda-title'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyAgenda extends StatelessWidget {
  const _EmptyAgenda({required this.day});

  final DateTime day;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const Key('month-agenda-empty'),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: EmptyState(
        compact: true,
        icon: Icons.event_available_outlined,
        title: 'Nothing on this day',
        actionLabel: 'Add event',
        onAction: () =>
            showEventEditor(context, initialDay: day, initialHour: 9),
      ),
    );
  }
}
