part of '../alarm_settings_screen.dart';

class _PresetCards extends StatelessWidget {
  const _PresetCards(this.ref);
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final p in AlarmPreset.values)
          Card(
            child: ListTile(
              title: Text(p.title),
              subtitle: Text(p.description),
            ),
          ),
      ],
    );
  }
}

class _Upcoming extends ConsumerWidget {
  const _Upcoming(this.ref);
  final WidgetRef ref;

  @override
  Widget build(BuildContext context, WidgetRef innerRef) {
    final upcoming = ref.watch(upcomingAlarmsProvider);
    final count = upcoming.value?.length ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader('Upcoming', count: count > 0 ? count : null),
        upcoming.maybeWhen(
          data: (list) => Column(
            children: [
              if (list.isEmpty)
                const EmptyState(
                  compact: true,
                  icon: Icons.schedule,
                  title: 'No upcoming alarms',
                  subtitle: 'Alarms you set will appear here.',
                )
              else
                for (final a in list.take(20))
                  ListTile(
                    title: Text(a.title ?? a.sourceId),
                    subtitle: Text(
                      '${a.kind} - ${a.preset ?? ''} - '
                      '${formatAlarmFireTime(a.fireAtUtc, DeviceDateFormat.yMMMd(context).add_Hm())}',
                    ),
                  ),
            ],
          ),
          orElse: () => const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _Missed extends ConsumerWidget {
  const _Missed(this.ref);
  final WidgetRef ref;

  @override
  Widget build(BuildContext context, WidgetRef innerRef) {
    final missedAsync = ref.watch(missedAlarmsProvider);
    final count = missedAsync.value?.length ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader('Missed alarms', count: count > 0 ? count : null),
        missedAsync.maybeWhen(
          data: (missed) => Column(
            children: [
              if (missed.isEmpty)
                const EmptyState(
                  compact: true,
                  icon: Icons.alarm_off,
                  title: 'No missed alarms',
                  subtitle: 'Alarms you miss will appear here.',
                )
              else
                for (final m in missed)
                  ListTile(
                    title: Text(m.title ?? m.sourceId),
                    subtitle: Text(
                      formatAlarmFireTime(
                        m.fireAtUtc,
                        DeviceDateFormat.yMMMd(context).add_Hm(),
                      ),
                    ),
                  ),
            ],
          ),
          orElse: () => const SizedBox.shrink(),
        ),
      ],
    );
  }
}
