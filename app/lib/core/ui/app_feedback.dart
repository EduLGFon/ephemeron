// Haptic feedback and snack bar helpers. Screens call these instead of
// touching HapticFeedback or ScaffoldMessenger directly so the haptics
// preference and snack bar styling stay consistent, and no call can throw when
// a messenger or haptics support is missing.
import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

abstract final class AppFeedback {
  /// Defaults to enabled; main.dart configures it from user settings once the
  /// repository is available.
  static bool hapticsEnabled = true;

  static void configure({required bool hapticsEnabled}) {
    AppFeedback.hapticsEnabled = hapticsEnabled;
  }

  static void tap() => _run(HapticFeedback.lightImpact);

  static void success() => _run(HapticFeedback.mediumImpact);

  static void warning() => _run(HapticFeedback.heavyImpact);

  static void error() => _run(HapticFeedback.heavyImpact);

  static void selection() => _run(HapticFeedback.selectionClick);

  static void _run(Future<void> Function() action) {
    if (!hapticsEnabled) return;
    unawaited(() async {
      try {
        await action();
      } catch (_) {
        // Haptics are best effort and unsupported on some platforms.
      }
    }());
  }
}

/// Shows a floating, theme-styled snack bar. No-op without a messenger.
void showAppSnackBar(
  BuildContext context,
  String message, {
  IconData? icon,
  Duration duration = const Duration(seconds: 4),
  String? actionLabel,
  VoidCallback? onAction,
  bool showCloseIcon = false,
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;

  final theme = Theme.of(context);
  final iconColor =
      theme.snackBarTheme.contentTextStyle?.color ??
      theme.colorScheme.onInverseSurface;

  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20, color: iconColor),
              const SizedBox(width: 10),
            ],
            Flexible(child: Text(message)),
          ],
        ),
        duration: duration,
        showCloseIcon: showCloseIcon,
        action: actionLabel != null && onAction != null
            ? SnackBarAction(label: actionLabel, onPressed: onAction)
            : null,
      ),
    );
}

/// 6s undo window, matching the repository's destructive-update rule.
void showUndoSnackBar(
  BuildContext context,
  String message, {
  required VoidCallback onUndo,
  Duration duration = const Duration(seconds: 6),
}) {
  showAppSnackBar(
    context,
    message,
    duration: duration,
    actionLabel: 'Undo',
    onAction: onUndo,
  );
}

void showErrorSnackBar(
  BuildContext context,
  String message, {
  Duration duration = const Duration(seconds: 6),
  String? actionLabel,
  VoidCallback? onAction,
}) {
  showAppSnackBar(
    context,
    message,
    icon: Icons.error_outline,
    duration: duration,
    actionLabel: actionLabel,
    onAction: onAction,
    showCloseIcon: true,
  );
}
