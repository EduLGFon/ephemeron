// Riverpod providers for countdowns. UI reads only from Drift streams.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/db_provider.dart';
import '../../../data/drift/app_database.dart';
import '../../../data/repositories/countdown_repository.dart';

final countdownRepositoryProvider = Provider<CountdownRepository>((ref) {
  return CountdownRepository(ref.watch(appDatabaseProvider));
});

final countdownsProvider = StreamProvider<List<Countdown>>((ref) {
  return ref.watch(countdownRepositoryProvider).watchCountdowns();
});

/// Live countdowns linked to one event/task/habit.
final linkedCountdownsProvider = StreamProvider.autoDispose
    .family<List<Countdown>, ({String type, String id})>(
      (ref, link) => ref
          .watch(countdownRepositoryProvider)
          .watchLinkedCountdowns(link.type, link.id),
    );
