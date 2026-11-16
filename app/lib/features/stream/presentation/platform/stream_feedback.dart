// Thin haptics adapter for Stream surfaces. Reuses AppFeedback; never touches
// HapticFeedback directly and never throws.
import 'package:ephemeron/core/ui/app_feedback.dart';

enum StreamHaptic { tap, selection, success, warning }

abstract final class StreamFeedback {
  // Meaningful actions map to the closest AppFeedback primitive.
  static void complete() {
    try {
      AppFeedback.success();
    } catch (_) {}
  }

  static void push() {
    try {
      AppFeedback.tap();
    } catch (_) {}
  }

  static void levelChange() {
    try {
      AppFeedback.selection();
    } catch (_) {}
  }

  static void streak() {
    try {
      AppFeedback.success();
    } catch (_) {}
  }

  static void timerEnd() {
    try {
      AppFeedback.warning();
    } catch (_) {}
  }

  static void undoAvailable() {
    try {
      AppFeedback.selection();
    } catch (_) {}
  }

  static void haptic(StreamHaptic type) {
    try {
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
    } catch (_) {}
  }
}

// Android API levels: AppFeedback._run is best-effort and swallows unsupported
// platform errors, so no level-specific gating is needed here. HapticFeedback
// support is reported by the OS; Android 12+ richer effects are not used.
