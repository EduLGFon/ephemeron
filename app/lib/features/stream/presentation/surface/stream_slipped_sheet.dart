// Slipped-task triage sheet. Loads overdue tasks from
// [streamSlippedItemsProvider], renders [SlippedTriage] and runs the four
// triage actions with undo. Presentation only: the time picker is injected so
// callers and tests can supply their own.
import 'dart:async';

import 'package:ephemeron/l10n/src/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/ui/app_feedback.dart';
import '../../../../core/ui/app_sheet.dart';
import '../../../../core/ui/escape_to_close.dart';
import '../../application/stream_slipped_data.dart';
import '../../design/stream_tokens.dart';
import '../platform/stream_undo.dart';
import '../slipped/slipped_action_labels.dart';
import '../slipped/slipped_item.dart';
import '../slipped/slipped_triage.dart';

part 'stream_slipped_sheet/actions.dart';
part 'stream_slipped_sheet/view.dart';

/// Resolves the start time for a slipped task. Returning null cancels.
typedef StreamSlippedTimePicker = Future<DateTime?> Function(
  BuildContext context,
  String taskId,
);

Future<DateTime?> _defaultTimePicker(
  BuildContext context,
  String taskId,
) async {
  final now = DateTime.now();
  final picked = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(now),
  );
  if (picked == null) return null;
  return DateTime(now.year, now.month, now.day, picked.hour, picked.minute);
}

/// Opens the slipped triage sheet. [timePicker] defaults to [showTimePicker].
Future<void> showStreamSlippedTriage(
  BuildContext context, {
  StreamSlippedTimePicker? timePicker,
}) {
  return showAppSheet<void>(
    context,
    builder: (sheetContext) => EscapeToClose(
      child: StreamSlippedSheet(
        onClose: () => Navigator.of(sheetContext).pop(),
        timePicker: timePicker,
      ),
    ),
  );
}

class StreamSlippedSheet extends ConsumerWidget {
  const StreamSlippedSheet({super.key, required this.onClose, this.timePicker});

  final VoidCallback onClose;
  final StreamSlippedTimePicker? timePicker;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final items = ref.watch(streamSlippedItemsProvider);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SheetHeader(
          title: l.streamSlippedTitle,
          closeLabel: l.streamSlippedClose,
          onClose: onClose,
        ),
        const Divider(height: 1),
        items.when(
          loading: () =>
              _SheetMessage(label: l.streamSlippedLoading, busy: true),
          error: (_, _) => _SheetMessage(label: l.streamSlippedLoadError),
          data: (items) => items.isEmpty
              ? _SheetMessage(label: l.streamSlippedEmpty)
              : _buildTriage(context, ref, l, items),
        ),
      ],
    );
  }

  Widget _buildTriage(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l,
    List<SlippedItem> items,
  ) {
    final wanted = items.length * slippedTriageItemExtent + StreamSpacing.x12;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.6;
    final picker = timePicker ?? _defaultTimePicker;
    return SizedBox(
      height: wanted > maxHeight ? maxHeight : wanted,
      child: SlippedTriage(
        items: items,
        daysOverdueLabel: (item) =>
            l.streamSlippedDaysOverdue(item.daysOverdue),
        actionLabels: SlippedActionLabels(
          done: l.streamSlippedDone,
          tomorrow: l.streamSlippedTomorrow,
          pickTime: l.streamSlippedPickTime,
          drop: l.streamSlippedDrop,
        ),
        hintLabel: l.streamSlippedHint,
        onDone: (id) => _done(context, ref, l, id),
        onTomorrow: (id) => _tomorrow(context, ref, l, id),
        onPickTime: (id) => unawaited(_pickTime(context, ref, l, picker, id)),
        onDrop: (id) => _drop(context, ref, l, id),
        // The sheet shows undo after the async action resolves; the triage
        // requests it synchronously, before a result exists.
        onUndoRequested: (_) {},
      ),
    );
  }
}
