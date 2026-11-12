part of '../month_view.dart';

class _AgendaHeader extends StatelessWidget {
  const _AgendaHeader({required this.day, required this.count});

  final DateTime day;

  /// Final item count, or null while the day's range is loading or failed.
  final int? count;

  @override
  Widget build(BuildContext context) {
    final title =
        '${DeviceDateFormat.weekdayFull(context, day)}, '
        '${DeviceDateFormat.monthName(context, day.month)} ${day.day}';
    final count = this.count;
    final subtitle = count == null
        ? null
        : count == 0
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
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Small placeholder for the selected day while its range is loading.
class _AgendaLoading extends StatelessWidget {
  const _AgendaLoading();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      key: Key('month-agenda-loading'),
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
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
