/// Caller-supplied labels for the four slipped-task triage actions.
class SlippedActionLabels {
  const SlippedActionLabels({
    required this.done,
    required this.tomorrow,
    required this.pickTime,
    required this.drop,
  });

  final String done;
  final String tomorrow;
  final String pickTime;
  final String drop;
}
