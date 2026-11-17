// Thin haptics adapter for Stream surfaces. Reuses AppFeedback; never touches
// platform haptics directly and never throws.
import 'package:ephemeron/core/ui/app_feedback.dart';

enum StreamHaptic { tap, selection, success, warning }

abstract final class StreamFeedback {
  static void complete() => AppFeedback.success();

  static void push() => AppFeedback.tap();

  static void levelChange() => AppFeedback.selection();

  static void streak() => AppFeedback.success();

  static void timerEnd() => AppFeedback.success();

  static void undoAvailable() => AppFeedback.selection();

  static void haptic(StreamHaptic type) {
    switch (type) {
      case StreamHaptic.tap:
        AppFeedback.tap();
      case StreamHaptic.selection:
        AppFeedback.selection();
      case StreamHaptic.success:
        AppFeedback.success();
      case StreamHaptic.warning:
        AppFeedback.warning();
    }
  }
}

// Android API levels: AppFeedback is best-effort and swallows unsupported
// platform errors, so no level-specific gating is needed here. Richer
// platform haptic effects are not used.
