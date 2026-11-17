// Capture draft to preview chip labels. Localized prefixes and locale-aware
// date/time formatting; no repository access.
import 'package:intl/intl.dart';
import 'package:ephemeron/l10n/src/app_localizations.dart';

import '../../capture/capture_kind.dart';
import '../../capture/capture_parser.dart' show CaptureDraft;
import '../../capture/capture_priority.dart';
import '../../capture/capture_repeat.dart';
import '../capture/capture_preview_chips.dart';

List<CapturePreviewChip> buildStreamCaptureChips(
  CaptureDraft draft, {
  required AppLocalizations l,
  required String localeName,
}) {
  final chips = <CapturePreviewChip>[
    CapturePreviewChip(
      kind: CaptureChipKind.kind,
      label: _kindLabel(draft.kind, l),
    ),
  ];
  final date = draft.date;
  if (date != null) {
    chips.add(
      CapturePreviewChip(
        kind: CaptureChipKind.date,
        label:
            '${l.streamChipDate}: ${DateFormat.MMMd(localeName).format(date)}',
      ),
    );
  }
  final startTime = draft.startTime;
  if (startTime != null) {
    chips.add(
      CapturePreviewChip(
        kind: CaptureChipKind.time,
        label:
            '${l.streamChipTime}: '
            '${DateFormat.Hm(localeName).format(startTime)}',
      ),
    );
  }
  final repeat = draft.repeat;
  if (repeat != null) {
    chips.add(
      CapturePreviewChip(
        kind: CaptureChipKind.repeat,
        label: '${l.streamChipRepeat}: ${_repeatLabel(repeat, l)}',
      ),
    );
  }
  final listTag = draft.listTag;
  if (listTag != null) {
    chips.add(
      CapturePreviewChip(
        kind: CaptureChipKind.list,
        label: '${l.streamChipList}: $listTag',
      ),
    );
  }
  if (draft.priority != CapturePriority.none) {
    chips.add(
      CapturePreviewChip(
        kind: CaptureChipKind.priority,
        label: '${l.streamChipPriority}: ${_priorityLabel(draft.priority, l)}',
      ),
    );
  }
  return chips;
}

String _kindLabel(CaptureKind kind, AppLocalizations l) => switch (kind) {
  CaptureKind.task => l.streamChipKindTask,
  CaptureKind.event => l.streamChipKindEvent,
  CaptureKind.habit => l.streamChipKindHabit,
  CaptureKind.countdown => l.streamChipKindCountdown,
};

String _repeatLabel(CaptureRepeat repeat, AppLocalizations l) {
  if (repeat.frequency == CaptureRepeatFrequency.daily) {
    return l.streamCaptureRepeatDaily;
  }
  if (repeat.weekdays.isEmpty) return l.streamCaptureRepeatWeekly;
  final sorted = repeat.weekdays.toSet().toList()..sort();
  final days = sorted
      .map((weekday) => _weekdayLabel(weekday, l))
      .where((label) => label.isNotEmpty)
      .join(', ');
  if (days.isEmpty) return l.streamCaptureRepeatWeekly;
  return l.streamCaptureWeeklyOn(days);
}

String _weekdayLabel(int weekday, AppLocalizations l) => switch (weekday) {
  1 => l.streamWeekdayMon,
  2 => l.streamWeekdayTue,
  3 => l.streamWeekdayWed,
  4 => l.streamWeekdayThu,
  5 => l.streamWeekdayFri,
  6 => l.streamWeekdaySat,
  7 => l.streamWeekdaySun,
  _ => '',
};

String _priorityLabel(CapturePriority priority, AppLocalizations l) =>
    switch (priority) {
      CapturePriority.none => '',
      CapturePriority.low => l.streamCapturePriorityLow,
      CapturePriority.medium => l.streamCapturePriorityMedium,
      CapturePriority.high => l.streamCapturePriorityHigh,
    };
