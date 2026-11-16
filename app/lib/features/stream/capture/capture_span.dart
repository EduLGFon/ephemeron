// Source span for a recognized capture chip. Pure Dart.
class CaptureSpan {
  const CaptureSpan({
    required this.kind,
    required this.start,
    required this.end,
  });

  final String kind;
  final int start;
  final int end;

  @override
  bool operator ==(Object other) =>
      other is CaptureSpan &&
      kind == other.kind &&
      start == other.start &&
      end == other.end;

  @override
  int get hashCode => Object.hash(kind, start, end);
}
