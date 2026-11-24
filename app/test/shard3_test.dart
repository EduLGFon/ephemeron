// GENERATED CODE - DO NOT MODIFY BY HAND.
// Run: dart run tools/gen_test_runner.dart
//
// Shard 3 of 4. Each shard owns a contiguous
// range of cases and pays one kernel compile.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'cases/stream_slipped_trail_host_case.dart' as stream_slipped_trail_host;
import 'cases/stream_slipped_triage_case.dart' as stream_slipped_triage;
import 'cases/stream_states_case.dart' as stream_states;
import 'cases/stream_surface_dock_case.dart' as stream_surface_dock;
import 'cases/stream_theme_case.dart' as stream_theme;
import 'cases/stream_theme_preferences_case.dart' as stream_theme_preferences;
import 'cases/stream_time_viewport_case.dart' as stream_time_viewport;
import 'cases/stream_tray_chip_case.dart' as stream_tray_chip;
import 'cases/stream_tray_data_case.dart' as stream_tray_data;
import 'cases/stream_tray_drop_case.dart' as stream_tray_drop;
import 'cases/stream_tray_panel_grouping_case.dart'
    as stream_tray_panel_grouping;
import 'cases/stream_tray_panel_interaction_case.dart'
    as stream_tray_panel_interaction;
import 'cases/stream_tray_strip_case.dart' as stream_tray_strip;
import 'cases/stream_viewport_case.dart' as stream_viewport;
import 'cases/stream_week_view_case.dart' as stream_week_view;
import 'cases/stream_year_view_case.dart' as stream_year_view;
import 'cases/support_fixtures_case.dart' as support_fixtures;
import 'cases/sync_all_case.dart' as sync_all;
import 'cases/sync_attention_case.dart' as sync_attention;
import 'cases/sync_calendar_integrity_case.dart' as sync_calendar_integrity;
import 'cases/sync_diagnostics_case.dart' as sync_diagnostics;
import 'cases/sync_engine_case.dart' as sync_engine;
import 'cases/sync_engine_errors_case.dart' as sync_engine_errors;
import 'cases/sync_engine_ownership_case.dart' as sync_engine_ownership;
import 'cases/sync_engine_task_lists_case.dart' as sync_engine_task_lists;
import 'cases/sync_fix_case.dart' as sync_fix;
import 'cases/sync_reliability_case.dart' as sync_reliability;
import 'cases/sync_title_case.dart' as sync_title;
import 'cases/task_action_sheet_case.dart' as task_action_sheet;
import 'cases/task_editor_case.dart' as task_editor;
import 'cases/task_editor_extra_case.dart' as task_editor_extra;
import 'cases/task_repository_crud_case.dart' as task_repository_crud;
import 'cases/task_repository_lifecycle_case.dart' as task_repository_lifecycle;
import 'cases/task_repository_lists_case.dart' as task_repository_lists;
import 'cases/task_repository_recurrence_case.dart'
    as task_repository_recurrence;
import 'cases/task_repository_smart_filter_case.dart'
    as task_repository_smart_filter;
import 'cases/tasks_screen_ui_case.dart' as tasks_screen_ui;
import 'cases/timeline_layout_case.dart' as timeline_layout;
import 'cases/timeline_multiday_overflow_case.dart'
    as timeline_multiday_overflow;
import 'cases/timeline_now_controller_case.dart' as timeline_now_controller;
import 'cases/timeline_persist_case.dart' as timeline_persist;
import 'cases/timeline_title_wrap_case.dart' as timeline_title_wrap;
import 'cases/timeline_view_case.dart' as timeline_view;
import 'cases/today_providers_case.dart' as today_providers;
import 'cases/today_screen_case.dart' as today_screen;
import 'cases/todo_coverage_case.dart' as todo_coverage;
import 'cases/todo_layout_scale_case.dart' as todo_layout_scale;
import 'cases/todo_sync_status_case.dart' as todo_sync_status;
import 'cases/ui_preferences_case.dart' as ui_preferences;
import 'cases/ux_alarms_case.dart' as ux_alarms;
import 'cases/ux_calendar_case.dart' as ux_calendar;
import 'cases/ux_foundation_case.dart' as ux_foundation;
import 'cases/ux_notes_case.dart' as ux_notes;
import 'cases/ux_search_case.dart' as ux_search;
import 'cases/ux_shell_case.dart' as ux_shell;
import 'cases/ux_tasks_case.dart' as ux_tasks;
import 'cases/ux_wellness_case.dart' as ux_wellness;
import 'cases/week_calendar_case.dart' as week_calendar;
import 'cases/week_widget_options_case.dart' as week_widget_options;
import 'cases/wellness_ui_case.dart' as wellness_ui;
import 'cases/widget_case.dart' as widget;
import 'cases/widget_config_case.dart' as widget_config;
import 'cases/widget_image_case.dart' as widget_image;
import 'cases/widget_provider_match_case.dart' as widget_provider_match;
import 'cases/year_view_case.dart' as year_view;

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

  group('stream_slipped_trail_host', stream_slipped_trail_host.main);
  group('stream_slipped_triage', stream_slipped_triage.main);
  group('stream_states', stream_states.main);
  group('stream_surface_dock', stream_surface_dock.main);
  group('stream_theme', stream_theme.main);
  group('stream_theme_preferences', stream_theme_preferences.main);
  group('stream_time_viewport', stream_time_viewport.main);
  group('stream_tray_chip', stream_tray_chip.main);
  group('stream_tray_data', stream_tray_data.main);
  group('stream_tray_drop', stream_tray_drop.main);
  group('stream_tray_panel_grouping', stream_tray_panel_grouping.main);
  group('stream_tray_panel_interaction', stream_tray_panel_interaction.main);
  group('stream_tray_strip', stream_tray_strip.main);
  group('stream_viewport', stream_viewport.main);
  group('stream_week_view', stream_week_view.main);
  group('stream_year_view', stream_year_view.main);
  group('support_fixtures', support_fixtures.main);
  group('sync_all', sync_all.main);
  group('sync_attention', sync_attention.main);
  group('sync_calendar_integrity', sync_calendar_integrity.main);
  group('sync_diagnostics', sync_diagnostics.main);
  group('sync_engine', sync_engine.main);
  group('sync_engine_errors', sync_engine_errors.main);
  group('sync_engine_ownership', sync_engine_ownership.main);
  group('sync_engine_task_lists', sync_engine_task_lists.main);
  group('sync_fix', sync_fix.main);
  group('sync_reliability', sync_reliability.main);
  group('sync_title', sync_title.main);
  group('task_action_sheet', task_action_sheet.main);
  group('task_editor', task_editor.main);
  group('task_editor_extra', task_editor_extra.main);
  group('task_repository_crud', task_repository_crud.main);
  group('task_repository_lifecycle', task_repository_lifecycle.main);
  group('task_repository_lists', task_repository_lists.main);
  group('task_repository_recurrence', task_repository_recurrence.main);
  group('task_repository_smart_filter', task_repository_smart_filter.main);
  group('tasks_screen_ui', tasks_screen_ui.main);
  group('timeline_layout', timeline_layout.main);
  group('timeline_multiday_overflow', timeline_multiday_overflow.main);
  group('timeline_now_controller', timeline_now_controller.main);
  group('timeline_persist', timeline_persist.main);
  group('timeline_title_wrap', timeline_title_wrap.main);
  group('timeline_view', timeline_view.main);
  group('today_providers', today_providers.main);
  group('today_screen', today_screen.main);
  group('todo_coverage', todo_coverage.main);
  group('todo_layout_scale', todo_layout_scale.main);
  group('todo_sync_status', todo_sync_status.main);
  group('ui_preferences', ui_preferences.main);
  group('ux_alarms', ux_alarms.main);
  group('ux_calendar', ux_calendar.main);
  group('ux_foundation', ux_foundation.main);
  group('ux_notes', ux_notes.main);
  group('ux_search', ux_search.main);
  group('ux_shell', ux_shell.main);
  group('ux_tasks', ux_tasks.main);
  group('ux_wellness', ux_wellness.main);
  group('week_calendar', week_calendar.main);
  group('week_widget_options', week_widget_options.main);
  group('wellness_ui', wellness_ui.main);
  group('widget', widget.main);
  group('widget_config', widget_config.main);
  group('widget_image', widget_image.main);
  group('widget_provider_match', widget_provider_match.main);
  group('year_view', year_view.main);
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
