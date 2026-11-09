// Providers for alarms.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/db_provider.dart';
import '../../../data/drift/app_database.dart';
import '../data/alarm_repository.dart';

final alarmRepositoryProvider = Provider<AlarmRepository>((ref) {
  return AlarmRepository(ref.watch(appDatabaseProvider));
});

final missedAlarmsProvider = StreamProvider<List<AlarmsIndexData>>((ref) {
  return ref.watch(alarmRepositoryProvider).watchMissed();
});

final upcomingAlarmsProvider = StreamProvider<List<AlarmsIndexData>>((ref) {
  return ref.watch(alarmRepositoryProvider).watchUpcoming();
});

/// Ring request code currently shown by the ring screen, or null when the
/// screen should fall back to the latest fired alarm.
class ActiveRingRequestNotifier extends Notifier<int?> {
  @override
  int? build() => null;

  void set(int requestCode) => state = requestCode;

  void clear() => state = null;
}

final activeRingRequestProvider =
    NotifierProvider<ActiveRingRequestNotifier, int?>(
      ActiveRingRequestNotifier.new,
    );
