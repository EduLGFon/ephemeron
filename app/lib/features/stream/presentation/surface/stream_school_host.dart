// First-run Gesture School host for the Stream surface.
//
// Presentation only: completion is owned by [streamSchoolCompletedProvider].
// The overlay is shown once until the user skips or finishes, then the child
// renders alone for every later launch. The caller supplies the child and may
// observe completion via [onFinished]; no route or navigation is added.
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'package:ephemeron/l10n/src/app_localizations.dart';

import '../../application/stream_school_preferences.dart';
import '../school/gesture_school_controller.dart';
import '../school/gesture_school_overlay.dart';
import '../school/gesture_school_step.dart';

class StreamSchoolHost extends ConsumerStatefulWidget {
  const StreamSchoolHost({super.key, required this.child, this.onFinished});

  final Widget child;
  final VoidCallback? onFinished;

  @override
  ConsumerState<StreamSchoolHost> createState() => _StreamSchoolHostState();
}

class _StreamSchoolHostState extends ConsumerState<StreamSchoolHost> {
  late final GestureSchoolController _controller;
  bool _dismissed = false;
  bool _reported = false;

  @override
  void initState() {
    super.initState();
    _controller = GestureSchoolController(onSkip: _dismiss, onFinish: _dismiss)
      ..addListener(_onStepChanged);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onStepChanged)
      ..dispose();
    super.dispose();
  }

  void _onStepChanged() {
    if (mounted) setState(() {});
  }

  void _dismiss() {
    if (_dismissed) return;
    setState(() => _dismissed = true);
    unawaited(ref.read(streamSchoolCompletedProvider.notifier).markCompleted());
    if (_reported) return;
    _reported = true;
    widget.onFinished?.call();
  }

  @override
  Widget build(BuildContext context) {
    final completed = ref.watch(streamSchoolCompletedProvider).value;
    // Loading or failed reads leave the app usable instead of blocking it.
    if (_dismissed || completed != false) return widget.child;
    final l = AppLocalizations.of(context);
    final isLast = _controller.stepIndex >= _controller.stepCount - 1;
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        const ModalBarrier(dismissible: false, color: Colors.black54),
        SafeArea(
          child: GestureSchoolOverlay(
            controller: _controller,
            steps: gestureSchoolStepsFromLabels(_labels(l)),
            skipLabel: l.onboardingSkip,
            nextLabel: isLast ? l.streamSchoolDone : l.onboardingNext,
            progressLabel: (_, current, total) =>
                l.onboardingStep(current, total),
          ),
        ),
      ],
    );
  }
}

Map<GestureSchoolStepId, GestureSchoolStepText> _labels(AppLocalizations l) {
  return <GestureSchoolStepId, GestureSchoolStepText>{
    GestureSchoolStepId.scroll: GestureSchoolStepText(
      title: l.streamSchoolScrollTitle,
      body: l.streamSchoolScrollBody,
      gestureHint: l.streamSchoolScrollHint,
    ),
    GestureSchoolStepId.capture: GestureSchoolStepText(
      title: l.streamSchoolCaptureTitle,
      body: l.streamSchoolCaptureBody,
      gestureHint: l.streamSchoolCaptureHint,
    ),
    GestureSchoolStepId.complete: GestureSchoolStepText(
      title: l.streamSchoolCompleteTitle,
      body: l.streamSchoolCompleteBody,
      gestureHint: l.streamSchoolCompleteHint,
    ),
    GestureSchoolStepId.push: GestureSchoolStepText(
      title: l.streamSchoolPushTitle,
      body: l.streamSchoolPushBody,
      gestureHint: l.streamSchoolPushHint,
    ),
    GestureSchoolStepId.dragSchedule: GestureSchoolStepText(
      title: l.streamSchoolDragScheduleTitle,
      body: l.streamSchoolDragScheduleBody,
      gestureHint: l.streamSchoolDragScheduleHint,
    ),
    GestureSchoolStepId.pinch: GestureSchoolStepText(
      title: l.streamSchoolPinchTitle,
      body: l.streamSchoolPinchBody,
      gestureHint: l.streamSchoolPinchHint,
    ),
  };
}
