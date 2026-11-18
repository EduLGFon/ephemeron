// Single source of truth for Ephemeron's shell destinations. Branch indices
// are stable: they are persisted in `session.lastTab` and used by
// StatefulShellRoute.indexedStack. Primary destinations use ids 0..4 and are
// reorderable through `settings.navOrderV2`; secondary destinations live in
// More/sidebar only.
import 'package:material_ui/material_ui.dart';

import '../../features/stream/presentation/stream_route_params.dart';

@immutable
class AppDestination {
  const AppDestination({
    required this.id,
    required this.title,
    required this.icon,
    required this.path,
    required this.primary,
  });

  /// Branch index and stable destination id (0..8).
  final int id;
  final String title;
  final IconData icon;

  /// Router path. Stream carries its parameters; use [streamLocation] for a
  /// concrete navigation target.
  final String path;

  /// Primary destinations appear in the adaptive navigation; secondary ones
  /// only in More and the expanded sidebar.
  final bool primary;

  int get branch => id;

  static const AppDestination today = AppDestination(
    id: 0,
    title: 'Today',
    icon: Icons.today_outlined,
    path: '/today',
    primary: true,
  );
  static const AppDestination tasks = AppDestination(
    id: 1,
    title: 'Tasks',
    icon: Icons.checklist_outlined,
    path: '/tasks',
    primary: true,
  );
  static const AppDestination calendar = AppDestination(
    id: 2,
    title: 'Calendar',
    icon: Icons.calendar_month_outlined,
    path: '/calendar',
    primary: true,
  );
  static const AppDestination habits = AppDestination(
    id: 3,
    title: 'Habits',
    icon: Icons.repeat_outlined,
    path: '/habits',
    primary: true,
  );
  static const AppDestination focus = AppDestination(
    id: 4,
    title: 'Focus',
    icon: Icons.timer_outlined,
    path: '/focus',
    primary: true,
  );
  static const AppDestination countdowns = AppDestination(
    id: 5,
    title: 'Countdowns',
    icon: Icons.hourglass_bottom_outlined,
    path: '/countdowns',
    primary: false,
  );
  static const AppDestination notes = AppDestination(
    id: 6,
    title: 'Notes',
    icon: Icons.note_outlined,
    path: '/notes',
    primary: false,
  );
  static const AppDestination matrix = AppDestination(
    id: 7,
    title: 'Matrix',
    icon: Icons.grid_view_outlined,
    path: '/matrix',
    primary: false,
  );
  static const AppDestination stream = AppDestination(
    id: 8,
    title: 'Stream',
    icon: Icons.stream_outlined,
    path: '/stream/:date/:zoom',
    primary: false,
  );

  static const List<AppDestination> all = <AppDestination>[
    today,
    tasks,
    calendar,
    habits,
    focus,
    countdowns,
    notes,
    matrix,
    stream,
  ];

  static const List<int> primaryIds = <int>[0, 1, 2, 3, 4];
  static const List<int> secondaryIds = <int>[5, 6, 7];

  /// Legacy `/tabN` order mapped to the new branch indices:
  /// 0 Calendar, 1 Tasks, 2 Matrix, 3 Habits, 4 Countdowns, 5 Focus,
  /// 6 Notes, 7 Stream.
  static const List<int> legacyTabBranches = <int>[2, 1, 7, 3, 5, 4, 6, 8];

  static AppDestination byId(int id) {
    for (final destination in all) {
      if (destination.id == id) return destination;
    }
    return today;
  }

  /// Concrete Stream URL for [day]. The Stream branch needs a real path
  /// because `goBranch` cannot fill date/zoom parameters.
  static String streamLocation([DateTime? day]) =>
      '/stream/${formatStreamDate(day ?? DateTime.now())}/day';

  /// Branch path used when persisting `session.lastRoute`.
  static String pathForBranch(int branch) {
    final destination = byId(branch);
    if (destination.id == stream.id) return streamLocation();
    return destination.path;
  }
}
