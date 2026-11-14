// Shared bottom-sheet helper: every modal sheet auto-sizes to content
// up to 92% of the screen height and stays dismissible via drag,
// tap-outside, or Escape (see EscapeToClose).
//
// Sheets are centrally guarded by DirtyGuard: when the sheet content reports
// dirty state via DirtyGuard.of(context), dismissing prompts Discard/Save/Cancel.
import 'package:material_ui/material_ui.dart';

import '../theme/theme_tokens.dart';
import 'dirty_guard.dart';

class _GuardedModalBottomSheetRoute<T> extends ModalBottomSheetRoute<T> {
  _GuardedModalBottomSheetRoute({
    required super.builder,
    required this.isDirty,
    this.onSave,
    this.onDiscard,
    super.capturedThemes,
    super.barrierLabel,
    super.barrierOnTapHint,
    super.backgroundColor,
    super.elevation,
    super.shape,
    super.clipBehavior,
    super.constraints,
    super.modalBarrierColor,
    super.isDismissible = true,
    super.enableDrag = true,
    super.showDragHandle,
    required super.isScrollControlled,
    super.scrollControlDisabledMaxHeightRatio =
        _kDefaultScrollControlDisabledMaxHeightRatio,
    super.settings,
    super.requestFocus,
    super.transitionAnimationController,
    super.anchorPoint,
    super.useSafeArea = false,
    super.sheetAnimationStyle,
  });

  final bool Function() isDirty;
  final Future<bool> Function()? onSave;
  final void Function()? onDiscard;

  // Shared escape state for BOTH didPop and PopScope paths so only one prompt
  // can be shown at a time and a confirmed discard/save force-pops cleanly.
  bool _prompting = false;
  bool _confirmed = false;

  BuildContext? promptContext;

  Future<void> _attemptClose(T? result) async {
    if (_confirmed || !isDirty()) return;
    if (_prompting) return;
    _prompting = true;
    final ctx = promptContext;
    final nav = navigator;
    if (ctx == null || !ctx.mounted || nav == null) {
      _prompting = false;
      return;
    }
    // A prompt dismissed via system-back returns null -> treated as Cancel.
    final choice = await showDirtyChoiceDialog(ctx, canSave: onSave != null);
    if (!ctx.mounted) {
      _prompting = false;
      return;
    }
    if (choice == DirtyChoice.discard) {
      onDiscard?.call();
      _confirmed = true;
      nav.pop(result);
    } else if (choice == DirtyChoice.save && onSave != null) {
      final ok = await onSave!();
      if (ok && ctx.mounted) {
        _confirmed = true;
        nav.pop(result);
      }
    }
    // cancel or null: do nothing, sheet stays open.
    _prompting = false;
  }

  @override
  bool didPop(T? result) {
    if (_confirmed || !isDirty()) {
      return super.didPop(result);
    }
    if (!_prompting) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _attemptClose(result),
      );
    }
    return false;
  }
}

Future<T?> showGuardedAppSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  DirtyGuardController? guard,
  bool Function()? isDirty,
  Future<bool> Function()? onSave,
  Color? backgroundColor,
  String? barrierLabel,
  double? elevation,
  ShapeBorder? shape,
  Clip? clipBehavior,
  BoxConstraints? constraints,
  Color? barrierColor,
  bool isScrollControlled = true,
  double scrollControlDisabledMaxHeightRatio =
      _kDefaultScrollControlDisabledMaxHeightRatio,
  bool useRootNavigator = false,
  bool isDismissible = true,
  bool enableDrag = true,
  bool showDragHandle = true,
  bool useSafeArea = true,
  RouteSettings? routeSettings,
  AnimationController? transitionAnimationController,
  Offset? anchorPoint,
  AnimationStyle? sheetAnimationStyle,
  bool? requestFocus,
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

  final NavigatorState navigator = Navigator.of(
    context,
    rootNavigator: useRootNavigator,
  );
  final MaterialLocalizations localizations = MaterialLocalizations.of(context);
  final capturedThemes = InheritedTheme.capture(
    from: context,
    to: navigator.context,
  );

  late final _GuardedModalBottomSheetRoute<T> route;
  route = _GuardedModalBottomSheetRoute<T>(
    builder: (sheetContext) {
      route.promptContext = sheetContext;
      return AnimatedBuilder(
        animation: controller,
        builder: (_, child) => PopScope(
          canPop: !controller.dirty,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            if (route._prompting || route._confirmed) return;
            // ignore: discarded_futures
            route._attemptClose(null);
          },
          child: child!,
        ),
        child: DirtyGuard(
          controller: controller,
          child: SafeArea(
            top: false,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(sheetContext).size.height * 0.92,
              ),
              child: builder(sheetContext),
            ),
          ),
        ),
      );
    },
    capturedThemes: capturedThemes,
    isScrollControlled: isScrollControlled,
    scrollControlDisabledMaxHeightRatio: scrollControlDisabledMaxHeightRatio,
    barrierLabel: barrierLabel ?? localizations.scrimLabel,
    barrierOnTapHint: localizations.scrimOnTapHint(
      localizations.bottomSheetLabel,
    ),
    backgroundColor: backgroundColor,
    elevation: elevation,
    shape:
        shape ??
        const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
        ),
    clipBehavior: clipBehavior ?? Clip.antiAlias,
    constraints: constraints ?? const BoxConstraints(maxWidth: 640),
    isDismissible: isDismissible,
    modalBarrierColor:
        barrierColor ?? Theme.of(context).bottomSheetTheme.modalBarrierColor,
    enableDrag: enableDrag,
    showDragHandle: showDragHandle,
    settings: routeSettings,
    transitionAnimationController: transitionAnimationController,
    anchorPoint: anchorPoint,
    useSafeArea: useSafeArea,
    sheetAnimationStyle: sheetAnimationStyle,
    requestFocus: requestFocus,
    isDirty: dirtyFn,
    onSave: controller.onSave == null ? null : saveFn,
    onDiscard: discardFn,
  );

  return navigator.push<T>(route);
}

Future<T?> showAppSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  DirtyGuardController? guard,
  bool Function()? isDirty,
  Future<bool> Function()? onSave,
}) {
  return showGuardedAppSheet<T>(
    context,
    builder: builder,
    guard: guard,
    isDirty: isDirty,
    onSave: onSave,
  );
}

const double _kDefaultScrollControlDisabledMaxHeightRatio = 9.0 / 16.0;
