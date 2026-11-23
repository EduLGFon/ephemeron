// English copy for Settings and Onboarding. Each feature owns its strings so
// localization can grow without touching the shared ARB files. Every
// user-visible string lives here with a typed getter.
import 'package:material_ui/material_ui.dart';

class SettingsStrings {
  const SettingsStrings(this.locale);

  final Locale locale;

  static SettingsStrings of(BuildContext context) =>
      SettingsStrings(Localizations.localeOf(context));

  // Shared chrome.
  String get title => 'Settings';
  String get subtitle => 'Local-first by default. Sync is optional.';
  String get back => 'Back';
  String get search => 'Search settings';
  String get closeSearch => 'Close search';
  String get searchHint => 'Search sync, theme, alarms...';
  String get searchEmptyTitle => 'No settings match';
  String get searchEmptyMessage => 'Try "sync", "theme" or "alarms".';
  String get loadErrorTitle => 'Could not load settings';
  String get loadErrorMessage => 'Your data is safe. Try again.';
  String get retry => 'Try again';
  String get saveFailed => 'Could not save this setting.';
  String get appName => 'Ephemeron';

  // Account and sync.
  String get accountSyncTitle => 'Account and sync';
  String get accountSyncDescription =>
      'Sign in, review sync health and control automatic sync.';
  String get accountRowTitle => 'Accounts';
  String get accountRowSubtitle =>
      'Google Calendar and Tasks, Microsoft calendars, and the habits/focus '
      'account.';
  String get lastSyncTitle => 'Last sync';
  String get syncedNow => 'Synced - just now';
  String syncedAt(String date) => 'Synced - $date';
  String get notSyncedYet => 'Not synced yet';
  String get errorNotSyncedYet => 'Error - has not synced yet';
  String errorLastSuccess(String date) => 'Error - last success $date';
  String get syncingNotSyncedYet => 'Syncing - has not synced yet';
  String syncingLastSuccess(String date) => 'Syncing - last success $date';
  String get offlineNotSyncedYet => 'Offline - has not synced yet';
  String offlineLastSuccess(String date) => 'Offline - last success $date';
  String get syncNow => 'Sync now';
  String get syncIssuesTitle => 'Sync issues';
  String get syncIssuesSubtitle =>
      'Review changes and calendar errors that need help.';
  String get reconnectTitle => 'Reconnect accounts';
  String get reconnectSubtitle =>
      'A connected account needs permission again before sync can continue.';
  String get googleSyncIntervalTitle => 'Google auto-sync interval';
  String get googleSyncIntervalHelp =>
      'Sync starts after sign-in. Pull to refresh or tap the sync action to '
      'sync now and restart the countdown.';
  String get backendSyncIntervalTitle => 'Habits and focus auto-sync';
  String get backendSyncIntervalHelp =>
      'Periodic sync of habits and focus sessions. Manual when off.';
  String get calendarsTitle => 'Calendars';
  String get calendarsSubtitle =>
      'Choose visible calendars, defaults and device import.';
  String get listsTitle => 'Task lists';
  String get listsSubtitle => 'Rename, recolor and reorder lists.';
  String get syncComplete => 'Sync complete';
  String get syncOffline =>
      'Offline. Changes are queued and will sync when you reconnect.';
  String get syncAccountAttention =>
      'Sync needs attention. Reconnect your account.';
  String get syncBackendFailed =>
      'Calendar sync complete. Habits/focus sync failed.';
  String get syncStillRunning => 'Sync is still running';
  String get off => 'Off';
  String get manual => 'Manual';
  String minutes(int value) => '$value min';
  String get oneHour => '1 hour';
  String get twoHours => '2 hours';

  // Notifications.
  String get notificationsTitle => 'Notifications';
  String get notificationsDescription =>
      'Reminders, alarms and focus interruptions.';
  String get permissionTitle => 'Notification permission';
  String get permissionGranted =>
      'Allowed. Reminders and alarms can reach you.';
  String get permissionDenied =>
      'Notifications are off. Reminders are saved but may stay silent.';
  String get permissionSystemManaged =>
      'Managed by your system notification settings.';
  String get permissionWeb =>
      'Browser notifications are limited. Background alarms are not '
      'available on the web.';
  String get permissionChecking => 'Checking permission...';
  String get allowNotifications => 'Allow notifications';
  String get appSettings => 'App settings';
  String get notificationsDeniedTitle => 'Notifications are off';
  String get notificationsDeniedBody =>
      'Reminders and alarms are saved, but the system will not show them. '
      'Allow notifications, or open app settings if the prompt was denied '
      'permanently.';
  String get notificationsReason =>
      'Allow notifications so reminders and alarms can ring on time.';
  String get exactAlarmTitle => 'Exact alarms';
  String get exactAlarmGranted =>
      'Granted. Alarms ring at the exact time, including in power saving.';
  String get exactAlarmDenied =>
      'Not granted. Android may delay alarms, especially in power saving.';
  String get exactAlarmAndroidOnly =>
      'Exact alarm access is an Android setting.';
  String get exactAlarmWeb => 'Not available in a browser.';
  String get exactAlarmSystemManaged =>
      'The system schedules alerts; exact-alarm access is not required.';
  String get openSettings => 'Open settings';
  String get dueTomorrowTitle => 'Due tomorrow reminder';
  String get dueTomorrowSubtitle =>
      'Fires 24h before the due time, clamped to 09:00-17:00.';
  String get dndTitle => 'Do Not Disturb during focus';
  String get dndSubtitle => 'Alarms only while a focus session runs.';
  String get dndAndroidOnly => 'Android only.';
  String get dndAccessMessage =>
      'Grant Do Not Disturb access in system settings.';
  String get webNoticeTitle => 'Web limitations';
  String get webNoticeBody =>
      'Ephemeron cannot ring alarms in the background in a browser. '
      'Reminders appear only while this tab is open. Use the Android app for '
      'reliable alarms and home-screen widgets.';
  String get iosNoticeTitle => 'iOS limitations';
  String get iosNoticeBody =>
      'iOS delivers reminders as notifications. A full-screen alarm over the '
      'lock screen is not possible.';

  // Appearance.
  String get appearanceTitle => 'Appearance';
  String get appearanceDescription => 'Theme, color, density and language.';
  String get brightnessTitle => 'Brightness';
  String get brightnessHelp => 'Light, dark, true black or follow the system.';
  String get brightnessLight => 'Light';
  String get brightnessDark => 'Dark';
  String get brightnessAmoled => 'True black';
  String get brightnessSystem => 'System';
  String get accentTitle => 'Accent color';
  String get accentHelp => 'Buttons, links and selected states.';
  String get backgroundTitle => 'Background';
  String get backgroundHelp => 'Page background for light and dark themes.';
  String get customAccentTitle => 'Custom accent';
  String get customBackgroundTitle => 'Custom background';
  String get customHexHelp => 'Enter a value like #RRGGBB and press Enter.';
  String get invalidHex => 'Enter a valid hex like #RRGGBB.';
  String get dynamicColorTitle => 'Dynamic color';
  String get dynamicColorSubtitle =>
      'Follow the Android system accent on Android 12 and newer.';
  String get dynamicColorUnavailable => 'Android only.';
  String get densityTitle => 'Density';
  String get densityHelp => 'Compact fits more rows on screen.';
  String get densityComfortable => 'Comfortable';
  String get densityCompact => 'Compact';
  String get reduceMotionTitle => 'Reduce motion';
  String get reduceMotionSubtitle => 'Fewer transitions and motion effects.';
  String get hapticsTitle => 'Haptics';
  String get hapticsSubtitle => 'Vibration feedback on supported devices.';
  String get powerSavingTitle => 'Power saving';
  String get powerSavingHelp => 'Auto reduces background work on low battery.';
  String get powerAuto => 'Auto';
  String get powerOn => 'On';
  String get powerOff => 'Off';
  String get languageTitle => 'Language';
  String get languageHelp => 'System follows the device language.';
  String get languageSystem => 'System';
  String get languageEnglish => 'English';
  String get languagePortuguese => 'Portuguese';

  // Time.
  String get timeTitle => 'Time';
  String get timeDescription => 'Calendar week start and clock format.';
  String get weekStartTitle => 'Week starts on';
  String get weekStartHelp => 'Used by calendar weeks and home widgets.';
  String get weekdayMonday => 'Monday';
  String get weekdayTuesday => 'Tuesday';
  String get weekdayWednesday => 'Wednesday';
  String get weekdayThursday => 'Thursday';
  String get weekdayFriday => 'Friday';
  String get weekdaySaturday => 'Saturday';
  String get weekdaySunday => 'Sunday';
  String get clockTitle => '24-hour clock';
  String get clockSubtitle => 'Show times like 14:30 instead of 2:30 PM.';
  String get clock12Title => '12-hour clock';
  String get clock12Subtitle => 'Show times like 2:30 PM instead of 14:30.';

  // Shortcuts.
  String get shortcutsTitle => 'Keyboard shortcuts';
  String get shortcutsDescription => 'Available in the desktop and web app.';
  String get shortcutsUnavailable =>
      'Keyboard shortcuts are available on desktop and web.';
  String get shortcutNew => 'New item';
  String get shortcutSearch => 'Search';
  String get shortcutCommandSearch => 'Search from anywhere';
  String get shortcutEscape => 'Close the current sheet or dialog';
  String get shortcutTabs => 'Switch primary destination';
  String get shortcutToday => 'Go to Today';
  String get shortcutArrows => 'Previous or next calendar period';

  // Stream.
  String get streamTitle => 'Stream';
  String get streamDescription => 'Optional timeline view. Off by default.';
  String get streamToggleTitle => 'Show Stream';
  String get streamToggleSubtitle =>
      'Adds Stream to More and the sidebar. Direct Stream links open Today '
      'while this is off.';

  // Data.
  String get dataTitle => 'Data';
  String get dataDescription => 'Backups and home-screen widgets.';
  String get backupTitle => 'Backup and restore';
  String get backupSubtitle =>
      'Export a local JSON backup, or restore one from this device.';
  String get homeWidgetsTitle => 'Home-screen widgets';
  String get homeWidgetsSubtitle =>
      'Pin and configure calendar and task widgets.';

  // Security.
  String get securityTitle => 'Security';
  String get securityDescription => 'Protect the app when it opens.';
  String get biometricTitle => 'Biometric app lock';
  String get biometricSupported =>
      'Require unlock on startup. Unsupported devices skip the lock.';
  String get biometricUnsupported => 'Not available on this device.';

  // Navigation.
  String get navigationTitle => 'Navigation';
  String get navigationDescription => 'Order of all destinations.';
  String get reorderTitle => 'Customize navigation order';
  String navigationOrder(String order) => 'Current order: $order';
  String get reorderSheetTitle => 'Navigation order';
  String get reorderSheetDescription =>
      'Drag to reorder. The first five appear in the navigation bar.';
  String get reset => 'Reset';
  String get save => 'Save';
  String get dragHandle => 'Drag to reorder';
  String get close => 'Close';

  // About.
  String get aboutTitle => 'About';
  String get aboutDescription => 'Privacy and app information.';
  String get aboutPrivacyTitle => 'Local-first privacy';
  String get aboutPrivacyBody =>
      'Calendar and task data goes directly from this device to the provider '
      'you connect. No central server sees it. Habits and focus sync only '
      'when you create an account.';
  String get aboutLicensesTitle => 'Open-source licenses';
  String get aboutLicensesSubtitle => 'Libraries used by Ephemeron.';
  String get aboutVersion => 'Ephemeron for Android, Linux, Web and desktop.';

  // Onboarding.
  String get onboardingBrand => 'Ephemeron';
  String get onboardingTagline => 'Your time, local-first.';
  String get onboardingSkip => 'Skip';
  String get onboardingNext => 'Next';
  String get onboardingDone => 'Get started';
  String onboardingStep(int current, int total) => 'Step $current of $total';
  String onboardingProgress(int current, int total) =>
      'Page $current of $total';
  String get onboardingP1Title => 'Everything in one calm place';
  String get onboardingP1Body =>
      'Calendar, tasks, habits, focus, countdowns and notes. Every feature '
      'works offline with no account. Your data is stored on this device.';
  String get onboardingP2Title => 'Alarms that actually ring';
  String get onboardingP2Body =>
      'Permission is asked only when you create your first reminder. '
      'Ephemeron never prompts for notifications during onboarding. You can '
      'test an alarm any time in Settings.';
  String get onboardingP3Title => 'Sync only if you want it';
  String get onboardingP3Body =>
      'Connect Google for calendar and tasks, or an email account for habits '
      'and focus. Google data never touches our server. Staying local is a '
      'complete experience.';
  String get onboardingGoogle => 'Connect Google (optional)';
  String get onboardingLocalNote =>
      'You can connect accounts later in Settings.';
  String get onboardingNotificationsNote =>
      'No notification permission is requested now.';
  String get onboardingSaveFailed => 'Could not finish onboarding. Try again.';
}
