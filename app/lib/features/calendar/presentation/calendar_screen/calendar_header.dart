// Calendar page header: title, visible period, period navigation, the view
// menu, calendar settings and the sync indicator.
import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/components/app_buttons.dart';
import '../../../../core/design/components/app_headers.dart';
import '../../../../core/design/components/sync_indicator.dart';
import '../../../../core/ui/app_feedback.dart';
import '../../../sync/application/sync_providers.dart';
import '../../../sync/data/sync_engine.dart';
import '../../application/calendar_providers.dart';
import '../../application/calendar_state.dart';
import '../calendar_settings_screen.dart';
import '../calendar_strings.dart';
import 'calendar_period_label.dart';
import 'calendar_view_menu.dart';

class CalendarHeader extends ConsumerWidget {
  const CalendarHeader({super.key, required this.window});

  final CalendarWindow window;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = CalendarStrings.of(context);
    final sync = switch (ref.watch(combinedSyncStatusProvider)) {
      SyncStatus.synced => AppSyncState.synced,
      SyncStatus.syncing => AppSyncState.syncing,
      SyncStatus.offline => AppSyncState.offline,
      SyncStatus.error => AppSyncState.attention,
    };
    final notifier = ref.read(calendarStateProvider.notifier);

    return AppPageHeader(
      title: Text(strings.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        calendarPeriodLabel(context, window),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      actions: <Widget>[
        AppIconButton(
          icon: Icons.today_outlined,
          tooltip: strings.today,
          semanticLabel: strings.today,
          onPressed: () {
            AppFeedback.tap();
            notifier.goToday();
          },
        ),
        AppIconButton(
          icon: Icons.chevron_left,
          tooltip: strings.previous,
          semanticLabel: strings.previous,
          onPressed: () {
            AppFeedback.selection();
            _shift(notifier, window, -1);
          },
        ),
        AppIconButton(
          icon: Icons.chevron_right,
          tooltip: strings.next,
          semanticLabel: strings.next,
          onPressed: () {
            AppFeedback.selection();
            _shift(notifier, window, 1);
          },
        ),
        CalendarViewMenu(window: window),
        AppIconButton(
          icon: Icons.settings_outlined,
          tooltip: strings.calendarSettings,
          semanticLabel: strings.calendarSettings,
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const CalendarSettingsScreen(),
            ),
          ),
        ),
        AppSyncIndicator(
          state: sync,
          tooltip: strings.syncNow,
          onTap: () {
            AppFeedback.tap();
            unawaited(ref.read(syncAllProvider)());
          },
        ),
      ],
    );
  }

  /// Month and year move by their own period; timelines move by a full page.
  void _shift(CalendarState notifier, CalendarWindow window, int direction) {
    switch (window.view) {
      case CalendarViewKind.month:
        notifier.shiftMonths(direction);
      case CalendarViewKind.year:
        notifier.shiftMonths(direction * 12);
      case CalendarViewKind.multiDay:
        notifier.shift(direction * window.dayCount);
      case CalendarViewKind.day:
      case CalendarViewKind.agenda:
        notifier.shift(direction);
    }
  }
}
