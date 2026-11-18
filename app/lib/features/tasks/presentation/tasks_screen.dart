// Tasks screen: list and smart-list chips, quick filters, search, swipe
// complete/reschedule with 6 s undo, custom drag order and detail entry.
// Data and action methods live in the part files so the chrome stays small.
import 'package:flutter/foundation.dart' show listEquals;
import 'package:material_ui/material_ui.dart';
import 'package:ephemeron/core/design/components/app_buttons.dart';
import 'package:ephemeron/core/design/components/app_chips.dart';
import 'package:ephemeron/core/design/components/app_fields.dart';
import 'package:ephemeron/core/design/components/app_headers.dart';
import 'package:ephemeron/core/design/components/app_overlays.dart';
import 'package:ephemeron/core/design/components/app_page.dart';
import 'package:ephemeron/core/design/components/app_states.dart';
import 'package:ephemeron/core/design/components/rows.dart';
import 'package:ephemeron/core/design/tokens.dart';
import 'package:ephemeron/core/time/device_date_format.dart';
import 'package:ephemeron/core/time/time.dart';
import 'package:ephemeron/core/ui/app_feedback.dart';
import 'package:ephemeron/core/ui/app_sheet.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/drift/app_database.dart';
import '../../../domain/sources/microsoft_source.dart';
import '../../../domain/sources/source_label.dart';
import '../../../domain/tasks/task_sort.dart';
import '../../calendar/presentation/task_action_sheet.dart';
import '../../settings/application/settings_providers.dart';
import '../../sync/application/pending_operations.dart';
import '../application/task_sorting.dart';
import '../application/tasks_providers.dart';
import 'quick_add_sheet.dart';
import 'smart_list_editor_sheet.dart';
import 'smart_lists_screen.dart';
import 'task_editor_sheet.dart';
import 'task_list_dialogs.dart';
import 'task_lists_screen.dart';
import 'task_source_picker.dart';
import 'tasks_strings.dart';
import 'trash_screen.dart';

part 'tasks_screen/tasks_screen_view.dart';
part 'tasks_screen/tasks_screen_methods.dart';
part 'tasks_screen/tasks_screen_enums.dart';
part 'tasks_screen/tasks_chrome.dart';
part 'tasks_screen/tasks_list.dart';
part 'tasks_screen/task_item.dart';
part 'tasks_screen/task_actions.dart';
part 'tasks_screen/custom_task_list.dart';
part 'tasks_screen/smart_list_chip.dart';

/// Search is a transient view state: closing it clears the query so the full
/// list comes back immediately.
final _taskSearchProvider =
    NotifierProvider.autoDispose<_TaskSearchNotifier, _TaskSearchState>(
      _TaskSearchNotifier.new,
    );

class _TaskSearchState {
  const _TaskSearchState({this.open = false, this.query = ''});

  final bool open;
  final String query;

  _TaskSearchState copyWith({bool? open, String? query}) =>
      _TaskSearchState(open: open ?? this.open, query: query ?? this.query);
}

class _TaskSearchNotifier extends Notifier<_TaskSearchState> {
  @override
  _TaskSearchState build() => const _TaskSearchState();

  void toggle() => state = state.open
      ? const _TaskSearchState()
      : const _TaskSearchState(open: true);

  void close() => state = const _TaskSearchState();

  void setQuery(String query) => state = state.copyWith(query: query);
}

/// Quick filter for the visible task source. Resets when the screen leaves the
/// tree so a tab revisit starts from All.
final _taskFilterProvider =
    NotifierProvider.autoDispose<_TaskFilterNotifier, _TaskFilter>(
      _TaskFilterNotifier.new,
    );

class _TaskFilterNotifier extends Notifier<_TaskFilter> {
  @override
  _TaskFilter build() => _TaskFilter.all;

  void select(_TaskFilter filter) => state = filter;
}
