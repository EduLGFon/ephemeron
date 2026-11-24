// GENERATED CODE - DO NOT MODIFY BY HAND.
// Run: dart run tools/gen_test_runner.dart
//
// Shard 1 of 4. Each shard owns a contiguous
// range of cases and pays one kernel compile.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'cases/microsoft_sync_engine_case.dart' as microsoft_sync_engine;
import 'cases/migration_replay_v11_v14_case.dart' as migration_replay_v11_v14;
import 'cases/migration_v4_v5_case.dart' as migration_v4_v5;
import 'cases/migration_v7_v11_regression_case.dart'
    as migration_v7_v11_regression;
import 'cases/month_view_case.dart' as month_view;
import 'cases/note_editor_case.dart' as note_editor;
import 'cases/note_repository_case.dart' as note_repository;
import 'cases/notes_screen_grid_case.dart' as notes_screen_grid;
import 'cases/occurrence_cache_case.dart' as occurrence_cache;
import 'cases/onboarding_case.dart' as onboarding;
import 'cases/onboarding_screen_case.dart' as onboarding_screen;
import 'cases/parser_case.dart' as parser;
import 'cases/picker_memory_case.dart' as picker_memory;
import 'cases/quick_add_case.dart' as quick_add;
import 'cases/quick_add_sheet_case.dart' as quick_add_sheet;
import 'cases/recurrence_case.dart' as recurrence;
import 'cases/search_case.dart' as search;
import 'cases/session_restore_case.dart' as session_restore;
import 'cases/settings_case.dart' as settings;
import 'cases/settings_screen_case.dart' as settings_screen;
import 'cases/settings_sync_status_case.dart' as settings_sync_status;
import 'cases/shared_calendar_dedupe_case.dart' as shared_calendar_dedupe;
import 'cases/smart_filter_case.dart' as smart_filter;
import 'cases/source_label_case.dart' as source_label;
import 'cases/source_move_case.dart' as source_move;
import 'cases/source_picker_case.dart' as source_picker;
import 'cases/stream_agenda_case.dart' as stream_agenda;
import 'cases/stream_agenda_host_case.dart' as stream_agenda_host;
import 'cases/stream_ambient_case.dart' as stream_ambient;
import 'cases/stream_ambient_mount_case.dart' as stream_ambient_mount;
import 'cases/stream_capture_actions_case.dart' as stream_capture_actions;
import 'cases/stream_capture_bar_case.dart' as stream_capture_bar;
import 'cases/stream_capture_parser_case.dart' as stream_capture_parser;
import 'cases/stream_capture_plan_case.dart' as stream_capture_plan;
import 'cases/stream_chrome_widgets_case.dart' as stream_chrome_widgets;
import 'cases/stream_command_actions_case.dart' as stream_command_actions;
import 'cases/stream_command_overlay_case.dart' as stream_command_overlay;
import 'cases/stream_command_palette_case.dart' as stream_command_palette;
import 'cases/stream_command_parser_case.dart' as stream_command_parser;
import 'cases/stream_countdown_edge_case.dart' as stream_countdown_edge;
import 'cases/stream_countdown_landmark_case.dart' as stream_countdown_landmark;
import 'cases/stream_countdown_layer_case.dart' as stream_countdown_layer;
import 'cases/stream_countdown_math_case.dart' as stream_countdown_math;
import 'cases/stream_culler_case.dart' as stream_culler;
import 'cases/stream_day_cache_case.dart' as stream_day_cache;
import 'cases/stream_day_canvas_case.dart' as stream_day_canvas;
import 'cases/stream_day_controller_case.dart' as stream_day_controller;
import 'cases/stream_day_gestures_case.dart' as stream_day_gestures;
import 'cases/stream_drag_overlay_case.dart' as stream_drag_overlay;
import 'cases/stream_focus_band_case.dart' as stream_focus_band;

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

  group('microsoft_sync_engine', microsoft_sync_engine.main);
  group('migration_replay_v11_v14', migration_replay_v11_v14.main);
  group('migration_v4_v5', migration_v4_v5.main);
  group('migration_v7_v11_regression', migration_v7_v11_regression.main);
  group('month_view', month_view.main);
  group('note_editor', note_editor.main);
  group('note_repository', note_repository.main);
  group('notes_screen_grid', notes_screen_grid.main);
  group('occurrence_cache', occurrence_cache.main);
  group('onboarding', onboarding.main);
  group('onboarding_screen', onboarding_screen.main);
  group('parser', parser.main);
  group('picker_memory', picker_memory.main);
  group('quick_add', quick_add.main);
  group('quick_add_sheet', quick_add_sheet.main);
  group('recurrence', recurrence.main);
  group('search', search.main);
  group('session_restore', session_restore.main);
  group('settings', settings.main);
  group('settings_screen', settings_screen.main);
  group('settings_sync_status', settings_sync_status.main);
  group('shared_calendar_dedupe', shared_calendar_dedupe.main);
  group('smart_filter', smart_filter.main);
  group('source_label', source_label.main);
  group('source_move', source_move.main);
  group('source_picker', source_picker.main);
  group('stream_agenda', stream_agenda.main);
  group('stream_agenda_host', stream_agenda_host.main);
  group('stream_ambient', stream_ambient.main);
  group('stream_ambient_mount', stream_ambient_mount.main);
  group('stream_capture_actions', stream_capture_actions.main);
  group('stream_capture_bar', stream_capture_bar.main);
  group('stream_capture_parser', stream_capture_parser.main);
  group('stream_capture_plan', stream_capture_plan.main);
  group('stream_chrome_widgets', stream_chrome_widgets.main);
  group('stream_command_actions', stream_command_actions.main);
  group('stream_command_overlay', stream_command_overlay.main);
  group('stream_command_palette', stream_command_palette.main);
  group('stream_command_parser', stream_command_parser.main);
  group('stream_countdown_edge', stream_countdown_edge.main);
  group('stream_countdown_landmark', stream_countdown_landmark.main);
  group('stream_countdown_layer', stream_countdown_layer.main);
  group('stream_countdown_math', stream_countdown_math.main);
  group('stream_culler', stream_culler.main);
  group('stream_day_cache', stream_day_cache.main);
  group('stream_day_canvas', stream_day_canvas.main);
  group('stream_day_controller', stream_day_controller.main);
  group('stream_day_gestures', stream_day_gestures.main);
  group('stream_drag_overlay', stream_drag_overlay.main);
  group('stream_focus_band', stream_focus_band.main);
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
