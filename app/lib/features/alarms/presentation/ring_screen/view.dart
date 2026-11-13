part of '../ring_screen.dart';

mixin _RingScreenView on _RingScreenStateBase {
  void _startAutoSnooze();
  Future<void> _snooze({int minutes, int? code});
  Future<void> _act(
    int? code,
    Future<void> Function(int requestCode) action, {
    required bool rebuild,
    String? destination,
    bool successFeedback,
  });
  int? _requestCode(AlarmsIndexData? alarm);
  Future<AlarmsIndexData?> _loadAlarm(int? requestCode);
  Future<bool> _isNumericHabit(String? sourceType, String? sourceId);

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
              final sourceLabel = alarmSourceLabel(alarm?.sourceType);
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
                            if (sourceLabel != null) ...[
                              const SizedBox(height: AppSpace.md),
                              Semantics(
                                label: '$sourceLabel alarm',
                                excludeSemantics: true,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpace.md,
                                    vertical: AppSpace.xs,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white10,
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.pill,
                                    ),
                                    border: Border.all(color: Colors.white24),
                                  ),
                                  child: Text(
                                    sourceLabel,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: AppSpace.md),
                            Text(
                              preset?.title ?? 'Alarm',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: AppSpace.sm),
                            Semantics(
                              header: true,
                              child: Text(
                                alarm?.title ?? 'Alarm',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(height: AppSpace.sm),
                            const Text(
                              'Auto-snoozes in 30 s if untouched',
                              style: TextStyle(
                                color: Colors.white38,
                                fontSize: 12,
                              ),
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
                              onPick: (m) {
                                AppFeedback.tap();
                                _snooze(minutes: m, code: _requestCode(alarm));
                              },
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
                                onPressed: () {
                                  _act(
                                    _requestCode(alarm),
                                    (code) => ref
                                        .read(alarmRepositoryProvider)
                                        .markDone(code),
                                    rebuild: true,
                                    successFeedback: true,
                                  );
                                },
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
                                  onPressed: () {
                                    AppFeedback.tap();
                                    _snooze(code: _requestCode(alarm));
                                  },
                                  child: const Text('Snooze'),
                                ),
                                if (numeric)
                                  OutlinedButton(
                                    onPressed: () {
                                      _act(
                                        _requestCode(alarm),
                                        (code) => ref
                                            .read(alarmRepositoryProvider)
                                            .completeHabitPlusOne(code),
                                        rebuild: true,
                                        successFeedback: true,
                                      );
                                    },
                                    child: const Text('+1'),
                                  ),
                                TextButton(
                                  onPressed: () {
                                    AppFeedback.tap();
                                    _act(
                                      _requestCode(alarm),
                                      (code) => ref
                                          .read(alarmRepositoryProvider)
                                          .dismissRequest(code),
                                      rebuild: true,
                                    );
                                  },
                                  child: const Text(
                                    'Dismiss',
                                    style: TextStyle(color: Colors.white70),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: () {
                                AppFeedback.tap();
                                _act(
                                  _requestCode(alarm),
                                  (code) => ref
                                      .read(alarmRepositoryProvider)
                                      .dismissRequest(code),
                                  rebuild: true,
                                  destination: alarmSourceRoute(
                                    alarm?.sourceType,
                                  ),
                                );
                              },
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
