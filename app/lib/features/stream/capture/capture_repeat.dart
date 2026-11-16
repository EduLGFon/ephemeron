// Repeat rule value type for capture drafts. Pure Dart.
enum CaptureRepeatFrequency { daily, weekly }

class CaptureRepeat {
  const CaptureRepeat({required this.frequency, this.weekdays = const <int>[]});

  final CaptureRepeatFrequency frequency;
  final List<int> weekdays;

  @override
  bool operator ==(Object other) =>
      other is CaptureRepeat &&
      frequency == other.frequency &&
      _listEquals(weekdays, other.weekdays);

  @override
  int get hashCode => Object.hash(frequency, Object.hashAll(weekdays));

  static bool _listEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
