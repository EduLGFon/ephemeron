// Central "dirty" guard for modal sheets, dialogs, and menus.
//
// Menus (popup menus) are explicitly out of scope for this unit; only sheets
// and dialogs are guarded here.
import 'package:flutter/material.dart';

enum DirtyChoice { discard, save, cancel }

class DirtyGuardController extends ValueNotifier<bool> {
  DirtyGuardController({bool dirty = false, this.isDirty, this.onSave})
    : super(dirty);

  /// Optional external source of truth for dirty state.
  final bool Function()? isDirty;

  /// Optional save handler. When null, the prompt omits the Save action.
  Future<bool> Function()? onSave;

  bool get dirty => value || (isDirty?.call() ?? false);

  void markDirty() => value = true;

  void markClean() => value = false;

  Future<bool> save() async {
    if (onSave == null) return true;
    return await onSave!();
  }
}

class DirtyGuard extends InheritedWidget {
  const DirtyGuard({super.key, required this.controller, required super.child});

  final DirtyGuardController controller;

  static DirtyGuardController? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<DirtyGuard>()?.controller;
  }

  static DirtyGuardController of(BuildContext context) {
    final c = maybeOf(context);
    assert(c != null, 'DirtyGuard.of() called without an ancestor DirtyGuard');
    return c!;
  }

  @override
  bool updateShouldNotify(DirtyGuard oldWidget) =>
      oldWidget.controller != controller;
}

Future<DirtyChoice?> showDirtyChoiceDialog(
  BuildContext context, {
  bool canSave = false,
}) {
  return showDialog<DirtyChoice>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: const Text('Unsaved changes'),
      content: const Text(
        'You have unsaved changes. What would you like to do?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(DirtyChoice.discard),
          child: const Text('Discard'),
        ),
        if (canSave)
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(DirtyChoice.save),
            child: const Text('Save'),
          ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(DirtyChoice.cancel),
          child: const Text('Cancel'),
        ),
      ],
    ),
  );
}
