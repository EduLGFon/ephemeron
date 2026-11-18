part of '../settings_screen.dart';

List<Widget> _accountSyncSection(
  _SettingsScreenState state,
  SettingsStrings strings, {
  required bool needsReconnect,
}) {
  final sections = <Widget>[
    SectionTitle(
      title: strings.accountSyncTitle,
      description: strings.accountSyncDescription,
    ),
    _SettingsGroup(
      children: <Widget>[
        _SettingsRow(
          key: const ValueKey('settings-accounts'),
          icon: Icons.person_outline,
          title: strings.accountRowTitle,
          subtitle: strings.accountRowSubtitle,
          onTap: () => _push(state.context, const AuthScreen()),
        ),
        if (needsReconnect)
          _SettingsRow(
            key: const ValueKey('settings-reconnect'),
            icon: Icons.warning_amber_rounded,
            title: strings.reconnectTitle,
            subtitle: strings.reconnectSubtitle,
            onTap: () => _push(state.context, const AuthScreen()),
          ),
        _LastSyncTile(strings: strings),
        _SettingsRow(
          key: const ValueKey('settings-sync-issues'),
          icon: Icons.report_outlined,
          title: strings.syncIssuesTitle,
          subtitle: strings.syncIssuesSubtitle,
          onTap: () => _push(state.context, const SyncIssuesScreen()),
        ),
        _SettingsPickerRow<int>(
          key: const ValueKey('settings-google-sync-interval'),
          title: strings.googleSyncIntervalTitle,
          help: strings.googleSyncIntervalHelp,
          value: state._syncIntervalMin,
          items: <DropdownMenuItem<int>>[
            DropdownMenuItem(value: 0, child: Text(strings.off)),
            DropdownMenuItem(value: 15, child: Text(strings.minutes(15))),
            DropdownMenuItem(value: 30, child: Text(strings.minutes(30))),
            DropdownMenuItem(value: 60, child: Text(strings.oneHour)),
            DropdownMenuItem(value: 120, child: Text(strings.twoHours)),
          ],
          onChanged: state._setSyncInterval,
        ),
        _SettingsPickerRow<int>(
          key: const ValueKey('settings-backend-sync-interval'),
          title: strings.backendSyncIntervalTitle,
          help: strings.backendSyncIntervalHelp,
          value: state._backendSyncIntervalMin,
          items: <DropdownMenuItem<int>>[
            DropdownMenuItem(value: 0, child: Text(strings.manual)),
            DropdownMenuItem(value: 15, child: Text(strings.minutes(15))),
            DropdownMenuItem(value: 30, child: Text(strings.minutes(30))),
            DropdownMenuItem(value: 60, child: Text(strings.oneHour)),
            DropdownMenuItem(value: 120, child: Text(strings.twoHours)),
          ],
          onChanged: state._setBackendSyncInterval,
        ),
        _SettingsRow(
          key: const ValueKey('settings-calendars'),
          icon: Icons.calendar_month_outlined,
          title: strings.calendarsTitle,
          subtitle: strings.calendarsSubtitle,
          onTap: () => _push(state.context, const CalendarSettingsScreen()),
        ),
        _SettingsRow(
          key: const ValueKey('settings-lists'),
          icon: Icons.checklist_outlined,
          title: strings.listsTitle,
          subtitle: strings.listsSubtitle,
          onTap: () => _push(state.context, const TaskListsScreen()),
        ),
      ],
    ),
  ];
  _sectionGap(sections);
  return sections;
}

void _push(BuildContext context, Widget screen) {
  Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
}

/// User-facing message for a classified Google sync failure. Auth, rate limit
/// and server failures must never tell the user to check their connection.
String syncIssueMessage(SyncErrorKind? kind) => switch (kind) {
  SyncErrorKind.auth => 'Sync needs permission. Reconnect your Google account.',
  SyncErrorKind.rateLimited => 'Google is rate-limiting sync. Try again later.',
  SyncErrorKind.network => 'No connection. Changes are queued.',
  SyncErrorKind.server => 'Google returned an error. Try again later.',
  SyncErrorKind.unknown => 'Sync failed. Try again.',
  SyncErrorKind.none || null => 'Sync failed. Try again.',
};

class _LastSyncTile extends ConsumerWidget {
  const _LastSyncTile({required this.strings});

  final SettingsStrings strings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(syncStatusProvider);
    final lastSync = ref.watch(lastGoogleSyncAtProvider);
    final date = lastSync == null
        ? null
        : DeviceDateFormat.dateTime(context, lastSync.toLocal());
    final subtitle = switch (status) {
      SyncStatus.synced =>
        date == null ? strings.notSyncedYet : strings.syncedAt(date),
      SyncStatus.error =>
        date == null
            ? strings.errorNotSyncedYet
            : strings.errorLastSuccess(date),
      SyncStatus.syncing =>
        date == null
            ? strings.syncingNotSyncedYet
            : strings.syncingLastSuccess(date),
      SyncStatus.offline =>
        date == null
            ? strings.offlineNotSyncedYet
            : strings.offlineLastSuccess(date),
    };
    final syncState = switch (status) {
      SyncStatus.synced => AppSyncState.synced,
      SyncStatus.syncing => AppSyncState.syncing,
      SyncStatus.offline => AppSyncState.offline,
      SyncStatus.error => AppSyncState.attention,
    };
    return _SettingsRow(
      key: const ValueKey('settings-last-sync'),
      icon: Icons.sync,
      title: strings.lastSyncTitle,
      subtitle: subtitle,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          AppSyncIndicator(state: syncState, compact: true, tooltip: subtitle),
          const SizedBox(width: DsSpace.x4),
          status == SyncStatus.syncing
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : AppIconButton(
                  tooltip: strings.syncNow,
                  semanticLabel: strings.syncNow,
                  icon: Icons.refresh,
                  onPressed: () => _syncNow(context, ref),
                ),
        ],
      ),
    );
  }

  Future<void> _syncNow(BuildContext context, WidgetRef ref) async {
    AppFeedback.tap();
    try {
      await ref.read(syncAllProvider)();
      if (!context.mounted) return;
      // syncAllProvider reports failures through status, not by throwing.
      final status = ref.read(combinedSyncStatusProvider);
      if (status == SyncStatus.synced) {
        AppFeedback.success();
        showAppSnackBar(context, strings.syncComplete, icon: Icons.sync);
      } else if (status == SyncStatus.offline) {
        AppFeedback.warning();
        showAppSnackBar(context, strings.syncOffline, icon: Icons.cloud_off);
      } else if (status == SyncStatus.error) {
        AppFeedback.error();
        final reconsentGoogle = ref.read(googleReconsentAccountsProvider);
        final reconsentMs = ref.read(microsoftReconsentAccountsProvider);
        final backendStatus = ref.read(backendSyncStatusProvider);
        final issue = ref.read(syncIssueProvider);
        if (reconsentGoogle.isNotEmpty) {
          showErrorSnackBar(context, syncIssueMessage(SyncErrorKind.auth));
        } else if (reconsentMs.isNotEmpty) {
          showErrorSnackBar(context, strings.syncAccountAttention);
        } else if (issue != null) {
          showErrorSnackBar(context, syncIssueMessage(issue));
        } else if (ref.read(syncStatusProvider) == SyncStatus.synced &&
            backendStatus == SyncStatus.error) {
          showErrorSnackBar(context, strings.syncBackendFailed);
        } else {
          showErrorSnackBar(context, syncIssueMessage(null));
        }
      } else {
        showAppSnackBar(context, strings.syncStillRunning, icon: Icons.sync);
      }
    } catch (_) {
      if (!context.mounted) return;
      AppFeedback.error();
      showErrorSnackBar(context, syncIssueMessage(SyncErrorKind.unknown));
    }
  }
}
