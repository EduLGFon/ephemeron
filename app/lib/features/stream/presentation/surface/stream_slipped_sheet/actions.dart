part of '../stream_slipped_sheet.dart';

void _done(BuildContext context, WidgetRef ref, AppLocalizations l, String id) {
  unawaited(
    _runAction(
      context,
      ref,
      l,
      (actions) => actions.done(id),
      l.streamSlippedDoneMessage,
    ),
  );
}

void _tomorrow(
  BuildContext context,
  WidgetRef ref,
  AppLocalizations l,
  String id,
) {
  unawaited(
    _runAction(
      context,
      ref,
      l,
      (actions) => actions.tomorrow(id),
      l.streamSlippedTomorrowMessage,
    ),
  );
}

void _drop(BuildContext context, WidgetRef ref, AppLocalizations l, String id) {
  unawaited(
    _runAction(
      context,
      ref,
      l,
      (actions) => actions.drop(id),
      l.streamSlippedDropMessage,
    ),
  );
}

Future<void> _pickTime(
  BuildContext context,
  WidgetRef ref,
  AppLocalizations l,
  StreamSlippedTimePicker picker,
  String id,
) async {
  final start = await picker(context, id);
  if (start == null || !context.mounted) return;
  await _runAction(
    context,
    ref,
    l,
    (actions) => actions.pickTime(id, start),
    l.streamSlippedPickTimeMessage,
  );
}

Future<void> _runAction(
  BuildContext context,
  WidgetRef ref,
  AppLocalizations l,
  Future<StreamSlippedResult> Function(StreamSlippedActions actions) action,
  String message,
) async {
  try {
    final result = await action(ref.read(streamSlippedActionsProvider));
    if (!context.mounted) return;
    final undo = result.undo;
    if (undo == null) {
      showAppSnackBar(context, message);
      return;
    }
    showStreamUndo(context, message, () => unawaited(_undo(context, l, undo)));
  } on StreamSlippedException {
    if (!context.mounted) return;
    showErrorSnackBar(context, l.streamSlippedActionError);
  }
}

Future<void> _undo(
  BuildContext context,
  AppLocalizations l,
  StreamSlippedUndo undo,
) async {
  try {
    await undo();
  } on StreamSlippedException {
    if (!context.mounted) return;
    showErrorSnackBar(context, l.streamSlippedActionError);
  }
}
