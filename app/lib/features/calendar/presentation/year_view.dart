// Year heat-map: 12 month cards with counts and a compact year-in-review summary.
import 'package:flutter/material.dart';
import 'package:ephemeron/core/time/device_date_format.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/calendar_providers.dart';

class YearView extends ConsumerWidget {
  const YearView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final window = ref.watch(calendarStateProvider);
    final range = ref.watch(calendarCacheRangeProvider);
    final occAsync = ref.watch(windowOccurrencesProvider(range));
    final building = ref.watch(calendarCacheBuildingProvider);
    final year = window.anchor.year;
    final yearPrefix = '$year-';
    final occs = occAsync.maybeWhen(data: (v) => v, orElse: () => const []);

    // One O(n) pass for counts + stats.
    final monthCounts = <int, int>{};
    int totalEvents = 0;
    int totalTasks = 0;
    final activeDays = <String>{};
    final monthDaySets = <int, Set<String>>{};
    for (final o in occs) {
      if (!o.dayKey.startsWith(yearPrefix)) continue;
      final month = int.tryParse(o.dayKey.substring(5, 7)) ?? 0;
      if (month < 1 || month > 12) continue;
      monthCounts[month] = (monthCounts[month] ?? 0) + 1;
      if (o.sourceType == 'event') totalEvents++;
      if (o.sourceType == 'task') totalTasks++;
      activeDays.add(o.dayKey);
      monthDaySets.putIfAbsent(month, () => <String>{}).add(o.dayKey);
    }
    // Busiest month
    int busiestMonth = 1;
    int busiestCount = -1;
    for (var m = 1; m <= 12; m++) {
      final c = monthCounts[m] ?? 0;
      if (c > busiestCount) {
        busiestCount = c;
        busiestMonth = m;
      }
    }
    if (busiestCount < 0) busiestCount = 0;
    // Longest streak of consecutive active calendar days in this year.
    int longestStreak = 0;
    int currentStreak = 0;
    DateTime? prev;
    final sortedDays = activeDays.toList()..sort();
    for (final key in sortedDays) {
      final d = DateTime.tryParse('${key}T00:00:00Z');
      if (d == null) continue;
      if (prev != null && d.difference(prev).inDays == 1) {
        currentStreak++;
      } else {
        currentStreak = 1;
      }
      if (currentStreak > longestStreak) longestStreak = currentStreak;
      prev = d;
    }
    if (activeDays.isEmpty) longestStreak = 0;

    final max = monthCounts.values.fold<int>(1, (a, b) => a > b ? a : b);
    final now = DateTime.now();
    final isCurrentYear = year == now.year;

    final notifier = ref.read(calendarStateProvider.notifier);

    return Stack(
      children: [
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  _chip(context, 'Events', totalEvents),
                  _chip(context, 'Tasks', totalTasks),
                  _chip(context, 'Active days', activeDays.length),
                  _chip(
                    context,
                    'Busiest',
                    busiestCount,
                    label: busiestCount == 0
                        ? '-'
                        : '${DeviceDateFormat.shortMonthName(context, busiestMonth)} ($busiestCount)',
                  ),
                  _chip(context, 'Longest streak', longestStreak),
                ],
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 1.4,
                ),
                itemCount: 12,
                itemBuilder: (ctx, m) {
                  final month = m + 1;
                  final c = monthCounts[month] ?? 0;
                  final isCurrentMonth = isCurrentYear && month == now.month;
                  return Semantics(
                    label:
                        'Open ${DeviceDateFormat.monthName(context, month)} $year, $c items',
                    button: true,
                    child: InkWell(
                      onTap: () => notifier.openMonth(year, month),
                      child: Card(
                        color: Theme.of(context).colorScheme.primary.withValues(
                          alpha: 0.1 + 0.5 * c / max,
                        ),
                        shape: isCurrentMonth
                            ? RoundedRectangleBorder(
                                side: BorderSide(
                                  color: Theme.of(context).colorScheme.primary,
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              )
                            : null,
                        child: Center(
                          child: Text(
                            '${DeviceDateFormat.shortMonthName(context, month)}\n$c',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        if (monthCounts.isEmpty && building)
          const Align(
            alignment: Alignment.topCenter,
            child: LinearProgressIndicator(minHeight: 2),
          ),
      ],
    );
  }

  Widget _chip(BuildContext context, String name, int count, {String? label}) {
    final text = label ?? '$count';
    return Chip(
      label: Text('$name: $text', style: const TextStyle(fontSize: 11)),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }
}
