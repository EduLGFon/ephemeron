// Stream Peek sheet: loads a day mark through the peek target provider and
// saves task edits through the reviewed peek actions. Presentation only.
import 'dart:async';

import 'package:ephemeron/l10n/src/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/ui/app_feedback.dart';
import '../../../../core/ui/app_sheet.dart';
import '../../../../core/ui/sheet_padding.dart';
import '../../application/stream_day_mark.dart';
import '../../application/stream_peek_actions.dart';
import '../../application/stream_peek_target.dart';
import '../../../tasks/application/tasks_providers.dart' show taskListsProvider;
import '../peek/peek_data.dart';
import '../peek/peek_editor_state.dart';
import '../peek/peek_panel.dart';
import '../stream_time_format.dart';

part 'stream_peek_sheet_content.dart';

/// Opens the Stream Peek sheet for [mark].
Future<void> showStreamPeek(
  BuildContext context, {
  required StreamDayMark mark,
}) {
  return showGuardedAppSheet<void>(
    context,
    builder: (sheetContext) => StreamPeekSheet(
      mark: mark,
      onClose: () => Navigator.of(sheetContext).pop(),
    ),
    isDismissible: false,
    enableDrag: false,
    showDragHandle: false,
  );
}

/// Modal body for a Stream mark.
///
/// The body owns loading, not-found and read-only states; task edits go
/// through the reviewed Peek actions. [onClose] is the only dismissal path, so
/// callers control the route.
class StreamPeekSheet extends ConsumerStatefulWidget {
  const StreamPeekSheet({super.key, required this.mark, required this.onClose});

  final StreamDayMark mark;
  final VoidCallback onClose;

  @override
  ConsumerState<StreamPeekSheet> createState() => _StreamPeekSheetState();
}

class _StreamPeekSheetState extends ConsumerState<StreamPeekSheet> {
  final GlobalKey<PeekEditorState> _editorKey = GlobalKey<PeekEditorState>();
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final target = ref.watch(streamPeekTargetProvider(widget.mark));
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _requestClose();
      },
      child: Padding(
        padding: sheetPadding(context),
        child: SingleChildScrollView(child: _body(context, l, target)),
      ),
    );
  }

  void _requestClose() {
    if (_editorKey.currentState?.hasChanges ?? false) {
      unawaited(_confirmDiscard());
    } else {
      widget.onClose();
    }
  }

  Future<int?> _pickTime(BuildContext context, int currentMs) async {
    final current = DateTime.fromMillisecondsSinceEpoch(currentMs);
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
      initialEntryMode: TimePickerEntryMode.input,
    );
    if (picked == null) return null;
    return DateTime(
      current.year,
      current.month,
      current.day,
      picked.hour,
      picked.minute,
    ).millisecondsSinceEpoch;
  }

  Widget _body(
    BuildContext context,
    AppLocalizations l,
    AsyncValue<StreamPeekTarget?> target,
  ) {
    return target.when(
      loading: () => _status(l, _Loading(label: l.streamPeekLoading)),
      error: (_, _) => _status(
        l,
        _LoadError(
          message: l.streamPeekLoadFailed,
          retryLabel: l.streamPeekRetry,
          onRetry: () => ref.invalidate(streamPeekTargetProvider(widget.mark)),
        ),
      ),
      data: (value) {
        if (value == null) {
          return _status(l, _NotFound(label: l.streamPeekNotFound));
        }
        if (!value.editable) {
          return _status(
            l,
            _ReadOnlySummary(
              data: value.data,
              formatTime: (ms) => _formatTime(context, ms),
              readOnlyLabel: l.streamPeekReadOnly,
              startLabel: l.streamPeekFieldStart,
              endLabel: l.streamPeekFieldEnd,
            ),
          );
        }
        return _editable(context, l, value);
      },
    );
  }

  Widget _status(AppLocalizations l, Widget child) {
    return _StatusBody(
      title: l.streamPeekTitle,
      closeLabel: l.streamPeekClose,
      onClose: widget.onClose,
      child: child,
    );
  }

  Widget _editable(
    BuildContext context,
    AppLocalizations l,
    StreamPeekTarget target,
  ) {
    final lists = ref.watch(taskListsProvider).value;
    final options = lists == null
        ? null
        : [
            for (final list in lists)
              PeekListOption(id: list.id, name: list.name),
          ];
    final currentListId = target.data.listId;
    final listOptions =
        options != null &&
            currentListId != null &&
            !options.any((option) => option.id == currentListId)
        ? null
        : options;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PeekPanel(
          data: target.data,
          expanded: true,
          editorKey: _editorKey,
          formatTime: (ms) => _formatTime(context, ms),
          onPickTime: _pickTime,
          listOptions: listOptions,
          priorityLabels: [
            l.streamPeekPriorityNone,
            l.streamPeekPriorityLow,
            l.streamPeekPriorityMedium,
            l.streamPeekPriorityHigh,
          ],
          saveLabel: l.streamPeekSave,
          cancelLabel: l.streamPeekCancel,
          closeLabel: l.streamPeekClose,
          panelLabel: l.streamPeekPanel,
          onSave: (edit) => unawaited(_save(target, edit)),
          onCancel: widget.onClose,
          onDiscardRequested: () => unawaited(_confirmDiscard()),
          emptyTitleLabel: l.streamPeekEmptyTitle,
          endBeforeStartLabel: l.streamPeekEndBeforeStart,
          titleLabel: l.streamPeekFieldTitle,
          startLabel: l.streamPeekFieldStart,
          endLabel: l.streamPeekFieldEnd,
          listLabel: l.streamPeekFieldList,
          notesLabel: l.streamPeekFieldNotes,
          addEndLabel: l.streamPeekAddEnd,
          clearEndLabel: l.streamPeekClearEnd,
        ),
      ],
    );
  }

  Future<void> _save(StreamPeekTarget target, PeekEdit edit) async {
    if (_saving) return;
    _saving = true;
    try {
      await ref.read(streamPeekActionsProvider).save(target, edit);
      if (!mounted || !context.mounted) return;
      final l = AppLocalizations.of(context);
      AppFeedback.success();
      showAppSnackBar(
        context,
        l.streamPeekSaved,
        icon: Icons.check_circle_outline,
      );
      widget.onClose();
    } catch (_) {
      if (!mounted || !context.mounted) return;
      final l = AppLocalizations.of(context);
      AppFeedback.error();
      showErrorSnackBar(context, l.streamPeekSaveFailed);
    } finally {
      _saving = false;
    }
  }

  Future<void> _confirmDiscard() async {
    final discard = await _showDiscardDialog(context);
    if (!context.mounted || !discard) return;
    widget.onClose();
  }
}
