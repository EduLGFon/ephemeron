enum GestureSchoolStepId {
  scroll,
  capture,
  complete,
  push,
  dragSchedule,
  pinch,
}

class GestureSchoolStepText {
  const GestureSchoolStepText({
    required this.title,
    required this.body,
    required this.gestureHint,
  });

  final String title;
  final String body;
  final String gestureHint;
}

class GestureSchoolStep {
  const GestureSchoolStep({required this.id, required this.text});

  final GestureSchoolStepId id;
  final GestureSchoolStepText text;

  String get title => text.title;
  String get body => text.body;
  String get gestureHint => text.gestureHint;
}

/// Ordered step ids for the six Gesture School steps.
const List<GestureSchoolStepId> gestureSchoolStepIds = <GestureSchoolStepId>[
  GestureSchoolStepId.scroll,
  GestureSchoolStepId.capture,
  GestureSchoolStepId.complete,
  GestureSchoolStepId.push,
  GestureSchoolStepId.dragSchedule,
  GestureSchoolStepId.pinch,
];

/// Builds the six steps from a typed labels map keyed by step id. Missing
/// entries fall back to the step id as a visible title.
List<GestureSchoolStep> gestureSchoolStepsFromLabels(
  Map<GestureSchoolStepId, GestureSchoolStepText> labels,
) {
  return <GestureSchoolStep>[
    for (final GestureSchoolStepId id in gestureSchoolStepIds)
      GestureSchoolStep(
        id: id,
        text:
            labels[id] ??
            GestureSchoolStepText(title: id.name, body: '', gestureHint: ''),
      ),
  ];
}
