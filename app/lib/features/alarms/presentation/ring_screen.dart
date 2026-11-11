// Ring screen: cannot be dismissed with back; Snooze, Dismiss, or a
// context action is required. Auto-snoozes after 30 s of no interaction.
import 'dart:async';

// drift query extensions.
// ignore: unused_import
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../core/db/db_provider.dart';
import '../../../data/drift/app_database.dart';
import '../../../domain/alarms/alarm_preset.dart';
import '../application/alarm_providers.dart';
import '../data/alarm_repository.dart';
import 'alarm_preset_picker.dart';

/// Only a row that is actually firing may open the ring screen or bypass the
/// biometric gate. A native intent alone is never trusted.
bool canOpenRingScreen(String? rowState) => rowState == 'fired';

class RingScreen extends ConsumerStatefulWidget {
  const RingScreen({super.key});

  @override
  ConsumerState<RingScreen> createState() => _RingScreenState();
}

class _RingScreenState extends ConsumerState<RingScreen> {
  Timer? _auto;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    unawaited(_setImmersive(true));
    unawaited(_setWakelock(true));
    _startAutoSnooze();
  }

  @override
  void dispose() {
    _auto?.cancel();
    unawaited(_setImmersive(false));
    unawaited(_setWakelock(false));
    super.dispose();
  }

  Future<void> _setImmersive(bool enabled) async {
    try {
      await SystemChrome.setEnabledSystemUIMode(
        enabled ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
      );
    } catch (_) {}
  }

  Future<void> _setWakelock(bool enabled) async {
    try {
      if (enabled) {
        await WakelockPlus.enable();
      } else {
        await WakelockPlus.disable();
      }
    } catch (_) {}
  }

  /// Restarts the 30 s auto-snooze window; a new ring request while the
  /// screen is open must not inherit the previous alarm's remaining time.
  void _startAutoSnooze() {
    if (_busy) return;
    _auto?.cancel();
    _auto = Timer(const Duration(seconds: 30), () {
      unawaited(_snooze());
    });
  }

  String _baseSourceId(String sourceId) {
    final at = sourceId.indexOf('@');
    if (at >= 0) return sourceId.substring(0, at);
    final hash = sourceId.indexOf('#');
    return hash >= 0 ? sourceId.substring(0, hash) : sourceId;
  }

  /// Loads the ring row for the active request code, falling back to the
  /// latest fired alarm when the route was opened without a request.
  Future<AlarmsIndexData?> _loadAlarm(int? requestCode) {
    final repo = ref.read(alarmRepositoryProvider);
    if (requestCode != null) return repo.byRequestCode(requestCode);
    return repo.latestFired();
  }

  /// Request code for the actions: the active native ring request wins,
  /// then the loaded row.
  int? _requestCode(AlarmsIndexData? alarm) =>
      ref.read(activeRingRequestProvider) ?? alarm?.requestCode;

  Future<int?> _resolveCode(int? code) async {
    if (code != null) return code;
    final active = ref.read(activeRingRequestProvider);
    if (active != null) return active;
    try {
      return (await ref.read(alarmRepositoryProvider).latestFired())
          ?.requestCode;
    } catch (_) {
      return null;
    }
  }

  Future<bool> _isNumericHabit(String? sourceType, String? sourceId) async {
    if (sourceType == null || sourceId == null) return false;
    if (sourceType != 'habit' && sourceType != 'habit_reminder') return false;
    final db = ref.read(appDatabaseProvider);
    final habit = await (db.select(
      db.habits,
    )..where((h) => h.id.equals(_baseSourceId(sourceId)))).getSingleOrNull();
    return (habit?.goalAmount ?? 0) > 0;
  }

  Future<void> _snooze({int minutes = 10, int? code}) async {
    await _act(
      code,
      (requestCode) => ref
          .read(alarmRepositoryProvider)
          .snoozeRequest(requestCode, minutes: minutes),
      rebuild: false,
    );
  }

  /// Runs one ring action, then clears the verified ring request and leaves.
  /// Done/Dismiss rebuild the alarm window so the next occurrence is
  /// scheduled; Snooze must not rebuild because that would cancel the snooze.
  /// The rebuild is fire-and-forget so the route change lands before the
  /// biometric gate replaces the app subtree.
  Future<void> _act(
    int? code,
    Future<void> Function(int requestCode) action, {
    required bool rebuild,
  }) async {
    if (_busy) return;
    _busy = true;
    _auto?.cancel();
    try {
      final requestCode = await _resolveCode(code);
      if (requestCode != null) await action(requestCode);
    } catch (_) {
      // The native notification/ring is already stopped; never trap the
      // user on the ring screen because of a DB failure.
    } finally {
      if (mounted) {
        ref.read(activeRingRequestProvider.notifier).clear();
        if (rebuild) {
          final repo = ref.read(alarmRepositoryProvider);
          unawaited(_rebuildWindow(repo));
        }
        if (mounted) _leaveRing();
      }
    }
  }

  Future<void> _rebuildWindow(AlarmRepository repo) async {
    try {
      await repo.rebuildWindow();
    } catch (_) {}
  }

  void _leaveRing() {
    if (!mounted) return;
    try {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/tab0');
      }
    } catch (_) {
      if (mounted) context.go('/tab0');
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeCode = ref.watch(activeRingRequestProvider);
    ref.listen<int?>(activeRingRequestProvider, (previous, next) {
      if (previous != next) _startAutoSnooze();
    });
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: FutureBuilder<AlarmsIndexData?>(
            future: _loadAlarm(activeCode),
            builder: (ctx, snap) {
              final alarm = snap.data;
              final preset = AlarmPreset.tryParse(alarm?.preset);
              final long = preset == AlarmPreset.fullScreenLong;
              final isHabit =
                  alarm?.sourceType == 'habit' ||
                  alarm?.sourceType == 'habit_reminder';
              return FutureBuilder<bool>(
                future: _isNumericHabit(alarm?.sourceType, alarm?.sourceId),
                builder: (ctx, numSnap) {
                  final numeric = isHabit && (numSnap.data ?? false);
                  return LayoutBuilder(
                    builder: (ctx, constraints) => SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 32,
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight > 64
                              ? constraints.maxHeight - 64
                              : 0,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              long ? Icons.alarm_on : Icons.alarm,
                              size: 96,
                              color: long ? Colors.redAccent : Colors.white,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              preset?.title ?? 'Alarm',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              alarm?.title ?? 'Alarm',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            if (long)
                              const Padding(
                                padding: EdgeInsets.only(top: 8),
                                child: Text(
                                  'Repeats every minute until resolved.',
                                  style: TextStyle(
                                    color: Colors.redAccent,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            const SizedBox(height: 24),
                            SnoozePicker(
                              onPick: (m) => _snooze(
                                minutes: m,
                                code: _requestCode(alarm),
                              ),
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size.fromHeight(56),
                                  textStyle: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                onPressed: () => _act(
                                  _requestCode(alarm),
                                  (code) => ref
                                      .read(alarmRepositoryProvider)
                                      .markDone(code),
                                  rebuild: true,
                                ),
                                child: const Text('Done'),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                OutlinedButton(
                                  onPressed: () =>
                                      _snooze(code: _requestCode(alarm)),
                                  child: const Text('Snooze'),
                                ),
                                if (numeric)
                                  OutlinedButton(
                                    onPressed: () => _act(
                                      _requestCode(alarm),
                                      (code) => ref
                                          .read(alarmRepositoryProvider)
                                          .completeHabitPlusOne(code),
                                      rebuild: true,
                                    ),
                                    child: const Text('+1'),
                                  ),
                                TextButton(
                                  onPressed: () => _act(
                                    _requestCode(alarm),
                                    (code) => ref
                                        .read(alarmRepositoryProvider)
                                        .dismissRequest(code),
                                    rebuild: true,
                                  ),
                                  child: const Text(
                                    'Dismiss',
                                    style: TextStyle(color: Colors.white70),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: () => _act(
                                _requestCode(alarm),
                                (code) => ref
                                    .read(alarmRepositoryProvider)
                                    .dismissRequest(code),
                                rebuild: true,
                              ),
                              child: const Text(
                                'Open item',
                                style: TextStyle(color: Colors.white54),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
