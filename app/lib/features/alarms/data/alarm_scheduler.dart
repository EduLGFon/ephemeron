// AlarmScheduler is the ONLY place that schedules OS alarms/notifications.
// Native code does the ringing; Dart only registers and mirrors state.
// On Android it uses the ephemeron/alarms channel. On other platforms it
// delegates to the in-app fallback engine (dialog + short sound).
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../../core/logger/logger.dart';
import '../../../domain/alarms/alarm_preset.dart';

final _log = AppLogger();

class AlarmScheduler {
  static const _channel = MethodChannel('ephemeron/alarms');

  /// Request code whose long ring currently owns audio, or null.
  /// Set by [startRing] after the native service starts and cleared by
  /// [stopRing], [cancel] (snooze/done/dismiss), and [cancelAll]. Window
  /// reconciliation uses it so an actively ringing row is never settled
  /// just because its fire time is old.
  static int? activeRingRequestCode;

  static Future<bool> get isSupported async {
    if (defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      final v = await _channel.invokeMethod<bool>('ping');
      return v ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> schedule({
    required int requestCode,
    required int fireAtUtcMs,
    required bool useAlarmClock,
    required String title,
    String preset = 'notification',
    String? sourceType,
    String? sourceId,
    String? phase,
    String kind = 'alarm',
    String body = '',
    bool fullScreen = false,
  }) async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      _log.debug('alarm schedule stubbed on $defaultTargetPlatform');
      return;
    }
    await _channel.invokeMethod<void>('schedule', {
      'requestCode': requestCode,
      'fireAtUtcMs': fireAtUtcMs,
      'useAlarmClock': useAlarmClock,
      'title': title,
      'body': body,
      'preset': preset,
      'sourceType': sourceType,
      'sourceId': sourceId,
      'phase': phase,
      'kind': kind,
      'fullScreen': fullScreen,
    });
  }

  /// Schedules one fire with the correct native flags for [preset].
  static Future<void> schedulePreset({
    required int requestCode,
    required int fireAtUtcMs,
    required AlarmPreset preset,
    required String title,
    String body = '',
    String? sourceType,
    String? sourceId,
    String? phase,
    String kind = 'alarm',
  }) {
    return schedule(
      requestCode: requestCode,
      fireAtUtcMs: fireAtUtcMs,
      useAlarmClock: preset.needsAlarmClock,
      title: title,
      body: body,
      preset: preset.id,
      sourceType: sourceType,
      sourceId: sourceId,
      phase: phase,
      kind: kind,
      fullScreen: preset.usesFullScreen,
    );
  }

  /// Plain early/at-time reminder: always a short-sound notification,
  /// never full-screen, never looping.
  static Future<void> scheduleReminder({
    required int requestCode,
    required int fireAtUtcMs,
    required String title,
    String body = '',
    String? sourceType,
    String? sourceId,
  }) {
    return schedule(
      requestCode: requestCode,
      fireAtUtcMs: fireAtUtcMs,
      useAlarmClock: false,
      title: title,
      body: body,
      preset: AlarmPreset.notification.id,
      sourceType: sourceType,
      sourceId: sourceId,
      kind: 'reminder',
      fullScreen: false,
    );
  }

  static Future<void> cancel(int requestCode) async {
    if (activeRingRequestCode == requestCode) activeRingRequestCode = null;
    if (defaultTargetPlatform != TargetPlatform.android) return;
    await _channel.invokeMethod<void>('cancel', {'requestCode': requestCode});
  }

  static Future<void> cancelAll() async {
    activeRingRequestCode = null;
    if (defaultTargetPlatform != TargetPlatform.android) return;
    await _channel.invokeMethod<void>('cancelAll');
  }

  /// Starts the native ring for a stored row. RingScreen calls this only
  /// after its first frame so sound never plays outside the visible screen.
  /// A successful start makes [activeRingRequestCode] protect the row from
  /// overdue reconciliation until it is stopped or resolved.
  static Future<bool> startRing(int requestCode) async {
    if (defaultTargetPlatform != TargetPlatform.android) return true;
    try {
      final v = await _channel.invokeMethod<bool>('startRing', {
        'requestCode': requestCode,
      });
      final started = v ?? false;
      if (started) activeRingRequestCode = requestCode;
      return started;
    } catch (_) {
      return false;
    }
  }

  /// Stops the native ring without touching the scheduled registration.
  /// A null [requestCode] stops every active ring.
  static Future<void> stopRing([int? requestCode]) async {
    if (requestCode == null || activeRingRequestCode == requestCode) {
      activeRingRequestCode = null;
    }
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _channel.invokeMethod<void>('stopRing', {
        'requestCode': requestCode,
      });
    } catch (_) {}
  }

  /// Test button: rings in 10 seconds with the given preset.
  static Future<void> testAlarm([
    AlarmPreset preset = AlarmPreset.notification,
  ]) async {
    await schedulePreset(
      requestCode: 1,
      fireAtUtcMs: DateTime.now().toUtc().millisecondsSinceEpoch + 10000,
      preset: preset,
      title: 'Test alarm',
      body: 'If you see this, alarms work.',
      sourceType: 'test',
      sourceId: 'test',
      kind: 'alarm',
    );
  }

  static Future<bool> canScheduleExact() async {
    if (defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      final v = await _channel.invokeMethod<bool>('canScheduleExact');
      return v ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> openExactAlarmSettings() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    await _channel.invokeMethod<void>('openExactAlarmSettings');
  }

  static Future<void> openBatterySettings() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    await _channel.invokeMethod<void>('openBatterySettings');
  }

  /// Requests iOS Critical Alerts authorization (needs the entitlement plus
  /// App Store approval; see docs/TODO.md). Returns true when granted.
  /// Always false off iOS or when the native handler is missing.
  static Future<bool> requestCriticalAlerts() async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return false;
    try {
      final v = await _channel.invokeMethod<bool>('requestCriticalAlerts');
      return v ?? false;
    } catch (_) {
      return false;
    }
  }
}
