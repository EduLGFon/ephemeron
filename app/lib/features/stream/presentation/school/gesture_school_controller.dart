import 'package:flutter/foundation.dart';

import 'gesture_school_step.dart';

/// Small controller for Gesture School progress. Pure Flutter foundation, no
/// providers. Never advances past the last step; calls [onFinish] once.
class GestureSchoolController extends ChangeNotifier {
  GestureSchoolController({
    List<String>? stepIds,
    this.onStepCompleted,
    this.onSkip,
    this.onFinish,
  }) : stepIds = stepIds ?? gestureSchoolStepIds;

  final List<String> stepIds;
  final void Function(String stepId)? onStepCompleted;
  final VoidCallback? onSkip;
  final VoidCallback? onFinish;

  int _stepIndex = 0;
  bool _finished = false;
  bool _finishCalled = false;

  int get stepIndex => _stepIndex;
  int get stepCount => stepIds.length;
  bool get isFinished => _finished;
  bool get finished => _finished;

  String get currentStepId =>
      stepIds.isEmpty ? '' : stepIds[_stepIndex.clamp(0, stepIds.length - 1)];

  void completeCurrentStep() {
    if (_finished || stepIds.isEmpty) return;
    final completed = stepIds[_stepIndex];
    onStepCompleted?.call(completed);
    if (_stepIndex < stepIds.length - 1) {
      _stepIndex++;
    } else {
      _finished = true;
      if (!_finishCalled) {
        _finishCalled = true;
        onFinish?.call();
      }
    }
    notifyListeners();
  }

  void next() => completeCurrentStep();

  void skip() {
    if (_finished) return;
    _finished = true;
    onSkip?.call();
    notifyListeners();
  }

  void restart() {
    _finished = false;
    _finishCalled = false;
    _stepIndex = 0;
    notifyListeners();
  }
}
