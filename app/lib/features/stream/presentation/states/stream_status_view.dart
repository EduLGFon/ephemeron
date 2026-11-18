// Pure selector: maps StreamStatus to the matching designed state (or nothing).
import 'package:material_ui/material_ui.dart';

import 'stream_empty_state.dart';
import 'stream_error_state.dart';
import 'stream_offline_banner.dart';
import 'stream_skeleton.dart';

enum StreamStatus { ready, empty, loadingRemote, error, offline }

class StreamStatusView extends StatelessWidget {
  const StreamStatusView({
    super.key,
    required this.status,
    this.emptyTitle,
    this.emptyBody,
    this.emptyActionLabel,
    this.onEmptyAction,
    this.emptySecondaryLabel,
    this.onEmptySecondary,
    this.errorTitle,
    this.errorBody,
    this.retryLabel,
    this.onRetry,
    this.errorSecondaryLabel,
    this.onSecondaryAction,
    this.offlineMessage,
    this.offlineRetryLabel,
    this.onOfflineRetry,
    this.offlineLiveRegion = false,
    this.skeletonItemCount = 3,
  });

  final StreamStatus status;
  final String? emptyTitle;
  final String? emptyBody;
  final String? emptyActionLabel;
  final VoidCallback? onEmptyAction;
  final String? emptySecondaryLabel;
  final VoidCallback? onEmptySecondary;
  final String? errorTitle;
  final String? errorBody;
  final String? retryLabel;
  final VoidCallback? onRetry;
  final String? errorSecondaryLabel;
  final VoidCallback? onSecondaryAction;
  final String? offlineMessage;
  final String? offlineRetryLabel;
  final VoidCallback? onOfflineRetry;
  final bool offlineLiveRegion;
  final int skeletonItemCount;

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case StreamStatus.ready:
        return const SizedBox.shrink();
      case StreamStatus.empty:
        return StreamEmptyState(
          title: emptyTitle ?? '',
          body: emptyBody,
          actionLabel: emptyActionLabel,
          onAction: onEmptyAction,
          secondaryActionLabel: emptySecondaryLabel,
          onSecondaryAction: onEmptySecondary,
        );
      case StreamStatus.loadingRemote:
        return StreamSkeleton(itemCount: skeletonItemCount);
      case StreamStatus.error:
        return StreamErrorState(
          title: errorTitle ?? '',
          body: errorBody,
          retryLabel: retryLabel,
          onRetry: onRetry,
          secondaryActionLabel: errorSecondaryLabel,
          onSecondaryAction: onSecondaryAction,
        );
      case StreamStatus.offline:
        return StreamOfflineBanner(
          message: offlineMessage ?? '',
          retryLabel: offlineRetryLabel,
          onRetry: onOfflineRetry,
          liveRegion: offlineLiveRegion,
        );
    }
  }
}
