part of 'capture_parser.dart';

void _resolveKind(_ParseState s) {
  if (s.prefixSet) return;
  if (s.repeat != null) {
    s.kind = CaptureKind.habit;
  } else if (s.startHour != null && s.endHour != null) {
    s.kind = CaptureKind.event;
  } else if (s.countdown) {
    s.kind = CaptureKind.countdown;
  }
}

void _buildDateTimes(_ParseState s) {
  DateTime? date;
  DateTime? startTime;
  DateTime? endTime;
  if (s.dateResolved != null) {
    date = DateTime(
      s.dateResolved!.year,
      s.dateResolved!.month,
      s.dateResolved!.day,
    );
  }
  if (s.startHour != null) {
    var base = s.dateResolved ?? DateTime(s.now.year, s.now.month, s.now.day);
    if (s.dateResolved == null) {
      final candidate = DateTime(
        base.year,
        base.month,
        base.day,
        s.startHour!,
        s.startMinute ?? 0,
      );
      if (candidate.isBefore(s.now)) {
        base = base.add(const Duration(days: 1));
      }
    }
    startTime = DateTime(
      base.year,
      base.month,
      base.day,
      s.startHour!,
      s.startMinute ?? 0,
    );
    date ??= DateTime(base.year, base.month, base.day);
    if (s.endHour != null) {
      var endBase = base;
      final eh = s.endHour!;
      final em = s.endMinute ?? 0;
      final endCandidate = DateTime(
        endBase.year,
        endBase.month,
        endBase.day,
        eh,
        em,
      );
      // Overnight ranges (e.g. 22:00-02:00, or 14:00-13:00) roll the end
      // to the following day when it is not strictly after the start.
      if (!endCandidate.isAfter(startTime)) {
        endBase = endBase.add(const Duration(days: 1));
      }
      endTime = DateTime(endBase.year, endBase.month, endBase.day, eh, em);
    }
  }
  s.resolvedDate = date;
  s.resolvedStartTime = startTime;
  s.resolvedEndTime = endTime;
  // keep dateResolved as raw date when present
  if (s.dateResolved == null && date != null) {
    s.dateResolved = date;
  }
}
