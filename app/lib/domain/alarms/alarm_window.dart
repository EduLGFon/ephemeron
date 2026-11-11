import 'package:ephemeron/core/time/time.dart';

import 'alarm_preset.dart';

// Rolling alarm window (PLAN 7.1): keep the next 48 h plus the next N
// future alarms registered. Pure Dart; the native module mirrors this.
// Reminders (kind=reminder) and alarms (kind=alarm) share the window.
class AlarmCandidate {
  AlarmCandidate({
    required this.sourceType,
    required this.sourceId,
    required this.fireAtUtcMs,
    required this.preset,
    this.kind = 'alarm',
    this.title = '',
    this.allDay = false,
  });

  final String sourceType;
  final String sourceId;
  final int fireAtUtcMs;
  final String preset;
  final String kind;
  final String title;
  final bool allDay;
}

class PlannedAlarm {
  PlannedAlarm({
    required this.sourceType,
    required this.sourceId,
    required this.fireAtUtcMs,
    required this.preset,
    required this.requestCode,
    this.kind = 'alarm',
    this.title = '',
    this.allDay = false,
  });

  final String sourceType;
  final String sourceId;
  final int fireAtUtcMs;
  final String preset;
  final int requestCode;
  final String kind;
  final String title;
  final bool allDay;
}

/// Returns registrations ordered by fire time, capped at [maxFuture].
/// [reservedRequestCodes] keeps live registrations from being reassigned,
/// for example an alarm row that is currently ringing.
List<PlannedAlarm> planAlarmWindow(
  List<AlarmCandidate> candidates, {
  required int nowUtcMs,
  int horizonHours = 48,
  int maxFuture = 60,
  Set<int> reservedRequestCodes = const {},
}) {
  final horizonMs = nowUtcMs + horizonHours * msPerHour;
  final future = candidates.where((c) => c.fireAtUtcMs > nowUtcMs).toList()
    ..sort((a, b) => a.fireAtUtcMs.compareTo(b.fireAtUtcMs));
  final inHorizon = future.where((c) => c.fireAtUtcMs <= horizonMs).toList();
  final beyond = future
      .where((c) => c.fireAtUtcMs > horizonMs)
      .take(maxFuture)
      .toList();
  final picked = [...inHorizon, ...beyond];
  final planned = <PlannedAlarm>[];
  var code = 100000;
  for (final c in picked) {
    while (reservedRequestCodes.contains(code)) {
      code++;
    }
    planned.add(
      PlannedAlarm(
        sourceType: c.sourceType,
        sourceId: c.sourceId,
        fireAtUtcMs: c.fireAtUtcMs,
        preset: c.preset,
        requestCode: code,
        kind: c.kind,
        title: c.title,
        allDay: c.allDay,
      ),
    );
    code++;
  }
  return planned;
}

/// Full-screen presets need setAlarmClock; notification uses exact-idle.
bool needsAlarmClock(String preset) {
  final p = AlarmPreset.tryParse(preset);
  if (p != null) return p.needsAlarmClock;
  return preset == 'medium' || preset == 'strong' || preset == 'constant';
}

bool usesFullScreen(String preset) {
  final p = AlarmPreset.tryParse(preset);
  if (p != null) return p.usesFullScreen;
  return preset == 'medium' || preset == 'strong' || preset == 'constant';
}
