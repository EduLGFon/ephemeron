// Shared dialog helpers to reduce boilerplate.
import 'package:flutter/material.dart';

import 'dirty_guard.dart';

Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  String? message,
  String confirmLabel = 'OK',
  String cancelLabel = 'Cancel',
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: message == null ? null : Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(cancelLabel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return ok ?? false;
}

Future<String?> showPromptDialog(
  BuildContext context, {
  required String title,
  String? hint,
  String? initial,
  String confirmLabel = 'Create',
  String cancelLabel = 'Cancel',
  bool autofocus = true,
}) async {
  final controller = TextEditingController(text: initial);
  final result = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: autofocus,
        decoration: InputDecoration(hintText: hint),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(cancelLabel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result;
}

class _GuardedDialogRoute<T> extends DialogRoute<T> {
  _GuardedDialogRoute({
    required super.context,
    required super.builder,
    super.barrierColor = Colors.black54,
    super.barrierDismissible,
    super.barrierLabel,
    super.useSafeArea = true,
    super.settings,
    super.requestFocus,
    super.anchorPoint,
    super.traversalEdgeBehavior,
    super.fullscreenDialog,
    super.animationStyle,
    super.themes,
    required this.isDirty,
    this.onSave,
    this.onDiscard,
  });

  final bool Function() isDirty;
  final Future<bool> Function()? onSave;
  final void Function()? onDiscard;

  bool _confirmed = false;
  bool _prompting = false;

  @override
  bool didPop(T? result) {
    if (_confirmed || !isDirty()) {
      return super.didPop(result);
    }
    if (_prompting) return false;
    _prompting = true;
    final nav = navigator;
    final ctx = nav?.context;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (ctx == null || !ctx.mounted) {
        _prompting = false;
        return;
      }
      final choice = await showDirtyChoiceDialog(ctx, canSave: onSave != null);
      if (!ctx.mounted) {
        _prompting = false;
        return;
      }
      if (choice == DirtyChoice.discard) {
        onDiscard?.call();
        _confirmed = true;
        nav?.pop(result);
      } else if (choice == DirtyChoice.save && onSave != null) {
        final ok = await onSave!();
        if (ok && ctx.mounted) {
          _confirmed = true;
          nav?.pop(result);
        }
      }
      _prompting = false;
    });
    return false;
  }
}

Future<T?> showGuardedDialog<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  DirtyGuardController? guard,
  bool Function()? isDirty,
  Future<bool> Function()? onSave,
  bool barrierDismissible = true,
  Color? barrierColor,
  String? barrierLabel,
  bool useSafeArea = true,
  bool useRootNavigator = true,
  RouteSettings? routeSettings,
  Offset? anchorPoint,
  TraversalEdgeBehavior? traversalEdgeBehavior,
  bool fullscreenDialog = false,
  bool? requestFocus,
  AnimationStyle? animationStyle,
}) {
  final controller =
      guard ?? DirtyGuardController(isDirty: isDirty, onSave: onSave);
  if (onSave != null && controller.onSave == null) {
    controller.onSave = onSave;
  }

  bool dirtyFn() => controller.dirty;
  Future<bool> saveFn() async {
    final ok = await controller.save();
    if (ok) controller.markClean();
    return ok;
  }

  final discardFn = controller.markClean;

  final themes = InheritedTheme.capture(
    from: context,
    to: Navigator.of(context, rootNavigator: useRootNavigator).context,
  );
  final navigator = Navigator.of(context, rootNavigator: useRootNavigator);

  final route = _GuardedDialogRoute<T>(
    context: context,
    builder: (dialogContext) => AnimatedBuilder(
      animation: controller,
      builder: (_, child) => PopScope(
        canPop: !controller.dirty,
        onPopInvokedWithResult: (didPop, _) async {
          if (didPop) return;
          final choice = await showDirtyChoiceDialog(
            dialogContext,
            canSave: controller.onSave != null,
          );
          if (!dialogContext.mounted) return;
          if (choice == DirtyChoice.discard) {
            controller.markClean();
            Navigator.of(dialogContext).pop();
          } else if (choice == DirtyChoice.save) {
            final ok = await controller.save();
            if (ok && dialogContext.mounted) {
              controller.markClean();
              Navigator.of(dialogContext).pop();
            }
          }
        },
        child: DirtyGuard(
          controller: controller,
          child: builder(dialogContext),
        ),
      ),
    ),
    barrierColor:
        barrierColor ??
        DialogTheme.of(context).barrierColor ??
        Theme.of(context).dialogTheme.barrierColor ??
        Colors.black54,
    barrierDismissible: barrierDismissible,
    barrierLabel: barrierLabel,
    useSafeArea: useSafeArea,
    settings: routeSettings,
    themes: themes,
    anchorPoint: anchorPoint,
    traversalEdgeBehavior:
        traversalEdgeBehavior ?? TraversalEdgeBehavior.closedLoop,
    requestFocus: requestFocus,
    animationStyle: animationStyle,
    fullscreenDialog: fullscreenDialog,
    isDirty: dirtyFn,
    onSave: controller.onSave == null ? null : saveFn,
    onDiscard: discardFn,
  );

  return navigator.push<T>(route);
}
