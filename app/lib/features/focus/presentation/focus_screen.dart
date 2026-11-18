// Focus screen: timestamp-based timer, one native end alarm, pause/resume as
// finished segments, stats, session history and CSV export. Widgets live in
// part files so only the timer face rebuilds every second.
import 'dart:async';

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../core/design/components/app_buttons.dart';
import '../../../core/design/components/app_chips.dart';
import '../../../core/design/components/app_fields.dart';
import '../../../core/design/components/app_headers.dart';
import '../../../core/design/components/app_overlays.dart';
import '../../../core/design/components/app_page.dart';
import '../../../core/design/components/app_states.dart';
import '../../../core/design/components/app_surface.dart';
import '../../../core/design/components/visuals.dart';
import '../../../core/design/tokens.dart';
import '../../../core/design/typography.dart';
import '../../../core/platform/app_permissions.dart';
import '../../../core/platform/system_launcher.dart';
import '../../../core/time/device_date_format.dart';
import '../../../core/time/time.dart';
import '../../../core/ui/app_feedback.dart';

import '../../../data/drift/app_database.dart';
import '../../../domain/alarms/alarm_preset.dart';
import '../../../domain/habits/date_key.dart';
import '../../../domain/habits/habit_timer.dart';
import '../../alarms/data/alarm_scheduler.dart';
import '../../alarms/presentation/alarm_preset_picker.dart';
import '../../habits/application/habits_providers.dart';
import '../../settings/application/settings_providers.dart';
import '../../sync/application/pending_operations.dart';
import '../application/focus_providers.dart';
import 'focus_stats_screen.dart';
import 'focus_strings.dart';

part 'focus_screen_start.dart';
part 'focus_screen_running.dart';
part 'focus_screen_running_actions.dart';
part 'focus_screen_shared.dart';
part 'focus_visuals.dart';

const _focusPresets = [15, 25, 50];
const _breakPresets = [5, 10, 15];

/// Returns an error message when [raw] is not a whole number inside the
/// allowed focus/break range. Pure so the custom duration path stays testable.
String? validateFocusMinutes(String raw, {required bool isBreak}) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return 'Enter minutes.';
  final value = int.tryParse(trimmed);
  if (value == null) return 'Enter a whole number.';
  final max = isBreak ? 60 : 240;
  if (value < 1 || value > max) return 'Enter 1-$max minutes.';
  return null;
}

class FocusScreen extends ConsumerStatefulWidget {
  const FocusScreen({super.key});

  @override
  ConsumerState<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends ConsumerState<FocusScreen> {
  PausedFocusSegment? _paused;

  void _onStarted() {
    if (_paused != null) setState(() => _paused = null);
  }

  @override
  Widget build(BuildContext context) {
    final strings = FocusStrings.of(context);
    final currentAsync = ref.watch(currentFocusSessionProvider);
    return AppPage(
      header: AppPageHeader(
        title: Text(strings.title),
        actions: [
          AppIconButton(
            icon: Icons.bar_chart_outlined,
            tooltip: strings.statsTooltip,
            semanticLabel: strings.statsTooltip,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const FocusStatsScreen()),
            ),
          ),
          AppIconButton(
            icon: Icons.download_outlined,
            tooltip: strings.exportTooltip,
            semanticLabel: strings.exportTooltip,
            onPressed: () => _exportCsv(context, ref, strings),
          ),
        ],
      ),
      child: currentAsync.when(
        loading: () => const AppSkeletonList(rows: 4),
        error: (_, _) => Center(
          child: AppButton(
            label: strings.retry,
            onPressed: () => ref.invalidate(currentFocusSessionProvider),
          ),
        ),
        data: (session) => session == null
            ? _StartView(
                paused: _paused,
                onStarted: _onStarted,
                onPausedCleared: () {
                  if (_paused != null) setState(() => _paused = null);
                },
              )
            : _RunningView(
                session: session,
                onPaused: (segment) => setState(() => _paused = segment),
              ),
      ),
    );
  }
}

Future<void> _exportCsv(
  BuildContext context,
  WidgetRef ref,
  FocusStrings strings,
) async {
  final sessions = ref.read(recentFocusSessionsProvider).value ?? const [];
  final buffer = StringBuffer('start,end,minutes,phase,note\n');
  for (final session in sessions) {
    buffer.writeln(
      '${session.startUtc},${session.endUtc ?? ''},'
      '${session.endUtc == null ? '' : ((session.endUtc! - session.startUtc) / msPerMinute).floor()},'
      '${session.phase ?? ''},'
      '${(session.note ?? '').replaceAll(',', ';')}',
    );
  }
  await Clipboard.setData(ClipboardData(text: buffer.toString()));
  if (context.mounted) showAppSnackBar(context, strings.csvCopied);
}

void _refresh(WidgetRef ref) {
  ref.invalidate(currentFocusSessionProvider);
  ref.invalidate(focusTodayMinutesProvider);
  ref.invalidate(focusWeekMinutesProvider);
  ref.invalidate(breakTodayMinutesProvider);
  ref.invalidate(breakWeekMinutesProvider);
  ref.invalidate(focusMonthMinutesProvider);
  ref.invalidate(breakMonthMinutesProvider);
  ref.invalidate(recentFocusSessionsProvider);
}

int _requestCode(String id) => id.hashCode & 0x7fffffff;

Future<void> _scheduleEndAlarm(FocusSession session, FocusStrings strings) {
  final target = session.targetEndUtc;
  if (target == null) return Future.value();
  final preset =
      parseAlarmPreset(session.alarmPreset) ?? AlarmPreset.notification;
  final phase = session.phase ?? 'focus';
  final isBreak = phase == 'break';
  return AlarmScheduler.schedulePreset(
    requestCode: _requestCode(session.id),
    fireAtUtcMs: target,
    preset: preset,
    title: isBreak ? strings.completeTitleBreak : strings.completeTitleFocus,
    body: isBreak ? strings.alarmBreakBody : strings.alarmFocusBody,
    sourceType: 'focus',
    sourceId: session.id,
    phase: phase,
  );
}

Future<void> _startSession(
  BuildContext context,
  WidgetRef ref, {
  String? taskId,
  String? habitId,
  required int? durationMin,
  required String phase,
  String? alarmPreset,
  String? note,
}) async {
  final strings = FocusStrings.of(context);
  final isStopwatch = durationMin == null;
  final preset = AlarmPreset.tryParse(alarmPreset);
  if (!isStopwatch) {
    await AppPermissions.ensureAlarmPrereqs(
      context,
      exactAlarm: preset?.needsAlarmClock ?? false,
      fullScreen: preset?.usesFullScreen ?? false,
    );
    if (!context.mounted) return;
  }
  AppFeedback.tap();
  final repo = ref.read(focusRepositoryProvider);
  final id = await repo.startSession(
    taskId: taskId,
    habitId: habitId,
    durationMin: durationMin,
    phase: phase,
    alarmPreset: isStopwatch ? null : alarmPreset,
  );
  if (note != null && note.isNotEmpty) await repo.updateNote(id, note);
  final session = await repo.currentSession();
  if (session != null && session.id == id) {
    await _scheduleEndAlarm(session, strings);
    await SystemLauncher.startFocusChronometer(
      phase == 'break' ? strings.modeBreak : strings.modeFocus,
      session.startUtc,
      targetUtcMs: session.targetEndUtc,
    );
    try {
      final settings = await ref.read(settingsRepositoryProvider.future);
      if (settings.focusDnd) await SystemLauncher.setDnd(true);
    } catch (_) {
      // DND is best-effort; the session runs regardless.
    }
  }
  _refresh(ref);
}
