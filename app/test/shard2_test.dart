// GENERATED CODE - DO NOT MODIFY BY HAND.
// Run: dart run tools/gen_test_runner.dart
//
// Shard 2 of 4. Each shard owns a contiguous
// range of cases and pays one kernel compile.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'cases/stream_focus_case.dart' as stream_focus;
import 'cases/stream_fuzzy_case.dart' as stream_fuzzy;
import 'cases/stream_gesture_school_case.dart' as stream_gesture_school;
import 'cases/stream_habit_gutter_case.dart' as stream_habit_gutter;
import 'cases/stream_habit_layer_case.dart' as stream_habit_layer;
import 'cases/stream_habit_streak_case.dart' as stream_habit_streak;
import 'cases/stream_interactions_case.dart' as stream_interactions;
import 'cases/stream_interchange_case.dart' as stream_interchange;
import 'cases/stream_launcher_case.dart' as stream_launcher;
import 'cases/stream_layout_mode_case.dart' as stream_layout_mode;
import 'cases/stream_level_data_case.dart' as stream_level_data;
import 'cases/stream_level_host_case.dart' as stream_level_host;
import 'cases/stream_level_streaks_case.dart' as stream_level_streaks;
import 'cases/stream_level_transition_case.dart' as stream_level_transition;
import 'cases/stream_mark_hit_test_case.dart' as stream_mark_hit_test;
import 'cases/stream_mark_layout_case.dart' as stream_mark_layout;
import 'cases/stream_mark_mapper_case.dart' as stream_mark_mapper;
import 'cases/stream_month_view_case.dart' as stream_month_view;
import 'cases/stream_offline_banner_host_case.dart'
    as stream_offline_banner_host;
import 'cases/stream_peek_data_case.dart' as stream_peek_data;
import 'cases/stream_peek_editor_case.dart' as stream_peek_editor;
import 'cases/stream_peek_editor_state_case.dart' as stream_peek_editor_state;
import 'cases/stream_peek_panel_case.dart' as stream_peek_panel;
import 'cases/stream_peek_sheet_case.dart' as stream_peek_sheet;
import 'cases/stream_permission_banner_case.dart' as stream_permission_banner;
import 'cases/stream_platform_case.dart' as stream_platform;
import 'cases/stream_restore_nav_case.dart' as stream_restore_nav;
import 'cases/stream_route_params_case.dart' as stream_route_params;
import 'cases/stream_school_host_case.dart' as stream_school_host;
import 'cases/stream_school_preferences_case.dart' as stream_school_preferences;
import 'cases/stream_screen_case.dart' as stream_screen;
import 'cases/stream_settings_sheet_case.dart' as stream_settings_sheet;
import 'cases/stream_slipped_data_case.dart' as stream_slipped_data;
import 'cases/stream_slipped_keyboard_case.dart' as stream_slipped_keyboard;
import 'cases/stream_slipped_school_case.dart' as stream_slipped_school;
import 'cases/stream_slipped_sheet_case.dart' as stream_slipped_sheet;
import 'cases/stream_slipped_trail_case.dart' as stream_slipped_trail;

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

  group('stream_focus', stream_focus.main);
  group('stream_fuzzy', stream_fuzzy.main);
  group('stream_gesture_school', stream_gesture_school.main);
  group('stream_habit_gutter', stream_habit_gutter.main);
  group('stream_habit_layer', stream_habit_layer.main);
  group('stream_habit_streak', stream_habit_streak.main);
  group('stream_interactions', stream_interactions.main);
  group('stream_interchange', stream_interchange.main);
  group('stream_launcher', stream_launcher.main);
  group('stream_layout_mode', stream_layout_mode.main);
  group('stream_level_data', stream_level_data.main);
  group('stream_level_host', stream_level_host.main);
  group('stream_level_streaks', stream_level_streaks.main);
  group('stream_level_transition', stream_level_transition.main);
  group('stream_mark_hit_test', stream_mark_hit_test.main);
  group('stream_mark_layout', stream_mark_layout.main);
  group('stream_mark_mapper', stream_mark_mapper.main);
  group('stream_month_view', stream_month_view.main);
  group('stream_offline_banner_host', stream_offline_banner_host.main);
  group('stream_peek_data', stream_peek_data.main);
  group('stream_peek_editor', stream_peek_editor.main);
  group('stream_peek_editor_state', stream_peek_editor_state.main);
  group('stream_peek_panel', stream_peek_panel.main);
  group('stream_peek_sheet', stream_peek_sheet.main);
  group('stream_permission_banner', stream_permission_banner.main);
  group('stream_platform', stream_platform.main);
  group('stream_restore_nav', stream_restore_nav.main);
  group('stream_route_params', stream_route_params.main);
  group('stream_school_host', stream_school_host.main);
  group('stream_school_preferences', stream_school_preferences.main);
  group('stream_screen', stream_screen.main);
  group('stream_settings_sheet', stream_settings_sheet.main);
  group('stream_slipped_data', stream_slipped_data.main);
  group('stream_slipped_keyboard', stream_slipped_keyboard.main);
  group('stream_slipped_school', stream_slipped_school.main);
  group('stream_slipped_sheet', stream_slipped_sheet.main);
  group('stream_slipped_trail', stream_slipped_trail.main);
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
