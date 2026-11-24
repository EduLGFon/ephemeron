// GENERATED CODE - DO NOT MODIFY BY HAND.
// Run: dart run tools/gen_test_runner.dart
//
// Shard 0 of 4. Each shard owns a contiguous
// range of cases and pays one kernel compile.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'cases/account_email_case.dart' as account_email;
import 'cases/adaptive_shell_case.dart' as adaptive_shell;
import 'cases/alarm_migration_v4v5_case.dart' as alarm_migration_v4v5;
import 'cases/alarm_notification_actions_case.dart'
    as alarm_notification_actions;
import 'cases/alarm_overdue_case.dart' as alarm_overdue;
import 'cases/alarm_repository_case.dart' as alarm_repository;
import 'cases/alarm_title_case.dart' as alarm_title;
import 'cases/alarm_window_case.dart' as alarm_window;
import 'cases/app_lock_case.dart' as app_lock;
import 'cases/auth_screen_case.dart' as auth_screen;
import 'cases/backend_auth_case.dart' as backend_auth;
import 'cases/backend_sync_case.dart' as backend_sync;
import 'cases/backup_case.dart' as backup;
import 'cases/calendar_atomic_load_case.dart' as calendar_atomic_load;
import 'cases/calendar_cache_coordinator_case.dart'
    as calendar_cache_coordinator;
import 'cases/calendar_color_case.dart' as calendar_color;
import 'cases/calendar_header_case.dart' as calendar_header;
import 'cases/calendar_list_pagination_case.dart' as calendar_list_pagination;
import 'cases/calendar_perf_case.dart' as calendar_perf;
import 'cases/calendar_screen_ui_case.dart' as calendar_screen_ui;
import 'cases/calendar_swipe_case.dart' as calendar_swipe;
import 'cases/calendar_ux_source_case.dart' as calendar_ux_source;
import 'cases/calendar_week_nav_case.dart' as calendar_week_nav;
import 'cases/countdown_link_case.dart' as countdown_link;
import 'cases/countdowns_screen_case.dart' as countdowns_screen;
import 'cases/db_case.dart' as db;
import 'cases/design_components_case.dart' as design_components;
import 'cases/design_data_components_case.dart' as design_data_components;
import 'cases/design_foundation_case.dart' as design_foundation;
import 'cases/device_calendar_import_case.dart' as device_calendar_import;
import 'cases/dirty_guard_case.dart' as dirty_guard;
import 'cases/event_editor_time_case.dart' as event_editor_time;
import 'cases/event_rsvp_case.dart' as event_rsvp;
import 'cases/event_scope_case.dart' as event_scope;
import 'cases/event_source_case.dart' as event_source;
import 'cases/focus_breaks_metrics_case.dart' as focus_breaks_metrics;
import 'cases/focus_overtime_case.dart' as focus_overtime;
import 'cases/focus_screen_case.dart' as focus_screen;
import 'cases/focus_stopwatch_case.dart' as focus_stopwatch;
import 'cases/google_restore_case.dart' as google_restore;
import 'cases/google_sync_resilience_case.dart' as google_sync_resilience;
import 'cases/habit_calendar_repository_case.dart' as habit_calendar_repository;
import 'cases/habit_delete_case.dart' as habit_delete;
import 'cases/habit_focus_case.dart' as habit_focus;
import 'cases/habit_percent_case.dart' as habit_percent;
import 'cases/habit_schedule_case.dart' as habit_schedule;
import 'cases/habit_stats_case.dart' as habit_stats;
import 'cases/habit_stats_screen_case.dart' as habit_stats_screen;
import 'cases/habit_streak_case.dart' as habit_streak;
import 'cases/habits_screen_case.dart' as habits_screen;
import 'cases/habits_timer_case.dart' as habits_timer;
import 'cases/headless_widget_push_case.dart' as headless_widget_push;
import 'cases/home_widget_binder_case.dart' as home_widget_binder;
import 'cases/home_widget_callback_case.dart' as home_widget_callback;
import 'cases/home_widget_case.dart' as home_widget;
import 'cases/l10n_case.dart' as l10n;
import 'cases/markdown_editing_controller_case.dart'
    as markdown_editing_controller;
import 'cases/matrix_case.dart' as matrix;
import 'cases/matrix_layout_case.dart' as matrix_layout;
import 'cases/matrix_planned_case.dart' as matrix_planned;
import 'cases/microsoft_auth_case.dart' as microsoft_auth;
import 'cases/microsoft_graph_case.dart' as microsoft_graph;

const _allCases = <String>{
  'account_email_case.dart',
  'adaptive_shell_case.dart',
  'alarm_migration_v4v5_case.dart',
  'alarm_notification_actions_case.dart',
  'alarm_overdue_case.dart',
  'alarm_repository_case.dart',
  'alarm_title_case.dart',
  'alarm_window_case.dart',
  'app_lock_case.dart',
  'auth_screen_case.dart',
  'backend_auth_case.dart',
  'backend_sync_case.dart',
  'backup_case.dart',
  'calendar_atomic_load_case.dart',
  'calendar_cache_coordinator_case.dart',
  'calendar_color_case.dart',
  'calendar_header_case.dart',
  'calendar_list_pagination_case.dart',
  'calendar_perf_case.dart',
  'calendar_screen_ui_case.dart',
  'calendar_swipe_case.dart',
  'calendar_ux_source_case.dart',
  'calendar_week_nav_case.dart',
  'countdown_link_case.dart',
  'countdowns_screen_case.dart',
  'db_case.dart',
  'design_components_case.dart',
  'design_data_components_case.dart',
  'design_foundation_case.dart',
  'device_calendar_import_case.dart',
  'dirty_guard_case.dart',
  'event_editor_time_case.dart',
  'event_rsvp_case.dart',
  'event_scope_case.dart',
  'event_source_case.dart',
  'focus_breaks_metrics_case.dart',
  'focus_overtime_case.dart',
  'focus_screen_case.dart',
  'focus_stopwatch_case.dart',
  'google_restore_case.dart',
  'google_sync_resilience_case.dart',
  'habit_calendar_repository_case.dart',
  'habit_delete_case.dart',
  'habit_focus_case.dart',
  'habit_percent_case.dart',
  'habit_schedule_case.dart',
  'habit_stats_case.dart',
  'habit_stats_screen_case.dart',
  'habit_streak_case.dart',
  'habits_screen_case.dart',
  'habits_timer_case.dart',
  'headless_widget_push_case.dart',
  'home_widget_binder_case.dart',
  'home_widget_callback_case.dart',
  'home_widget_case.dart',
  'l10n_case.dart',
  'markdown_editing_controller_case.dart',
  'matrix_case.dart',
  'matrix_layout_case.dart',
  'matrix_planned_case.dart',
  'microsoft_auth_case.dart',
  'microsoft_graph_case.dart',
  'microsoft_sync_engine_case.dart',
  'migration_replay_v11_v14_case.dart',
  'migration_v4_v5_case.dart',
  'migration_v7_v11_regression_case.dart',
  'month_view_case.dart',
  'note_editor_case.dart',
  'note_repository_case.dart',
  'notes_screen_grid_case.dart',
  'occurrence_cache_case.dart',
  'onboarding_case.dart',
  'onboarding_screen_case.dart',
  'parser_case.dart',
  'picker_memory_case.dart',
  'quick_add_case.dart',
  'quick_add_sheet_case.dart',
  'recurrence_case.dart',
  'search_case.dart',
  'session_restore_case.dart',
  'settings_case.dart',
  'settings_screen_case.dart',
  'settings_sync_status_case.dart',
  'shared_calendar_dedupe_case.dart',
  'smart_filter_case.dart',
  'source_label_case.dart',
  'source_move_case.dart',
  'source_picker_case.dart',
  'stream_agenda_case.dart',
  'stream_agenda_host_case.dart',
  'stream_ambient_case.dart',
  'stream_ambient_mount_case.dart',
  'stream_capture_actions_case.dart',
  'stream_capture_bar_case.dart',
  'stream_capture_parser_case.dart',
  'stream_capture_plan_case.dart',
  'stream_chrome_widgets_case.dart',
  'stream_command_actions_case.dart',
  'stream_command_overlay_case.dart',
  'stream_command_palette_case.dart',
  'stream_command_parser_case.dart',
  'stream_countdown_edge_case.dart',
  'stream_countdown_landmark_case.dart',
  'stream_countdown_layer_case.dart',
  'stream_countdown_math_case.dart',
  'stream_culler_case.dart',
  'stream_day_cache_case.dart',
  'stream_day_canvas_case.dart',
  'stream_day_controller_case.dart',
  'stream_day_gestures_case.dart',
  'stream_drag_overlay_case.dart',
  'stream_focus_band_case.dart',
  'stream_focus_case.dart',
  'stream_fuzzy_case.dart',
  'stream_gesture_school_case.dart',
  'stream_habit_gutter_case.dart',
  'stream_habit_layer_case.dart',
  'stream_habit_streak_case.dart',
  'stream_interactions_case.dart',
  'stream_interchange_case.dart',
  'stream_launcher_case.dart',
  'stream_layout_mode_case.dart',
  'stream_level_data_case.dart',
  'stream_level_host_case.dart',
  'stream_level_streaks_case.dart',
  'stream_level_transition_case.dart',
  'stream_mark_hit_test_case.dart',
  'stream_mark_layout_case.dart',
  'stream_mark_mapper_case.dart',
  'stream_month_view_case.dart',
  'stream_offline_banner_host_case.dart',
  'stream_peek_data_case.dart',
  'stream_peek_editor_case.dart',
  'stream_peek_editor_state_case.dart',
  'stream_peek_panel_case.dart',
  'stream_peek_sheet_case.dart',
  'stream_permission_banner_case.dart',
  'stream_platform_case.dart',
  'stream_restore_nav_case.dart',
  'stream_route_params_case.dart',
  'stream_school_host_case.dart',
  'stream_school_preferences_case.dart',
  'stream_screen_case.dart',
  'stream_settings_sheet_case.dart',
  'stream_slipped_data_case.dart',
  'stream_slipped_keyboard_case.dart',
  'stream_slipped_school_case.dart',
  'stream_slipped_sheet_case.dart',
  'stream_slipped_trail_case.dart',
  'stream_slipped_trail_host_case.dart',
  'stream_slipped_triage_case.dart',
  'stream_states_case.dart',
  'stream_surface_dock_case.dart',
  'stream_theme_case.dart',
  'stream_theme_preferences_case.dart',
  'stream_time_viewport_case.dart',
  'stream_tray_chip_case.dart',
  'stream_tray_data_case.dart',
  'stream_tray_drop_case.dart',
  'stream_tray_panel_grouping_case.dart',
  'stream_tray_panel_interaction_case.dart',
  'stream_tray_strip_case.dart',
  'stream_viewport_case.dart',
  'stream_week_view_case.dart',
  'stream_year_view_case.dart',
  'support_fixtures_case.dart',
  'sync_all_case.dart',
  'sync_attention_case.dart',
  'sync_calendar_integrity_case.dart',
  'sync_diagnostics_case.dart',
  'sync_engine_case.dart',
  'sync_engine_errors_case.dart',
  'sync_engine_ownership_case.dart',
  'sync_engine_task_lists_case.dart',
  'sync_fix_case.dart',
  'sync_reliability_case.dart',
  'sync_title_case.dart',
  'task_action_sheet_case.dart',
  'task_editor_case.dart',
  'task_editor_extra_case.dart',
  'task_repository_crud_case.dart',
  'task_repository_lifecycle_case.dart',
  'task_repository_lists_case.dart',
  'task_repository_recurrence_case.dart',
  'task_repository_smart_filter_case.dart',
  'tasks_screen_ui_case.dart',
  'timeline_layout_case.dart',
  'timeline_multiday_overflow_case.dart',
  'timeline_now_controller_case.dart',
  'timeline_persist_case.dart',
  'timeline_title_wrap_case.dart',
  'timeline_view_case.dart',
  'today_providers_case.dart',
  'today_screen_case.dart',
  'todo_coverage_case.dart',
  'todo_layout_scale_case.dart',
  'todo_sync_status_case.dart',
  'ui_preferences_case.dart',
  'ux_alarms_case.dart',
  'ux_calendar_case.dart',
  'ux_foundation_case.dart',
  'ux_notes_case.dart',
  'ux_search_case.dart',
  'ux_shell_case.dart',
  'ux_tasks_case.dart',
  'ux_wellness_case.dart',
  'week_calendar_case.dart',
  'week_widget_options_case.dart',
  'wellness_ui_case.dart',
  'widget_case.dart',
  'widget_config_case.dart',
  'widget_image_case.dart',
  'widget_provider_match_case.dart',
  'year_view_case.dart',
};

void main() {
  test('test runner includes every case file', () {
    expect(
      _caseFilesOnDisk(),
      _allCases,
      reason:
          'test runners are stale. Run: '
          'dart run tools/gen_test_runner.dart',
    );
  });

  group('account_email', account_email.main);
  group('adaptive_shell', adaptive_shell.main);
  group('alarm_migration_v4v5', alarm_migration_v4v5.main);
  group('alarm_notification_actions', alarm_notification_actions.main);
  group('alarm_overdue', alarm_overdue.main);
  group('alarm_repository', alarm_repository.main);
  group('alarm_title', alarm_title.main);
  group('alarm_window', alarm_window.main);
  group('app_lock', app_lock.main);
  group('auth_screen', auth_screen.main);
  group('backend_auth', backend_auth.main);
  group('backend_sync', backend_sync.main);
  group('backup', backup.main);
  group('calendar_atomic_load', calendar_atomic_load.main);
  group('calendar_cache_coordinator', calendar_cache_coordinator.main);
  group('calendar_color', calendar_color.main);
  group('calendar_header', calendar_header.main);
  group('calendar_list_pagination', calendar_list_pagination.main);
  group('calendar_perf', calendar_perf.main);
  group('calendar_screen_ui', calendar_screen_ui.main);
  group('calendar_swipe', calendar_swipe.main);
  group('calendar_ux_source', calendar_ux_source.main);
  group('calendar_week_nav', calendar_week_nav.main);
  group('countdown_link', countdown_link.main);
  group('countdowns_screen', countdowns_screen.main);
  group('db', db.main);
  group('design_components', design_components.main);
  group('design_data_components', design_data_components.main);
  group('design_foundation', design_foundation.main);
  group('device_calendar_import', device_calendar_import.main);
  group('dirty_guard', dirty_guard.main);
  group('event_editor_time', event_editor_time.main);
  group('event_rsvp', event_rsvp.main);
  group('event_scope', event_scope.main);
  group('event_source', event_source.main);
  group('focus_breaks_metrics', focus_breaks_metrics.main);
  group('focus_overtime', focus_overtime.main);
  group('focus_screen', focus_screen.main);
  group('focus_stopwatch', focus_stopwatch.main);
  group('google_restore', google_restore.main);
  group('google_sync_resilience', google_sync_resilience.main);
  group('habit_calendar_repository', habit_calendar_repository.main);
  group('habit_delete', habit_delete.main);
  group('habit_focus', habit_focus.main);
  group('habit_percent', habit_percent.main);
  group('habit_schedule', habit_schedule.main);
  group('habit_stats', habit_stats.main);
  group('habit_stats_screen', habit_stats_screen.main);
  group('habit_streak', habit_streak.main);
  group('habits_screen', habits_screen.main);
  group('habits_timer', habits_timer.main);
  group('headless_widget_push', headless_widget_push.main);
  group('home_widget_binder', home_widget_binder.main);
  group('home_widget_callback', home_widget_callback.main);
  group('home_widget', home_widget.main);
  group('l10n', l10n.main);
  group('markdown_editing_controller', markdown_editing_controller.main);
  group('matrix', matrix.main);
  group('matrix_layout', matrix_layout.main);
  group('matrix_planned', matrix_planned.main);
  group('microsoft_auth', microsoft_auth.main);
  group('microsoft_graph', microsoft_graph.main);
}

Set<String> _caseFilesOnDisk() {
  _checkNoStrayEntrypoints();
  return Directory('test/cases')
      .listSync()
      .whereType<File>()
      .map((f) => f.uri.pathSegments.last)
      .where((name) => name.endsWith('_case.dart'))
      .toSet();
}

void _checkNoStrayEntrypoints() {
  final shard = RegExp(r'^test/shard[0-9]+_test\.dart$');
  final stray = Directory('test')
      .listSync(recursive: true)
      .whereType<File>()
      .map((f) => f.path.replaceAll(r'\', '/'))
      .where((path) => path.endsWith('_test.dart'))
      .where((path) => !shard.hasMatch(path))
      .toSet();
  expect(
    stray,
    isEmpty,
    reason:
        'Move top-level test files under test/cases/ as '
        '*_case.dart and regenerate the test runners.',
  );
}
