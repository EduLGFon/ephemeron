// Eisenhower matrix classification. Pure Dart.

enum EisenhowerQuadrant { doFirst, schedule, delegate, eliminate, unclassified }

/// Board grouping mode: urgency/importance classification or stored priority.
enum MatrixMode { auto, priority }

MatrixMode matrixModeFromName(String? name) => MatrixMode.values.firstWhere(
  (mode) => mode.name == name,
  orElse: () => MatrixMode.auto,
);

/// Stored priority (1-4) as the user-facing P label. 0 (none) has no label.
String? matrixPriorityLabel(int priority) => switch (priority) {
  4 => 'P1',
  3 => 'P2',
  2 => 'P3',
  1 => 'P4',
  _ => null,
};

/// Stable identity of a coloured priority flag. [none] shows no flag.
///
/// This is pure data so both the UI kit and feature code can agree on flag
/// identity without either owning the other. The visual colour/icon mapping
/// lives in `core/design/components/app_wheel.dart`.
enum PriorityFlag { none, p4, p3, p2, p1 }

/// Flags in selector order: no flag, then low (P4) up to highest (P1).
const List<PriorityFlag> priorityFlags = <PriorityFlag>[
  PriorityFlag.none,
  PriorityFlag.p4,
  PriorityFlag.p3,
  PriorityFlag.p2,
  PriorityFlag.p1,
];

/// Maps a stored priority (0 none, 1 low .. 4 high) to its flag.
PriorityFlag priorityFlag(int priority) => switch (priority) {
  4 => PriorityFlag.p1,
  3 => PriorityFlag.p2,
  2 => PriorityFlag.p3,
  1 => PriorityFlag.p4,
  _ => PriorityFlag.none,
};

/// Stored priority value for [flag]; the inverse of [priorityFlag].
int priorityFlagValue(PriorityFlag flag) => switch (flag) {
  PriorityFlag.p1 => 4,
  PriorityFlag.p2 => 3,
  PriorityFlag.p3 => 2,
  PriorityFlag.p4 => 1,
  PriorityFlag.none => 0,
};

/// Visual P number (1 = highest) for a stored priority, 0 for none.
int visualPriority(int storedPriority) =>
    storedPriority == 0 ? 0 : 5 - storedPriority;

/// Stored priority for a visual P number, 0 for none. Inverse of
/// [visualPriority].
int storedPriority(int visual) => visual == 0 ? 0 : 5 - visual;

/// Short P label for [flag]; null for [PriorityFlag.none].
String? priorityFlagLabel(PriorityFlag flag) => switch (flag) {
  PriorityFlag.p1 => 'P1',
  PriorityFlag.p2 => 'P2',
  PriorityFlag.p3 => 'P3',
  PriorityFlag.p4 => 'P4',
  PriorityFlag.none => null,
};

EisenhowerQuadrant classifyTask({
  required int priority, // 0 none, 1 low, 2 medium, 3 high
  DateTime? dueDate,
  required DateTime now,
  int urgentDays = 2,
}) {
  // Urgency is derived from the due date (deadline) only. The planned date
  // (when the user intends to work) does not affect urgency; a task planned
  // soon but due later correctly stays in Schedule when important
  // (priority >= 2), and is Eliminate when not important. See PLAN.md 8.7.
  final important = priority >= 2;
  bool urgent = false;
  if (dueDate != null) {
    final diff = dueDate.difference(now).inDays;
    urgent = diff <= urgentDays; // overdue counts as urgent
  }
  if (priority == 0 && dueDate == null) return EisenhowerQuadrant.unclassified;
  if (important && urgent) return EisenhowerQuadrant.doFirst;
  if (important && !urgent) return EisenhowerQuadrant.schedule;
  if (!important && urgent) return EisenhowerQuadrant.delegate;
  return EisenhowerQuadrant.eliminate;
}
