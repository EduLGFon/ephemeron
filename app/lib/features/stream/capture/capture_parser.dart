// Pure, deterministic, offline capture parser. No Flutter imports.
import 'capture_kind.dart';
import 'capture_priority.dart';
import 'capture_repeat.dart';
import 'capture_span.dart';
import 'capture_vocabulary.dart';

export 'capture_vocabulary.dart' show CaptureLocale;

part 'capture_parser_state.dart';
part 'capture_parser_prefix.dart';
part 'capture_parser_tags.dart';
part 'capture_parser_countdown.dart';
part 'capture_parser_repeat.dart';
part 'capture_parser_date.dart';
part 'capture_parser_date_try.dart';
part 'capture_parser_time.dart';
part 'capture_parser_kind.dart';
part 'capture_parser_title.dart';
part 'capture_parser_utils.dart';

class CaptureDraft {
  const CaptureDraft({
    required this.kind,
    required this.title,
    this.date,
    this.startTime,
    this.endTime,
    this.repeat,
    this.listTag,
    this.priority = CapturePriority.none,
    this.spans = const <CaptureSpan>[],
  });

  final CaptureKind kind;
  final String title;
  final DateTime? date;
  final DateTime? startTime;
  final DateTime? endTime;
  final CaptureRepeat? repeat;
  final String? listTag;
  final CapturePriority priority;
  final List<CaptureSpan> spans;

  @override
  bool operator ==(Object other) =>
      other is CaptureDraft &&
      kind == other.kind &&
      title == other.title &&
      date == other.date &&
      startTime == other.startTime &&
      endTime == other.endTime &&
      repeat == other.repeat &&
      listTag == other.listTag &&
      priority == other.priority &&
      _spansEqual(spans, other.spans);

  @override
  int get hashCode => Object.hash(
    kind,
    title,
    date,
    startTime,
    endTime,
    repeat,
    listTag,
    priority,
    Object.hashAll(spans),
  );

  static bool _spansEqual(List<CaptureSpan> a, List<CaptureSpan> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

class _Tok {
  _Tok(this.text, this.start, this.end);
  final String text;
  final int start;
  final int end;
}

CaptureDraft parseCapture(
  String input, {
  required CaptureLocale locale,
  required DateTime now,
  DateTime Function()? clock,
}) {
  final resolvedNow = clock?.call() ?? now;
  final tokens = _tokenize(input);
  final state = _ParseState(
    input: input,
    locale: locale,
    now: resolvedNow,
    tokens: tokens,
  );

  _handlePrefix(state);
  _handleTagsAndPriorities(state);
  _handleCountdown(state);
  _handleRepeat(state);
  _handleDateTime(state);
  _resolveKind(state);
  _buildDateTimes(state);

  final title = _buildTitle(state);
  state.spans.sort((a, b) => a.start.compareTo(b.start));

  return CaptureDraft(
    kind: state.kind,
    title: title,
    date: state.resolvedDate,
    startTime: state.resolvedStartTime,
    endTime: state.resolvedEndTime,
    repeat: state.repeat,
    listTag: state.listTag,
    priority: state.priority,
    spans: state.spans,
  );
}
