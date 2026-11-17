/// Pure data model for one Gesture School step.
///
/// Text is supplied by the caller through a labels map keyed by step id; this
/// file only fixes the ordered set of step ids.
class GestureSchoolStep {
  const GestureSchoolStep({
    required this.id,
    required this.title,
    required this.body,
    required this.gestureHint,
  });

  /// One of: scroll, capture, complete, push, dragSchedule, pinch.
  final String id;
  final String title;
  final String body;
  final String gestureHint;
}

/// Ordered step ids for the six Gesture School steps.
const List<String> gestureSchoolStepIds = <String>[
  'scroll',
  'capture',
  'complete',
  'push',
  'dragSchedule',
  'pinch',
];

/// Builds the six steps from a labels map keyed by step id. Each value may be a
/// map containing 'title', 'body' and 'gestureHint'.
List<GestureSchoolStep> gestureSchoolStepsFromLabels(
  Map<String, dynamic> labels,
) {
  return <GestureSchoolStep>[
    for (final String id in gestureSchoolStepIds)
      GestureSchoolStep(
        id: id,
        title: _read(labels[id], 'title'),
        body: _read(labels[id], 'body'),
        gestureHint: _read(labels[id], 'gestureHint'),
      ),
  ];
}

String _read(dynamic value, String key) {
  if (value is Map<dynamic, dynamic>) {
    final found = value[key];
    if (found is String) return found;
  }
  return '';
}
