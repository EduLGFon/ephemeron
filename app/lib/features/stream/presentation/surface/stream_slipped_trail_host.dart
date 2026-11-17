// Slipped-task pill host under the Stream "Now" label.
//
// Presentation only: the count comes from [streamSlippedItemsProvider] and the
// existing [SlippedTrail] renders the single pill. The caller owns triage.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'package:ephemeron/l10n/src/app_localizations.dart';

import '../../application/stream_slipped_data.dart';
import '../slipped/slipped_trail.dart';

/// Count pill for slipped tasks, pinned under the Now label.
class StreamSlippedTrailHost extends ConsumerWidget {
  const StreamSlippedTrailHost({
    super.key,
    required this.onOpenTriage,
    this.color,
  });

  final VoidCallback onOpenTriage;
  final Color? color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Only the count is needed; the list itself stays in the provider.
    final count = ref.watch(streamSlippedItemsProvider).value?.length ?? 0;
    if (count <= 0) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);
    return SlippedTrail(
      count: count,
      label: l.streamSlippedCount(count),
      onOpenTriage: onOpenTriage,
      color: color,
    );
  }
}
