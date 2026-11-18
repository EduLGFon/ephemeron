// User-visible strings for the focus screens. English only for now; every
// string lives here so a future locale can override without touching widgets.
import 'package:material_ui/material_ui.dart';

class FocusStrings {
  const FocusStrings(this.locale);

  final Locale locale;

  static FocusStrings of(BuildContext context) =>
      FocusStrings(Localizations.localeOf(context));

  String get title => 'Focus';
  String get statsTooltip => 'Monthly stats';
  String get exportTooltip => 'Export CSV';
  String get csvCopied => 'Focus CSV copied to clipboard';
  String get alarmFocusBody => 'Focus session is over.';
  String get alarmBreakBody => 'Break session is over.';
  String get loadError => 'Could not load focus.';
  String get retry => 'Retry';

  String get modeFocus => 'Focus';
  String get modeBreak => 'Break';
  String get modeStopwatch => 'Stopwatch';
  String get custom => 'Custom';
  String customMinutes(int minutes) => 'Custom: $minutes min';
  String minutes(int minutes) => '$minutes min';
  String duration(int minutes) =>
      minutes < 60 ? '$minutes min' : '${minutes ~/ 60}h ${minutes % 60}m';
  String get minutesLabel => 'Minutes';
  String get useDuration => 'Use duration';
  String get noValue => '—';
  String get linkTask => 'Link task (optional)';
  String get linkHabit => 'Link habit (optional)';
  String get none => 'None';
  String get start => 'Start';
  String startLabel(String phase, int minutes) =>
      'Start $minutes min ${phase == 'break' ? 'break' : 'focus'}';
  String get startStopwatch => 'Start stopwatch';

  String get pausedTitle => 'Paused';
  String pausedLeft(String remaining) => '$remaining left';
  String get resume => 'Resume';
  String get discardPause => 'Discard pause';

  String get todayFocus => 'Focus today';
  String get todayBreak => 'Break today';
  String get weekTitle => 'Focus this week';
  String get recentTitle => 'Recent sessions';
  String get noSessions => 'No sessions yet.';
  String get notesLabel => 'Notes';

  String get pause => 'Pause';
  String get resumeSession => 'Resume';
  String get finish => 'Finish';
  String get stop => 'Stop';
  String get cancel => 'Cancel';
  String get finishDialogTitle => 'Stop session?';
  String stopDialogBody(int elapsed, int remaining, String phase) =>
      'Keep $elapsed min of $phase. The remaining $remaining min will not be counted.';
  String stopDialogBodyNoRemainder(int elapsed, String phase) =>
      'Keep $elapsed min of $phase. No time is left in this session.';
  String stopDialogBodyStopwatch(int elapsed) =>
      'Keep the $elapsed min you tracked. A stopwatch has no remainder to schedule.';
  String get discard => 'Discard session';
  String get sessionDiscarded => 'Session discarded.';
  String get undo => 'Undo';
  String get finishNow => 'Complete';
  String get completeAndStartBreak => 'Complete and start break';
  String get completeAndStartFocus => 'Complete and start focus';
  String get startBreak => 'Start break';
  String get startFocus => 'Start focus';

  String get completeTitleFocus => 'Focus session complete';
  String get completeTitleBreak => 'Break over';
  String completionBody(int minutes, bool isBreak) =>
      'Tracked $minutes min of ${isBreak ? 'break' : 'focus'}. '
      'Would you like to ${isBreak ? 'start a focus session' : 'start a break'}?';
  String get notNow => 'Not now';

  String recovered(int minutes) =>
      'Recovered after app restart. Finishing keeps $minutes min.';
  String elapsedLine(String phase, int minutes) =>
      '$phase · $minutes min elapsed';
  String remainingSemantics(String display) => 'Focus time remaining: $display';
  String elapsedSemantics(String display) => 'Focus elapsed time: $display';
  String get overtime => 'Time is up';
  String overtimeBody(int minutes, bool isBreak) =>
      '${isBreak ? 'Break' : 'Focus'} complete - $minutes min elapsed.';
  String creditHabit(int minutes) => 'Credited $minutes min to habit.';

  String get startBreakLabel => 'Start break';
  String get statsTitle => 'Monthly stats';
  String get pausedSemantics => 'Paused focus session';
}
