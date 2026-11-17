// Pure value objects for the Stream Peek inline editor.
// Times are local epoch milliseconds (DateTime.millisecondsSinceEpoch).
// No Flutter import.

/// Priority levels for a mark, ordered none < low < medium < high.
enum PeekPriority { none, low, medium, high }

/// Immutable snapshot of a mark as shown in Peek.
class PeekData {
  const PeekData({
    required this.id,
    required this.title,
    required this.startMs,
    this.endMs,
    this.listId,
    this.listName,
    this.priority = PeekPriority.none,
    this.notes,
  });

  final String id;
  final String title;
  // Local epoch milliseconds (DateTime.millisecondsSinceEpoch).
  final int startMs;
  final int? endMs;
  final String? listId;
  final String? listName;
  final PeekPriority priority;
  final String? notes;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PeekData &&
        other.id == id &&
        other.title == title &&
        other.startMs == startMs &&
        other.endMs == endMs &&
        other.listId == listId &&
        other.listName == listName &&
        other.priority == priority &&
        other.notes == notes;
  }

  @override
  int get hashCode =>
      Object.hash(id, title, startMs, endMs, listId, listName, priority, notes);

  PeekData copyWith({
    String? id,
    String? title,
    int? startMs,
    int? endMs,
    bool clearEndMs = false,
    String? listId,
    bool clearListId = false,
    String? listName,
    bool clearListName = false,
    PeekPriority? priority,
    String? notes,
    bool clearNotes = false,
  }) {
    return PeekData(
      id: id ?? this.id,
      title: title ?? this.title,
      startMs: startMs ?? this.startMs,
      endMs: clearEndMs ? null : (endMs ?? this.endMs),
      listId: clearListId ? null : (listId ?? this.listId),
      listName: clearListName ? null : (listName ?? this.listName),
      priority: priority ?? this.priority,
      notes: clearNotes ? null : (notes ?? this.notes),
    );
  }
}

/// Edited result produced by the Peek editor.
class PeekEdit {
  const PeekEdit({
    required this.title,
    required this.startMs,
    this.endMs,
    this.listId,
    this.priority = PeekPriority.none,
    this.notes,
  });

  final String title;
  final int startMs;
  final int? endMs;
  final String? listId;
  final PeekPriority priority;
  final String? notes;

  PeekEdit copyWith({
    String? title,
    int? startMs,
    int? endMs,
    bool clearEndMs = false,
    String? listId,
    bool clearListId = false,
    PeekPriority? priority,
    String? notes,
    bool clearNotes = false,
  }) {
    return PeekEdit(
      title: title ?? this.title,
      startMs: startMs ?? this.startMs,
      endMs: clearEndMs ? null : (endMs ?? this.endMs),
      listId: clearListId ? null : (listId ?? this.listId),
      priority: priority ?? this.priority,
      notes: clearNotes ? null : (notes ?? this.notes),
    );
  }
}

/// A list option for the Peek list selector.
class PeekListOption {
  const PeekListOption({required this.id, required this.name});
  final String id;
  final String name;
}
