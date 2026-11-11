// Pure mapping from an alarm row's source type to the app section that owns
// the underlying item. The ring screen uses this so "Open item" lands on the
// right tab instead of dismissing the alarm and leaving the user on Calendar.

/// Destination route for [sourceType]. Reminder variants follow their parent
/// section; null or unknown types fall back to the calendar tab.
String alarmSourceRoute(String? sourceType) {
  switch (sourceType) {
    case 'event':
    case 'event_reminder':
      return '/tab0';
    case 'task':
    case 'task_reminder':
    case 'task_due_tomorrow':
      return '/tab1';
    case 'habit':
    case 'habit_reminder':
      return '/tab3';
    case 'countdown':
    case 'countdown_reminder':
      return '/tab4';
    case 'focus':
      return '/tab5';
    case 'test':
      return '/alarm-settings';
    default:
      return '/tab0';
  }
}

/// Short chip label for [sourceType], or null when the alarm has no source
/// row to label (for example a pending fallback ring).
String? alarmSourceLabel(String? sourceType) {
  switch (sourceType) {
    case 'event':
    case 'event_reminder':
      return 'Event';
    case 'task':
    case 'task_reminder':
    case 'task_due_tomorrow':
      return 'Task';
    case 'habit':
    case 'habit_reminder':
      return 'Habit';
    case 'countdown':
    case 'countdown_reminder':
      return 'Countdown';
    case 'focus':
      return 'Focus';
    case 'test':
      return 'Test';
    default:
      return null;
  }
}
