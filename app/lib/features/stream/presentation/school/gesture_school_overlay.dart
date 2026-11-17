import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'ghost_finger.dart';
import 'gesture_school_controller.dart';
import 'gesture_school_step.dart';
import 'school_actions.dart';
import 'school_progress_dots.dart';

class GestureSchoolOverlay extends StatefulWidget {
  const GestureSchoolOverlay({
    super.key,
    required this.controller,
    this.steps,
    this.labels = const <GestureSchoolStepId, GestureSchoolStepText>{},
    required this.skipLabel,
    required this.nextLabel,
    this.progressLabel,
  }) : assert(skipLabel != ''),
       assert(nextLabel != '');

  final GestureSchoolController controller;
  final List<GestureSchoolStep>? steps;
  final Map<GestureSchoolStepId, GestureSchoolStepText> labels;
  final String skipLabel;
  final String nextLabel;
  final String Function(String stepId, int current, int total)? progressLabel;

  @override
  State<GestureSchoolOverlay> createState() => _GestureSchoolOverlayState();
}

class _GestureSchoolOverlayState extends State<GestureSchoolOverlay> {
  late List<GestureSchoolStep> _steps;

  @override
  void initState() {
    super.initState();
    _steps = _resolveSteps();
    widget.controller.addListener(_onController);
  }

  @override
  void didUpdateWidget(covariant GestureSchoolOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.steps != widget.steps || oldWidget.labels != widget.labels) {
      _steps = _resolveSteps();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onController);
    super.dispose();
  }

  List<GestureSchoolStep> _resolveSteps() {
    if (widget.steps != null) return widget.steps!;
    return gestureSchoolStepsFromLabels(widget.labels);
  }

  void _onController() {
    if (mounted) setState(() {});
  }

  String _progressLabel(String stepId, int current, int total) {
    final cb = widget.progressLabel;
    if (cb != null) return cb(stepId, current, total);
    return '$current of $total';
  }

  @override
  Widget build(BuildContext context) {
    if (_steps.isEmpty) return const SizedBox.shrink();
    final c = widget.controller;
    final idx = c.stepIndex.clamp(0, _steps.length - 1);
    final step = _steps[idx];

    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.arrowRight) {
            c.completeCurrentStep();
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.escape) {
            c.skip();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(step: step),
              const SizedBox(height: 8),
              GhostFinger(stepId: step.id),
              const SizedBox(height: 8),
              Text(
                step.gestureHint,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              SchoolProgressDots(
                count: _steps.length,
                currentIndex: idx,
                currentStepIdName: step.id.name,
                progressLabel: _progressLabel,
              ),
              const SizedBox(height: 12),
              SchoolActions(
                skipLabel: widget.skipLabel,
                nextLabel: widget.nextLabel,
                onSkip: c.skip,
                onNext: c.completeCurrentStep,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.step});

  final GestureSchoolStep step;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(step.title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(step.body, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
