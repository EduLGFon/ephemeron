// Undo snack bar helper for the Stream. Delegates to the shared helper.
import 'package:ephemeron/core/ui/app_feedback.dart';
import 'package:material_ui/material_ui.dart';

void showStreamUndo(BuildContext context, String message, VoidCallback onUndo) {
  showUndoSnackBar(context, message, onUndo: onUndo);
}
