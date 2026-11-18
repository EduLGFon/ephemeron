import 'dart:async';

import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import 'package:ephemeron/l10n/src/app_localizations.dart';

import '../../../../core/time/device_date_format.dart';
import '../../../../core/ui/app_feedback.dart';
import '../../../../core/ui/app_sheet.dart';
import '../../habits/application/habits_providers.dart' show habitByIdProvider;
import '../../habits/presentation/habit_editor_sheet.dart' show showHabitEditor;
import '../../sync/application/sync_providers.dart' show syncAllProvider;
import '../application/stream_command_actions.dart';
import '../application/stream_day_cache_scope.dart';
import '../application/stream_day_mark.dart' show StreamDayMarkKind;
import '../application/stream_day_providers.dart' show StreamDayKey;
import '../application/stream_level_data.dart';
import '../application/stream_level_streaks.dart';
import '../application/stream_school_preferences.dart';
import '../application/stream_sync_status.dart';
import '../application/stream_theme_provider.dart';
import '../capture/capture_parser.dart' show CaptureLocale;
import '../design/stream_theme.dart';
import 'stream_day_body.dart';
import 'stream_header.dart';
import 'stream_layout_mode.dart';
import 'stream_route_params.dart';
import 'stream_time_format.dart';
import 'surface/stream_command_overlay.dart';
import 'surface/stream_dock_host.dart';
import 'surface/stream_launcher.dart';
import 'surface/stream_level_host.dart';
import 'surface/stream_offline_banner_host.dart';
import 'surface/stream_peek_sheet.dart';
import 'surface/stream_school_host.dart';
import 'surface/stream_settings_sheet.dart';

String _weekdayShort(AppLocalizations l, int weekday) => switch (weekday) {
  DateTime.monday => l.streamWeekdayMon,
  DateTime.tuesday => l.streamWeekdayTue,
  DateTime.wednesday => l.streamWeekdayWed,
  DateTime.thursday => l.streamWeekdayThu,
  DateTime.friday => l.streamWeekdayFri,
  DateTime.saturday => l.streamWeekdaySat,
  _ => l.streamWeekdaySun,
};

String _levelLabel(AppLocalizations l, StreamLevel level) => switch (level) {
  StreamLevel.day => l.streamDay,
  StreamLevel.week => l.streamWeek,
  StreamLevel.month => l.streamMonth,
  StreamLevel.year => l.streamYear,
};

class StreamScreen extends ConsumerStatefulWidget {
  const StreamScreen({
    super.key,
    this.date,
    this.zoom,
    this.now,
    this.onOpenCommand,
    this.onOpenSettings,
    this.onDateChanged,
    this.onReturnToNow,
    this.syncStatus,
    this.syncLabel,
  });

  final DateTime? date;
  final String? zoom;

  /// Fixed wall clock for tests; null uses the real clock.
  final DateTime? now;
  final VoidCallback? onOpenCommand;
  final VoidCallback? onOpenSettings;
  final ValueChanged<DateTime>? onDateChanged;
  final VoidCallback? onReturnToNow;

  /// Test overrides. Null uses the live combined sync status and its localized
  /// label; a provided status without a label keeps the header label empty.
  final StreamSyncStatus? syncStatus;
  final String? syncLabel;

  @override
  ConsumerState<StreamScreen> createState() => _StreamScreenState();
}

class _StreamScreenState extends ConsumerState<StreamScreen> {
  final ValueNotifier<bool> _paletteOpen = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _agendaOpen = ValueNotifier<bool>(false);
  final FocusNode _shortcutFocus = FocusNode(debugLabel: 'streamShortcuts');

  @override
  void dispose() {
    _paletteOpen.dispose();
    _agendaOpen.dispose();
    _shortcutFocus.dispose();
    super.dispose();
  }

  void _openPalette() {
    _paletteOpen.value = true;
  }

  void _closePalette() {
    _paletteOpen.value = false;
    _shortcutFocus.requestFocus();
  }

  void _onBreadcrumbTap() {
    widget.onOpenCommand?.call();
    _openPalette();
  }

  /// Routes navigation intents and runs side-effect intents through the shared
  /// executor. Failures use a localized snackbar; the reason stays internal.
  Future<void> _handleCommandIntent(StreamCommandIntent intent) async {
    final router = GoRouter.maybeOf(context);
    switch (intent) {
      case StreamCommandGoToDate(:final date):
        router?.go('/stream/${formatStreamDate(date)}/day');
      case StreamCommandZoom(:final level):
        final params = _resolveParams();
        router?.go(
          '/stream/${formatStreamDate(params.date)}/'
          '${normalizeStreamZoom(level)}',
        );
      case StreamCommandAgenda():
        _agendaOpen.value = !_agendaOpen.value;
      case StreamCommandSettings():
        router?.push('/settings');
      case StreamCommandSearch():
        router?.push('/search');
      case StreamCommandSyncNow() || StreamCommandTheme():
        final result = await ref
            .read(streamCommandExecutorProvider)
            .execute(intent);
        if (!mounted || result is! StreamCommandFailed) return;
        showErrorSnackBar(
          context,
          AppLocalizations.of(context).streamCommandFailed,
        );
      case StreamCommandHelp() || StreamCommandUnsupported():
        // Not offered by the palette.
        break;
    }
  }

  String _syncLabel(AppLocalizations l, StreamSyncStatus status) =>
      switch (status) {
        StreamSyncStatus.synced => l.streamSyncSynced,
        StreamSyncStatus.syncing => l.streamSyncSyncing,
        StreamSyncStatus.offline => l.streamSyncOffline,
        StreamSyncStatus.attention => l.streamSyncAttention,
      };

  StreamRouteParams _resolveParams() {
    final router = GoRouter.maybeOf(context);
    final gs = router?.state;
    final routeDate = gs == null
        ? null
        : tryParseStreamDate(gs.pathParameters['date']);
    final routeZoom = gs?.pathParameters['zoom'];
    final resolvedDate = widget.date ?? routeDate;
    final resolvedZoom = widget.zoom ?? routeZoom;
    return parseStreamRouteParams(
      date: resolvedDate == null ? null : formatStreamDate(resolvedDate),
      zoom: resolvedZoom,
    );
  }

  /// Day taps drill into the day level and keep the route authoritative.
  void _openDay(DateTime day) {
    widget.onDateChanged?.call(day);
    GoRouter.maybeOf(context)?.go('/stream/${formatStreamDate(day)}/day');
  }

  /// Month and year ribbons open the existing habit editor sheet. The habit
  /// row is read on tap only, never per ribbon, so the level stays one batch.
  void _openHabit(String habitId) => unawaited(_showHabit(habitId));

  Future<void> _showHabit(String habitId) async {
    try {
      final habit = await ref.read(habitByIdProvider(habitId).future);
      if (!mounted || habit == null) return;
      await showHabitEditor(context, habit: habit);
    } catch (_) {
      if (!mounted) return;
      showErrorSnackBar(
        context,
        AppLocalizations.of(context).streamPeekLoadFailed,
      );
    }
  }

  Widget _bodyFor({
    required StreamLevel level,
    required StreamRouteParams params,
    required DateTime now,
    required AppLocalizations l,
  }) {
    if (level == StreamLevel.day) {
      return StreamDayCacheScope(
        day: StreamDayKey(
          year: params.date.year,
          month: params.date.month,
          day: params.date.day,
        ),
        child: StreamDayBody(
          date: params.date,
          now: now,
          onDateChanged: _openDay,
          onReturnToNow: widget.onReturnToNow,
        ),
      );
    }
    // Month and year ribbons come from one batch of habit entries for the
    // same range the level already renders; week and day have no ribbons.
    final streaks = switch (level) {
      StreamLevel.month || StreamLevel.year =>
        ref
            .watch(
              streamLevelHabitStreaksProvider(
                streamLevelRangeFor(level, params.date),
              ),
            )
            .value,
      StreamLevel.day || StreamLevel.week => null,
    };
    return StreamLevelHost(
      level: level,
      date: params.date,
      firstDayOfWeek: DateTime.monday,
      dayHeaderBuilder: (_, day) => _weekdayShort(l, day.weekday),
      daySemanticsLabel: (_, day) => l.streamWeekDaySemantics(
        _weekdayShort(l, day.weekday),
        DeviceDateFormat.shortDate(context, day),
      ),
      monthDaySemanticsLabel: (day, count) => l.streamMonthDaySemantics(
        DeviceDateFormat.shortDate(
          context,
          DateTime(params.date.year, params.date.month, day),
        ),
        count,
      ),
      streakSemanticsLabel: (_, firstDay, lastDay) =>
          l.streamMonthStreakSemantics(
            lastDay - firstDay + 1,
            firstDay,
            lastDay,
          ),
      markSemanticsLabel: (mark) => l.streamMarkSemantics(
        mark.kind == StreamDayMarkKind.task
            ? l.streamChipKindTask
            : l.streamChipKindEvent,
        mark.title,
      ),
      markActionLabels: <String, String>{
        'complete': l.streamMarkActionComplete,
        'push': l.streamMarkActionPush,
        'reschedule': l.streamMarkActionReschedule,
        'delete': l.streamMarkActionDelete,
      },
      emptyLabel: l.streamLevelEmpty,
      loadingLabel: l.streamLevelLoading,
      errorLabel: l.streamLevelError,
      yearMonthHeading: (month) =>
          DeviceDateFormat.shortMonthName(context, month),
      yearMonthSemanticsLabel: (heading, count) =>
          l.streamMonthDaySemantics(heading, count),
      yearDaySemanticsLabel: (day, count) => l.streamMonthDaySemantics(
        DeviceDateFormat.shortDate(context, day),
        count,
      ),
      // Year runs are split per month, so their day numbers stay unambiguous
      // under the month semantics node.
      yearHabitStreakSemanticsLabel: (_, first, last) =>
          l.streamMonthStreakSemantics(
            last.difference(first).inDays + 1,
            first.day,
            last.day,
          ),
      habitStreaks: streaks?.monthStreaks,
      yearHabitStreaks: streaks?.yearStreaks,
      onHabitTap: _openHabit,
      onDayTap: _openDay,
      onDateTap: _openDay,
      // Mark actions stay out of scope: the host exposes no complete, push,
      // reschedule or delete callbacks, so level mark chips are read-only and
      // onMarkTap is intentionally not wired.
    );
  }

  /// Agenda is a lens over the current level's marks, not a zoom level.
  Widget _agendaFor({
    required StreamLevel level,
    required StreamRouteParams params,
    required AppLocalizations l,
  }) {
    return StreamLevelAgenda(
      level: level,
      date: params.date,
      firstDayOfWeek: DateTime.monday,
      emptyLabel: l.streamLevelEmpty,
      loadingLabel: l.streamLevelLoading,
      errorLabel: l.streamLevelError,
      formatTime: (startMs) => formatStreamTimeOfDay(
        context,
        DateTime.fromMillisecondsSinceEpoch(startMs),
      ),
      markSemanticsLabel: (mark) => l.streamMarkSemantics(
        mark.kind == StreamDayMarkKind.task
            ? l.streamChipKindTask
            : l.streamChipKindEvent,
        mark.title,
      ),
      dayHeadingBuilder: (day) => DeviceDateFormat.date(context, day),
      onMarkTap: (mark) => unawaited(showStreamPeek(context, mark: mark)),
    );
  }

  Widget _agendaToggle(AppLocalizations l, bool open) => Padding(
    padding: const EdgeInsetsDirectional.fromSTEB(8, 0, 8, 0),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(l.streamAgenda),
        const SizedBox(width: 4),
        Switch(
          key: const Key('streamAgendaToggle'),
          value: open,
          onChanged: (value) => _agendaOpen.value = value,
        ),
      ],
    ),
  );

  /// Inline offline banner plus the agenda switch above the level body.
  Widget _levelBody({
    required StreamLevel level,
    required StreamRouteParams params,
    required DateTime now,
    required AppLocalizations l,
  }) {
    return ValueListenableBuilder<bool>(
      valueListenable: _agendaOpen,
      builder: (context, agendaOpen, _) => Column(
        children: [
          StreamOfflineBannerHost(
            message: l.streamOfflineMessage,
            retryLabel: l.streamOfflineRetry,
            onRetry: () => unawaited(ref.read(syncAllProvider)()),
          ),
          _agendaToggle(l, agendaOpen),
          Expanded(
            child: agendaOpen
                ? _agendaFor(level: level, params: params, l: l)
                : _bodyFor(level: level, params: params, now: now, l: l),
          ),
        ],
      ),
    );
  }

  /// Opens the Stream settings sheet. Navigation and school replay stay with
  /// this caller; the sheet only reports the intent.
  void _openSettings() {
    widget.onOpenSettings?.call();
    showAppSheet<void>(
      context,
      builder: (sheetContext) => StreamSettingsSheet(
        onClose: () => Navigator.of(sheetContext).pop(),
        onOpenAppSettings: () {
          Navigator.of(sheetContext).pop();
          GoRouter.maybeOf(context)?.push('/settings');
        },
        onReplaySchool: () => unawaited(_replaySchool(sheetContext)),
      ),
    );
  }

  /// Clears the completion flag, then dismisses the sheet so the school host
  /// can show the overlay again.
  Future<void> _replaySchool(BuildContext sheetContext) async {
    await ref.read(streamSchoolCompletedProvider.notifier).reset();
    if (!mounted || !sheetContext.mounted) return;
    Navigator.of(sheetContext).pop();
  }

  void _openLauncher() {
    showAppSheet<void>(
      context,
      builder: (sheetContext) => StreamLauncher(
        onClose: () => Navigator.of(sheetContext).pop(),
        onSelected: (destination) {
          Navigator.of(sheetContext).pop();
          _goToDestination(destination);
        },
      ),
    );
  }

  /// Shell branches use `go` because pushing a branch would mount a second
  /// AppShell. Top-level screens push so the Stream stays on the back stack.
  void _goToDestination(StreamLauncherDestination destination) {
    final router = GoRouter.maybeOf(context);
    if (router == null) return;
    if (destination.keepsStreamOnStack) {
      router.push(destination.route);
    } else {
      router.go(destination.route);
    }
  }

  CaptureLocale _captureLocale(BuildContext context) =>
      Localizations.localeOf(context).languageCode == 'pt'
      ? CaptureLocale.pt
      : CaptureLocale.en;

  Widget _compact(Widget header, Widget body, Widget dock) => Column(
    children: [
      header,
      Expanded(child: body),
      dock,
    ],
  );

  Widget _medium(Widget header, Widget body, Widget dock) => Column(
    children: [
      header,
      Expanded(
        child: Row(
          children: [
            Expanded(child: body),
            const SizedBox(key: Key('sidePanelPlaceholder'), width: 200),
          ],
        ),
      ),
      dock,
    ],
  );

  Widget _expanded(Widget header, Widget body, Widget dock) => Row(
    children: [
      const SizedBox(key: Key('leftPanelPlaceholder'), width: 240),
      Expanded(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Column(
              children: [
                header,
                Expanded(child: body),
                dock,
              ],
            ),
          ),
        ),
      ),
      const SizedBox(key: Key('rightInspectorPlaceholder'), width: 320),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final params = _resolveParams();
    final level = streamLevelForZoom(params.zoom);
    final mode = ref.watch(streamThemeProvider);
    final brightness = MediaQuery.platformBrightnessOf(context);
    final theme = streamThemeData(mode, brightness);
    final l = AppLocalizations.of(context);
    final now = widget.now ?? DateTime.now();
    final StreamSyncStatus syncStatus =
        widget.syncStatus ?? ref.watch(streamSyncStatusProvider);
    final syncLabel =
        widget.syncLabel ??
        (widget.syncStatus == null ? _syncLabel(l, syncStatus) : null);
    final header = Semantics(
      container: true,
      explicitChildNodes: true,
      child: StreamHeader(
        dateLabel:
            '${DateFormat('EEE d MMM').format(params.date)} '
            '(${formatStreamDate(params.date)})',
        levelLabel: _levelLabel(l, level),
        slippedCount: 0,
        onOpenCommand: _onBreadcrumbTap,
        menuLabel: l.streamLauncherMenu,
        onOpenMenu: _openLauncher,
        syncStatus: syncStatus,
        syncLabel: syncLabel,
        settingsLabel: l.streamSettings,
        onOpenSettings: _openSettings,
      ),
    );
    final body = _levelBody(level: level, params: params, now: now, l: l);
    final dock = StreamDockHost(now: now, locale: _captureLocale(context));

    return Theme(
      data: theme,
      child: CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          const SingleActivator(LogicalKeyboardKey.keyK, control: true):
              _openPalette,
          const SingleActivator(LogicalKeyboardKey.keyK, meta: true):
              _openPalette,
        },
        child: Focus(
          focusNode: _shortcutFocus,
          autofocus: true,
          includeSemantics: false,
          child: StreamSchoolHost(
            child: Scaffold(
              backgroundColor: theme.scaffoldBackgroundColor,
              body: Stack(
                children: [
                  SafeArea(
                    child: Semantics(
                      container: true,
                      explicitChildNodes: true,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final layoutMode = streamLayoutModeForWidth(
                            constraints.maxWidth,
                          );
                          switch (layoutMode) {
                            case StreamLayoutMode.compact:
                              return _compact(header, body, dock);
                            case StreamLayoutMode.medium:
                              return _medium(header, body, dock);
                            case StreamLayoutMode.expanded:
                              return _expanded(header, body, dock);
                          }
                        },
                      ),
                    ),
                  ),
                  StreamCommandOverlay(
                    open: _paletteOpen,
                    now: now,
                    labels: StreamCommandOverlayLabels.of(l),
                    onClose: _closePalette,
                    onSelected: (intent) =>
                        unawaited(_handleCommandIntent(intent)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
