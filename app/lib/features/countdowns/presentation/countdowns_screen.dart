// Countdowns screen: upcoming/passed groups, calm date cards, relative
// distances, editor, and delete with a 6s undo window.
import 'package:flutter/material.dart';
import 'package:ephemeron/core/theme/theme_tokens.dart';
import 'package:ephemeron/core/time/device_date_format.dart';
import 'package:ephemeron/core/ui/app_feedback.dart';
import 'package:ephemeron/core/ui/app_section_header.dart';
import 'package:ephemeron/core/ui/empty_state.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/drift/app_database.dart';
import '../../../domain/countdowns/countdown.dart';
import '../../sync/application/pending_operations.dart';
import '../application/countdowns_providers.dart';
import 'countdown_editor_sheet.dart';

/// Large left-side badge text. Null means the countdown has no date.
String countdownDayBadge(int? days) {
  if (days == null) return '-';
  if (days < 0) return 'Past';
  return '$days';
}

String countdownRelativeLabel(int days) {
  if (days == 0) return 'today';
  if (days == 1) return 'tomorrow';
  if (days > 1) return 'in $days days';
  if (days == -1) return 'yesterday';
  return '${-days} days ago';
}

class CountdownsScreen extends ConsumerWidget {
  const CountdownsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countdownsAsync = ref.watch(countdownsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Countdowns')),
      body: countdownsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Could not load countdowns.'),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => ref.invalidate(countdownsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (countdowns) {
          if (countdowns.isEmpty) {
            return EmptyState(
              icon: Icons.hourglass_bottom_outlined,
              title: 'No countdowns yet.',
              actionLabel: 'Add countdown',
              onAction: () => showCountdownEditor(context),
            );
          }
          final today = DateTime.now();
          final dated = <({Countdown c, DateTime next, int days})>[];
          final undated = <Countdown>[];
          for (final c in countdowns) {
            final parsed = _parseDate(c.targetDate);
            if (parsed == null) {
              undated.add(c);
              continue;
            }
            // One-time countdowns use the full stored date; yearly ones
            // roll to the next occurrence via the domain helper.
            final next = c.yearlyRepeat
                ? countdownNextDate(
                    month: parsed.month,
                    day: parsed.day,
                    today: today,
                    yearlyRepeat: true,
                  )
                : DateTime(parsed.year, parsed.month, parsed.day);
            dated.add((c: c, next: next, days: daysUntil(next, today)));
          }
          dated.sort((a, b) => a.days.compareTo(b.days));
          final upcoming = dated.where((d) => d.days >= 0).toList();
          final passed = dated.where((d) => d.days < 0).toList();
          final items = <Widget>[];
          if (upcoming.isNotEmpty) {
            items.add(AppSectionHeader('Upcoming', count: upcoming.length));
            items.addAll(
              upcoming.map(
                (d) =>
                    _CountdownCard(countdown: d.c, next: d.next, days: d.days),
              ),
            );
          }
          if (passed.isNotEmpty) {
            items.add(AppSectionHeader('Passed', count: passed.length));
            items.addAll(
              passed.map(
                (d) =>
                    _CountdownCard(countdown: d.c, next: d.next, days: d.days),
              ),
            );
          }
          if (undated.isNotEmpty) {
            items.add(AppSectionHeader('No date', count: undated.length));
            items.addAll(undated.map((c) => _CountdownCard(countdown: c)));
          }
          return RepaintBoundary(
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 88),
              itemCount: items.length,
              itemBuilder: (_, i) => items[i],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'countdownsFab',
        onPressed: () => showCountdownEditor(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}

DateTime? _parseDate(String? targetDate) {
  if (targetDate == null || targetDate.isEmpty) return null;
  final p = targetDate.split('-');
  if (p.length != 3) return null;
  final y = int.tryParse(p[0]);
  final m = int.tryParse(p[1]);
  final d = int.tryParse(p[2]);
  if (y == null || m == null || d == null) return null;
  if (m < 1 || m > 12 || d < 1 || d > 31) return null;
  return DateTime(y, m, d);
}

enum _CountdownAction { edit, delete }

class _CountdownCard extends ConsumerWidget {
  const _CountdownCard({required this.countdown, this.next, this.days});

  final Countdown countdown;
  final DateTime? next;
  final int? days;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final passed = days != null && days! < 0;
    final isToday = days == 0;
    final detail = StringBuffer(
      days == null ? 'No date' : countdownRelativeLabel(days!),
    );
    if (next != null) {
      detail.write(' - ${DeviceDateFormat.yMMMd(context).format(next!)}');
    }
    String? yearlyBadge;
    if (countdown.yearlyRepeat) {
      final birth = _parseDate(countdown.targetDate);
      yearlyBadge = countdown.showAge && birth != null && next != null
          ? 'Turns ${next!.year - birth.year}'
          : 'Yearly';
    }
    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpace.md,
        vertical: AppSpace.xs,
      ),
      color: isToday ? scheme.primaryContainer.withValues(alpha: 0.45) : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: () => showCountdownEditor(context, countdown: countdown),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.md,
            AppSpace.sm,
            AppSpace.xs,
            AppSpace.sm,
          ),
          child: Row(
            children: [
              SizedBox(
                width: 58,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        countdownDayBadge(days),
                        style: theme.textTheme.displaySmall?.copyWith(
                          fontFamily: 'Fraunces',
                          height: 1,
                          color: passed
                              ? scheme.onSurfaceVariant
                              : isToday
                              ? scheme.primary
                              : scheme.onSurface,
                        ),
                      ),
                    ),
                    if (days != null && !passed)
                      Text(
                        isToday ? 'today' : 'days',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      countdown.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: passed
                            ? scheme.onSurfaceVariant
                            : scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: AppSpace.xxs),
                    Text(
                      detail.toString(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    if (yearlyBadge != null) ...[
                      const SizedBox(height: AppSpace.xs),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpace.sm,
                          vertical: AppSpace.xxs,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Text(
                          yearlyBadge,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.onSecondaryContainer,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              PopupMenuButton<_CountdownAction>(
                tooltip: 'More options',
                icon: const Icon(Icons.more_vert),
                onSelected: (action) {
                  switch (action) {
                    case _CountdownAction.edit:
                      showCountdownEditor(context, countdown: countdown);
                      break;
                    case _CountdownAction.delete:
                      _delete(context, ref);
                      break;
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: _CountdownAction.edit,
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 20),
                        SizedBox(width: AppSpace.sm),
                        Text('Edit'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: _CountdownAction.delete,
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, size: 20),
                        SizedBox(width: AppSpace.sm),
                        Text('Delete'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final pending = ref.read(pendingOperationsProvider);
    final opId = await pending.scheduleCountdownDelete(countdown.id);
    if (!context.mounted) return;
    showUndoSnackBar(
      context,
      'Countdown deleted.',
      onUndo: () => pending.cancel(opId),
    );
  }
}
