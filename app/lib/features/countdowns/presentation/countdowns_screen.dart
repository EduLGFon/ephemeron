// Countdowns screen: grouped upcoming/passed/no-date grid, responsive cards,
// editor, and delete with the standard six-second undo window.
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/components/app_headers.dart';
import '../../../core/design/components/app_page.dart';
import '../../../core/design/components/app_states.dart';
import '../../../core/design/tokens.dart';
import '../../../core/time/device_date_format.dart';
import '../../../core/ui/app_feedback.dart';

import '../../../data/drift/app_database.dart';
import '../../sync/application/pending_operations.dart';
import '../application/countdowns_providers.dart';
import 'countdown_editor_sheet.dart';
import 'countdown_formatters.dart';
import 'countdown_widgets.dart';
import 'countdowns_strings.dart';

export 'countdown_formatters.dart'
    show countdownDayBadge, countdownRelativeLabel;

class CountdownsScreen extends ConsumerWidget {
  const CountdownsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = CountdownsStrings.of(context);
    final countdownsAsync = ref.watch(countdownsProvider);
    return AppPage(
      header: AppPageHeader(
        title: Text(strings.title),
        subtitle: countdownsAsync.maybeWhen(
          data: (items) =>
              items.isEmpty ? null : Text(strings.count(items.length)),
          orElse: () => null,
        ),
      ),
      child: countdownsAsync.when(
        loading: () => const AppSkeletonList(rows: 5),
        error: (_, _) => AppErrorState(
          title: strings.loadError,
          onRetry: () => ref.invalidate(countdownsProvider),
        ),
        data: (countdowns) {
          if (countdowns.isEmpty) {
            return AppEmptyState(
              icon: Icons.hourglass_bottom_outlined,
              title: strings.emptyTitle,
              message: strings.emptyMessage,
              actionLabel: strings.addAction,
              onAction: () => showCountdownEditor(context),
            );
          }
          return _CountdownGrid(
            countdowns: countdowns,
            strings: strings,
            onDelete: (countdown) => _delete(context, ref, strings, countdown),
          );
        },
      ),
    );
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    CountdownsStrings strings,
    Countdown countdown,
  ) async {
    final pending = ref.read(pendingOperationsProvider);
    final opId = await pending.scheduleCountdownDelete(countdown.id);
    if (!context.mounted) return;
    showUndoSnackBar(
      context,
      strings.deletedMessage,
      onUndo: () => pending.cancel(opId),
    );
  }
}

class _DatedCountdown {
  const _DatedCountdown({
    required this.countdown,
    required this.next,
    required this.days,
  });

  final Countdown countdown;
  final DateTime next;
  final int days;
}

class _CountdownGrid extends StatelessWidget {
  const _CountdownGrid({
    required this.countdowns,
    required this.strings,
    required this.onDelete,
  });

  final List<Countdown> countdowns;
  final CountdownsStrings strings;
  final ValueChanged<Countdown> onDelete;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final dated = <_DatedCountdown>[];
    final undated = <Countdown>[];
    for (final countdown in countdowns) {
      final schedule = countdownSchedule(
        targetDate: countdown.targetDate,
        yearlyRepeat: countdown.yearlyRepeat,
        today: today,
      );
      if (schedule == null) {
        undated.add(countdown);
      } else {
        dated.add(
          _DatedCountdown(
            countdown: countdown,
            next: schedule.next,
            days: schedule.days,
          ),
        );
      }
    }
    dated.sort((a, b) => a.days.compareTo(b.days));
    final upcoming = dated.where((item) => item.days >= 0).toList();
    final passed = dated.where((item) => item.days < 0).toList();
    final slivers = <Widget>[];
    void addGroup({
      required String title,
      required int count,
      required bool noDate,
      required Widget Function(int index) cellBuilder,
    }) {
      if (count == 0) return;
      slivers.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: DsSpace.x12),
            child: SectionTitle(title: title, count: count),
          ),
        ),
      );
      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.only(bottom: DsSpace.x12),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 420,
              mainAxisExtent: countdownCardExtent(context, noDate: noDate),
              crossAxisSpacing: DsSpace.x12,
              mainAxisSpacing: DsSpace.x12,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => cellBuilder(index),
              childCount: count,
            ),
          ),
        ),
      );
    }

    addGroup(
      title: strings.upcoming,
      count: upcoming.length,
      noDate: false,
      cellBuilder: (index) => _datedCell(context, upcoming[index], false),
    );
    addGroup(
      title: strings.passed,
      count: passed.length,
      noDate: false,
      cellBuilder: (index) => _datedCell(context, passed[index], true),
    );
    addGroup(
      title: strings.noDate,
      count: undated.length,
      noDate: true,
      cellBuilder: (index) {
        final countdown = undated[index];
        return CountdownCardCell(
          key: ValueKey(countdown.id),
          title: countdown.title,
          strings: strings,
          onTap: () => showCountdownEditor(context, countdown: countdown),
          onAction: (action) => _onAction(context, action, countdown),
        );
      },
    );
    return CustomScrollView(
      slivers: [
        ...slivers,
        const SliverToBoxAdapter(child: SizedBox(height: DsSpace.x48 * 2)),
      ],
    );
  }

  Widget _datedCell(BuildContext context, _DatedCountdown item, bool passed) {
    final countdown = item.countdown;
    return CountdownCardCell(
      key: ValueKey(countdown.id),
      title: countdown.title,
      strings: strings,
      days: passed ? item.days.abs() : item.days,
      dateLabel: _dateLabel(context, item, passed: passed),
      yearly: countdown.yearlyRepeat,
      onTap: () => showCountdownEditor(context, countdown: countdown),
      onAction: (action) => _onAction(context, action, countdown),
    );
  }

  String _dateLabel(
    BuildContext context,
    _DatedCountdown item, {
    required bool passed,
  }) {
    final countdown = item.countdown;
    final parts = <String>[];
    if (passed) parts.add(countdownRelativeLabel(item.days));
    if (countdown.yearlyRepeat && countdown.showAge) {
      final birth = parseCountdownDate(countdown.targetDate);
      if (birth != null) {
        parts.add(strings.turnsAge(item.next.year - birth.year));
      }
    }
    final linked = countdownLinkedTypeLabel(countdown.linkedType);
    if (linked != null) parts.add(linked);
    final date = DeviceDateFormat.yMMMd(context).format(item.next);
    return strings.dateLabel(date, parts.isEmpty ? null : parts.join(' · '));
  }

  void _onAction(
    BuildContext context,
    CountdownAction action,
    Countdown countdown,
  ) {
    switch (action) {
      case CountdownAction.edit:
        showCountdownEditor(context, countdown: countdown);
      case CountdownAction.delete:
        onDelete(countdown);
    }
  }
}
