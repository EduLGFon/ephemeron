// GENERATED CODE - DO NOT MODIFY BY HAND.
// Run: dart run tools/gen_test_runner.dart
//
// One entrypoint for every case file. Flutter compiles one kernel per
// test file, so keeping the suite in a single file removes that cost.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'cases/account_email_case.dart' as account_email;
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
import 'cases/calendar_color_case.dart' as calendar_color;
import 'cases/calendar_header_case.dart' as calendar_header;
import 'cases/calendar_list_pagination_case.dart' as calendar_list_pagination;
import 'cases/calendar_perf_case.dart' as calendar_perf;
import 'cases/calendar_swipe_case.dart' as calendar_swipe;
import 'cases/calendar_ux_source_case.dart' as calendar_ux_source;
import 'cases/calendar_week_nav_case.dart' as calendar_week_nav;
import 'cases/countdown_link_case.dart' as countdown_link;
import 'cases/countdowns_screen_case.dart' as countdowns_screen;
import 'cases/db_case.dart' as db;
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
import 'cases/parser_case.dart' as parser;
import 'cases/picker_memory_case.dart' as picker_memory;
import 'cases/quick_add_case.dart' as quick_add;
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
import 'cases/stream_capture_bar_case.dart' as stream_capture_bar;
import 'cases/stream_capture_parser_case.dart' as stream_capture_parser;
import 'cases/stream_chrome_widgets_case.dart' as stream_chrome_widgets;
import 'cases/stream_command_actions_case.dart' as stream_command_actions;
import 'cases/stream_command_palette_case.dart' as stream_command_palette;
import 'cases/stream_command_parser_case.dart' as stream_command_parser;
import 'cases/stream_countdown_edge_case.dart' as stream_countdown_edge;
import 'cases/stream_countdown_landmark_case.dart' as stream_countdown_landmark;
import 'cases/stream_countdown_math_case.dart' as stream_countdown_math;
import 'cases/stream_culler_case.dart' as stream_culler;
import 'cases/stream_day_canvas_case.dart' as stream_day_canvas;
import 'cases/stream_day_gestures_case.dart' as stream_day_gestures;
import 'cases/stream_drag_overlay_case.dart' as stream_drag_overlay;
import 'cases/stream_focus_case.dart' as stream_focus;
import 'cases/stream_fuzzy_case.dart' as stream_fuzzy;
import 'cases/stream_gesture_school_case.dart' as stream_gesture_school;
import 'cases/stream_habit_gutter_case.dart' as stream_habit_gutter;
import 'cases/stream_habit_streak_case.dart' as stream_habit_streak;
import 'cases/stream_layout_mode_case.dart' as stream_layout_mode;
import 'cases/stream_level_data_case.dart' as stream_level_data;
import 'cases/stream_level_transition_case.dart' as stream_level_transition;
import 'cases/stream_mark_hit_test_case.dart' as stream_mark_hit_test;
import 'cases/stream_mark_layout_case.dart' as stream_mark_layout;
import 'cases/stream_mark_mapper_case.dart' as stream_mark_mapper;
import 'cases/stream_month_view_case.dart' as stream_month_view;
import 'cases/stream_peek_editor_case.dart' as stream_peek_editor;
import 'cases/stream_peek_editor_state_case.dart' as stream_peek_editor_state;
import 'cases/stream_peek_panel_case.dart' as stream_peek_panel;
import 'cases/stream_platform_case.dart' as stream_platform;
import 'cases/stream_route_params_case.dart' as stream_route_params;
import 'cases/stream_screen_case.dart' as stream_screen;
import 'cases/stream_slipped_keyboard_case.dart' as stream_slipped_keyboard;
import 'cases/stream_slipped_trail_case.dart' as stream_slipped_trail;
import 'cases/stream_slipped_triage_case.dart' as stream_slipped_triage;
import 'cases/stream_states_case.dart' as stream_states;
import 'cases/stream_theme_case.dart' as stream_theme;
import 'cases/stream_theme_preferences_case.dart' as stream_theme_preferences;
import 'cases/stream_time_viewport_case.dart' as stream_time_viewport;
import 'cases/stream_tray_chip_case.dart' as stream_tray_chip;
import 'cases/stream_tray_panel_grouping_case.dart'
    as stream_tray_panel_grouping;
import 'cases/stream_tray_panel_interaction_case.dart'
    as stream_tray_panel_interaction;
import 'cases/stream_tray_strip_case.dart' as stream_tray_strip;
import 'cases/stream_viewport_case.dart' as stream_viewport;
import 'cases/stream_week_view_case.dart' as stream_week_view;
import 'cases/sync_all_case.dart' as sync_all;
import 'cases/sync_attention_case.dart' as sync_attention;
import 'cases/sync_calendar_integrity_case.dart' as sync_calendar_integrity;
import 'cases/sync_diagnostics_case.dart' as sync_diagnostics;
import 'cases/sync_engine_case.dart' as sync_engine;
import 'cases/sync_engine_errors_case.dart' as sync_engine_errors;
import 'cases/sync_engine_ownership_case.dart' as sync_engine_ownership;
import 'cases/sync_engine_task_lists_case.dart' as sync_engine_task_lists;
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
import 'cases/timeline_layout_case.dart' as timeline_layout;
import 'cases/timeline_multiday_overflow_case.dart'
    as timeline_multiday_overflow;
import 'cases/timeline_now_controller_case.dart' as timeline_now_controller;
import 'cases/timeline_persist_case.dart' as timeline_persist;
import 'cases/timeline_title_wrap_case.dart' as timeline_title_wrap;
import 'cases/timeline_view_case.dart' as timeline_view;
import 'cases/todo_coverage_case.dart' as todo_coverage;
import 'cases/todo_layout_scale_case.dart' as todo_layout_scale;
import 'cases/todo_sync_status_case.dart' as todo_sync_status;
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
import 'cases/widget_case.dart' as widget;
import 'cases/widget_config_case.dart' as widget_config;
import 'cases/widget_image_case.dart' as widget_image;
import 'cases/widget_provider_match_case.dart' as widget_provider_match;
import 'cases/year_view_case.dart' as year_view;

const _included = <String>{
  'account_email_case.dart',
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
  'calendar_color_case.dart',
  'calendar_header_case.dart',
  'calendar_list_pagination_case.dart',
  'calendar_perf_case.dart',
  'calendar_swipe_case.dart',
  'calendar_ux_source_case.dart',
  'calendar_week_nav_case.dart',
  'countdown_link_case.dart',
  'countdowns_screen_case.dart',
  'db_case.dart',
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
  'parser_case.dart',
  'picker_memory_case.dart',
  'quick_add_case.dart',
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
  'stream_capture_bar_case.dart',
  'stream_capture_parser_case.dart',
  'stream_chrome_widgets_case.dart',
  'stream_command_actions_case.dart',
  'stream_command_palette_case.dart',
  'stream_command_parser_case.dart',
  'stream_countdown_edge_case.dart',
  'stream_countdown_landmark_case.dart',
  'stream_countdown_math_case.dart',
  'stream_culler_case.dart',
  'stream_day_canvas_case.dart',
  'stream_day_gestures_case.dart',
  'stream_drag_overlay_case.dart',
  'stream_focus_case.dart',
  'stream_fuzzy_case.dart',
  'stream_gesture_school_case.dart',
  'stream_habit_gutter_case.dart',
  'stream_habit_streak_case.dart',
  'stream_layout_mode_case.dart',
  'stream_level_data_case.dart',
  'stream_level_transition_case.dart',
  'stream_mark_hit_test_case.dart',
  'stream_mark_layout_case.dart',
  'stream_mark_mapper_case.dart',
  'stream_month_view_case.dart',
  'stream_peek_editor_case.dart',
  'stream_peek_editor_state_case.dart',
  'stream_peek_panel_case.dart',
  'stream_platform_case.dart',
  'stream_route_params_case.dart',
  'stream_screen_case.dart',
  'stream_slipped_keyboard_case.dart',
  'stream_slipped_trail_case.dart',
  'stream_slipped_triage_case.dart',
  'stream_states_case.dart',
  'stream_theme_case.dart',
  'stream_theme_preferences_case.dart',
  'stream_time_viewport_case.dart',
  'stream_tray_chip_case.dart',
  'stream_tray_panel_grouping_case.dart',
  'stream_tray_panel_interaction_case.dart',
  'stream_tray_strip_case.dart',
  'stream_viewport_case.dart',
  'stream_week_view_case.dart',
  'sync_all_case.dart',
  'sync_attention_case.dart',
  'sync_calendar_integrity_case.dart',
  'sync_diagnostics_case.dart',
  'sync_engine_case.dart',
  'sync_engine_errors_case.dart',
  'sync_engine_ownership_case.dart',
  'sync_engine_task_lists_case.dart',
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
  'timeline_layout_case.dart',
  'timeline_multiday_overflow_case.dart',
  'timeline_now_controller_case.dart',
  'timeline_persist_case.dart',
  'timeline_title_wrap_case.dart',
  'timeline_view_case.dart',
  'todo_coverage_case.dart',
  'todo_layout_scale_case.dart',
  'todo_sync_status_case.dart',
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
      _included,
      reason:
          'test/all_test.dart is stale. Run: '
          'dart run tools/gen_test_runner.dart',
    );
  });

  group('account_email', account_email.main);
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
  group('calendar_color', calendar_color.main);
  group('calendar_header', calendar_header.main);
  group('calendar_list_pagination', calendar_list_pagination.main);
  group('calendar_perf', calendar_perf.main);
  group('calendar_swipe', calendar_swipe.main);
  group('calendar_ux_source', calendar_ux_source.main);
  group('calendar_week_nav', calendar_week_nav.main);
  group('countdown_link', countdown_link.main);
  group('countdowns_screen', countdowns_screen.main);
  group('db', db.main);
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
  group('parser', parser.main);
  group('picker_memory', picker_memory.main);
  group('quick_add', quick_add.main);
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
  group('stream_capture_bar', stream_capture_bar.main);
  group('stream_capture_parser', stream_capture_parser.main);
  group('stream_chrome_widgets', stream_chrome_widgets.main);
  group('stream_command_actions', stream_command_actions.main);
  group('stream_command_palette', stream_command_palette.main);
  group('stream_command_parser', stream_command_parser.main);
  group('stream_countdown_edge', stream_countdown_edge.main);
  group('stream_countdown_landmark', stream_countdown_landmark.main);
  group('stream_countdown_math', stream_countdown_math.main);
  group('stream_culler', stream_culler.main);
  group('stream_day_canvas', stream_day_canvas.main);
  group('stream_day_gestures', stream_day_gestures.main);
  group('stream_drag_overlay', stream_drag_overlay.main);
  group('stream_focus', stream_focus.main);
  group('stream_fuzzy', stream_fuzzy.main);
  group('stream_gesture_school', stream_gesture_school.main);
  group('stream_habit_gutter', stream_habit_gutter.main);
  group('stream_habit_streak', stream_habit_streak.main);
  group('stream_layout_mode', stream_layout_mode.main);
  group('stream_level_data', stream_level_data.main);
  group('stream_level_transition', stream_level_transition.main);
  group('stream_mark_hit_test', stream_mark_hit_test.main);
  group('stream_mark_layout', stream_mark_layout.main);
  group('stream_mark_mapper', stream_mark_mapper.main);
  group('stream_month_view', stream_month_view.main);
  group('stream_peek_editor', stream_peek_editor.main);
  group('stream_peek_editor_state', stream_peek_editor_state.main);
  group('stream_peek_panel', stream_peek_panel.main);
  group('stream_platform', stream_platform.main);
  group('stream_route_params', stream_route_params.main);
  group('stream_screen', stream_screen.main);
  group('stream_slipped_keyboard', stream_slipped_keyboard.main);
  group('stream_slipped_trail', stream_slipped_trail.main);
  group('stream_slipped_triage', stream_slipped_triage.main);
  group('stream_states', stream_states.main);
  group('stream_theme', stream_theme.main);
  group('stream_theme_preferences', stream_theme_preferences.main);
  group('stream_time_viewport', stream_time_viewport.main);
  group('stream_tray_chip', stream_tray_chip.main);
  group('stream_tray_panel_grouping', stream_tray_panel_grouping.main);
  group('stream_tray_panel_interaction', stream_tray_panel_interaction.main);
  group('stream_tray_strip', stream_tray_strip.main);
  group('stream_viewport', stream_viewport.main);
  group('stream_week_view', stream_week_view.main);
  group('sync_all', sync_all.main);
  group('sync_attention', sync_attention.main);
  group('sync_calendar_integrity', sync_calendar_integrity.main);
  group('sync_diagnostics', sync_diagnostics.main);
  group('sync_engine', sync_engine.main);
  group('sync_engine_errors', sync_engine_errors.main);
  group('sync_engine_ownership', sync_engine_ownership.main);
  group('sync_engine_task_lists', sync_engine_task_lists.main);
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
  group('timeline_layout', timeline_layout.main);
  group('timeline_multiday_overflow', timeline_multiday_overflow.main);
  group('timeline_now_controller', timeline_now_controller.main);
  group('timeline_persist', timeline_persist.main);
  group('timeline_title_wrap', timeline_title_wrap.main);
  group('timeline_view', timeline_view.main);
  group('todo_coverage', todo_coverage.main);
  group('todo_layout_scale', todo_layout_scale.main);
  group('todo_sync_status', todo_sync_status.main);
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
  group('widget', widget.main);
  group('widget_config', widget_config.main);
  group('widget_image', widget_image.main);
  group('widget_provider_match', widget_provider_match.main);
  group('year_view', year_view.main);
}

Set<String> _caseFilesOnDisk() {
  final cases = Directory('test/cases')
      .listSync()
      .whereType<File>()
      .map((f) => f.uri.pathSegments.last)
      .where((name) => name.endsWith('_case.dart'))
      .toSet();
  final stray = Directory('test')
      .listSync(recursive: true)
      .whereType<File>()
      .map((f) => f.path.replaceAll(r'\', '/'))
      .where((path) => path.endsWith('_test.dart'))
      .where((path) => !path.endsWith('/all_test.dart'))
      .toSet();
  expect(
    stray,
    isEmpty,
    reason:
        'Move top-level test files under test/cases/ as '
        '*_case.dart and regenerate this runner.',
  );
  return cases;
}
