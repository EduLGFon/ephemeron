// Mutable parse state for the capture parser. Part of capture_parser.dart.
part of 'capture_parser.dart';

class _ParseState {
  _ParseState({
    required this.input,
    required this.locale,
    required this.now,
    required this.tokens,
  }) : used = List<bool>.filled(tokens.length, false);

  final String input;
  final CaptureLocale locale;
  final DateTime now;
  final List<_Tok> tokens;
  final List<bool> used;
  final List<CaptureSpan> spans = <CaptureSpan>[];

  CaptureKind kind = CaptureKind.task;
  bool prefixSet = false;
  CaptureRepeat? repeat;
  String? listTag;
  CapturePriority priority = CapturePriority.none;
  DateTime? dateResolved;
  DateTime? resolvedDate;
  DateTime? resolvedStartTime;
  DateTime? resolvedEndTime;
  int? startHour;
  int? startMinute;
  int? endHour;
  int? endMinute;
  bool countdown = false;
}
