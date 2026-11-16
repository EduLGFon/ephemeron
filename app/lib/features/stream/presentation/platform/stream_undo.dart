// Undo / action snack bar helpers for the Stream. Delegates to the shared
// helpers; no new snackbar implementation.
import 'package:ephemeron/core/ui/app_feedback.dart';
import 'package:material_ui/material_ui.dart';

void showStreamUndo(BuildContext context, String message, VoidCallback onUndo) {
  try {
    showUndoSnackBar(context, message, onUndo: onUndo);
  } catch (_) {}
}

void showStreamAction(
  BuildContext context,
  String message, {
  required String actionLabel,
  VoidCallback? onAction,
  Duration duration = const Duration(seconds: 4),
}) {
  try {
    showAppSnackBar(
      context,
      message,
      duration: duration,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  } catch (_) {}
}
