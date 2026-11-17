/// Stream header sync state derived from the combined sync status. The Stream
/// surface does not own a sync source; this only translates the existing
/// Google/Microsoft plus backend status into the header's four states.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../sync/application/sync_providers.dart';
import '../../sync/data/sync_engine.dart' show SyncStatus;
import '../presentation/stream_header.dart' show StreamSyncStatus;

/// Pure mapping from the combined sync status to the header dot state.
StreamSyncStatus streamSyncStatusFromSync(SyncStatus status) =>
    switch (status) {
      SyncStatus.synced => StreamSyncStatus.synced,
      SyncStatus.syncing => StreamSyncStatus.syncing,
      SyncStatus.offline => StreamSyncStatus.offline,
      SyncStatus.error => StreamSyncStatus.attention,
    };

/// Live header status. Watches the existing combined status so a backend or
/// Google sync change updates the dot without a new sync source.
final streamSyncStatusProvider = Provider<StreamSyncStatus>((ref) {
  return streamSyncStatusFromSync(ref.watch(combinedSyncStatusProvider));
});
