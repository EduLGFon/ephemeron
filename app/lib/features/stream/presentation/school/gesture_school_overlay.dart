import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'ghost_finger.dart';
import 'gesture_school_controller.dart';
import 'gesture_school_step.dart';

class GestureSchoolOverlay extends StatefulWidget {
  const GestureSchoolOverlay({
    super.key,
    required this.controller,
    this.steps,
    this.labels,
    this.stepLabels,
    this.skipLabel = '',
    this.nextLabel = '',
    this.skipText,
    this.nextText,
    required this.onStepCompleted,
    required this.onSkip,
    required this.onFinish,
  });

  final GestureSchoolController controller;
  final List<GestureSchoolStep>? steps;
  final Map<String, dynamic>? labels;
  final Map<String, dynamic>? stepLabels;
  final String skipLabel;
  final String nextLabel;
  final String? skipText;
  final String? nextText;
  final void Function(String stepId) onStepCompleted;
  final VoidCallback onSkip;
  final VoidCallback onFinish;

  @override
  State<GestureSchoolOverlay> createState() => _GestureSchoolOverlayState();
}

class _GestureSchoolOverlayState extends State<GestureSchoolOverlay> {
  late List<GestureSchoolStep> _steps;
  int _lastIndex = -1;
  bool _finishedNotified = false;

  String get _skipLabel =>
      widget.skipLabel.isNotEmpty ? widget.skipLabel : (widget.skipText ?? '');
  String get _nextLabel =>
      widget.nextLabel.isNotEmpty ? widget.nextLabel : (widget.nextText ?? '');

  @override
  void initState() {
    super.initState();
    _steps = _resolveSteps();
    _lastIndex = widget.controller.stepIndex;
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
    final map = widget.labels ?? widget.stepLabels ?? const <String, dynamic>{};
    return gestureSchoolStepsFromLabels(map);
  }

  void _onController() {
    final c = widget.controller;
    if (c.stepIndex != _lastIndex &&
        _lastIndex >= 0 &&
        c.stepIndex > _lastIndex) {
      final completedId = _steps[_lastIndex].id;
      widget.onStepCompleted(completedId);
    }
    _lastIndex = c.stepIndex;
    if (c.isFinished && !_finishedNotified) {
      _finishedNotified = true;
      widget.onFinish();
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = widget.controller;
    final idx = c.stepIndex.clamp(0, _steps.length - 1);
    final step = _steps.isEmpty
        ? const GestureSchoolStep(id: '', title: '', body: '', gestureHint: '')
        : _steps[idx];

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
            widget.onSkip();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Semantics(
        liveRegion: true,
        label: 'Step ${idx + 1} of ${_steps.length}',
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  liveRegion: true,
                  child: Text(
                    step.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const SizedBox(height: 8),
                Text(step.body, style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 8),
                GhostFinger(stepId: step.id, color: scheme.primary),
                const SizedBox(height: 8),
                Text(
                  step.gestureHint,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (int i = 0; i < _steps.length; i++)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: Semantics(
                          label: 'Step ${i + 1} of ${_steps.length}',
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: i == idx
                                  ? scheme.primary
                                  : scheme.outlineVariant,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Semantics(
                      button: true,
                      label: _skipLabel,
                      child: TextButton(
                        onPressed: () {
                          c.skip();
                          widget.onSkip();
                        },
                        child: Text(_skipLabel),
                      ),
                    ),
                    Semantics(
                      button: true,
                      label: _nextLabel,
                      child: FilledButton(
                        onPressed: c.completeCurrentStep,
                        child: Text(_nextLabel),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
