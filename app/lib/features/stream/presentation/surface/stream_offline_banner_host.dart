// Inline host for the live offline banner.
//
// Presentation only: watches the shared Stream sync status and renders the
// existing [StreamOfflineBanner] in normal flow while offline. It never
// overlays content or uses a snackbar. Message and retry labels come from the
// caller so the active locale stays with the app shell.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../application/stream_sync_status.dart';
import '../states/stream_offline_banner.dart';
import '../stream_header.dart' show StreamSyncStatus;

class StreamOfflineBannerHost extends ConsumerWidget {
  const StreamOfflineBannerHost({
    super.key,
    required this.message,
    required this.retryLabel,
    required this.onRetry,
    this.statusOverride,
  });

  /// Caller-localized offline message.
  final String message;

  /// Caller-localized retry action label.
  final String retryLabel;

  final VoidCallback onRetry;

  /// Test-only status; when set the live provider is not read.
  final StreamSyncStatus? statusOverride;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = statusOverride ?? ref.watch(streamSyncStatusProvider);
    if (status != StreamSyncStatus.offline) {
      return const SizedBox.shrink();
    }
    return StreamOfflineBanner(
      message: message,
      retryLabel: retryLabel,
      onRetry: onRetry,
    );
  }
}
