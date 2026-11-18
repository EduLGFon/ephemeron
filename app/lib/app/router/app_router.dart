import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../shell/app_shell.dart';
import '../shell/destinations.dart';
import '../../features/alarms/application/alarm_providers.dart';
import '../../features/alarms/presentation/alarm_settings_screen.dart';
import '../../features/alarms/presentation/ring_screen.dart';
import '../../features/calendar/presentation/calendar_screen.dart';
import '../../features/countdowns/presentation/countdowns_screen.dart';
import '../../features/focus/presentation/focus_screen.dart';
import '../../features/habits/presentation/habits_screen.dart';
import '../../features/notes/presentation/notes_screen.dart';
import '../../features/search/presentation/search_screen.dart';
import '../../features/settings/application/settings_providers.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/stream/presentation/stream_route_params.dart';
import '../../features/stream/presentation/stream_screen.dart';
import '../../features/tasks/presentation/matrix_screen.dart';
import '../../features/tasks/presentation/tasks_screen.dart';
import '../../features/today/presentation/today_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  // A verified cold-start ring request must be the very first route; AppShell
  // (and its alarm action handler) is not built above /ring.
  final startAtRing = ref.read(activeRingRequestProvider) != null;

  Future<bool> streamEnabled() async {
    final loaded = ref.read(settingsRepositoryProvider).value;
    if (loaded != null) return loaded.streamEnabled;
    try {
      return (await ref.read(settingsRepositoryProvider.future)).streamEnabled;
    } catch (_) {
      return false;
    }
  }

  return GoRouter(
    initialLocation: startAtRing ? '/ring' : '/',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            initialLocation: AppDestination.today.path,
            routes: [
              GoRoute(
                path: AppDestination.today.path,
                builder: (context, state) => const TodayScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            initialLocation: AppDestination.tasks.path,
            routes: [
              GoRoute(
                path: AppDestination.tasks.path,
                builder: (context, state) => const TasksScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            initialLocation: AppDestination.calendar.path,
            routes: [
              GoRoute(
                path: AppDestination.calendar.path,
                builder: (context, state) => const CalendarScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            initialLocation: AppDestination.habits.path,
            routes: [
              GoRoute(
                path: AppDestination.habits.path,
                builder: (context, state) => const HabitsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            initialLocation: AppDestination.focus.path,
            routes: [
              GoRoute(
                path: AppDestination.focus.path,
                builder: (context, state) => const FocusScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            initialLocation: AppDestination.countdowns.path,
            routes: [
              GoRoute(
                path: AppDestination.countdowns.path,
                builder: (context, state) => const CountdownsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            initialLocation: AppDestination.notes.path,
            routes: [
              GoRoute(
                path: AppDestination.notes.path,
                builder: (context, state) => const NotesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            initialLocation: AppDestination.matrix.path,
            routes: [
              GoRoute(
                path: AppDestination.matrix.path,
                builder: (context, state) => const MatrixScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            // Stream is opt-in. A concrete initialLocation is required because
            // goBranch(8) cannot fill this route's date/zoom parameters, and
            // the branch must stay inside AppShell so restore, sync and alarm
            // window handling still run on a Stream cold start.
            initialLocation: AppDestination.streamLocation(),
            routes: [
              GoRoute(
                path: AppDestination.stream.path,
                builder: (context, state) => _StreamGate(
                  date: tryParseStreamDate(state.pathParameters['date']),
                  zoom: state.pathParameters['zoom'],
                ),
              ),
            ],
          ),
        ],
      ),
      GoRoute(path: '/ring', builder: (context, state) => const RingScreen()),
      GoRoute(
        path: '/search',
        builder: (context, state) => const SearchScreen(),
      ),
      GoRoute(
        path: '/alarm-settings',
        builder: (context, state) => const AlarmSettingsScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
    redirect: (context, state) async {
      // Canonicalize unsupported stream zoom levels (such as hour) to day and
      // lowercase valid ones, so the URL and the rendered level agree.
      final match = RegExp(r'^/stream/([^/]+)/([^/]+)/?$')
          .firstMatch(state.uri.path);
      if (match != null) {
        final zoom = normalizeStreamZoom(match.group(2));
        if (zoom != match.group(2)) {
          final query = state.uri.hasQuery ? '?${state.uri.query}' : '';
          return '/stream/${match.group(1)}/$zoom$query';
        }
      }
      final path = state.uri.path;
      if (path == '/') return AppDestination.today.path;
      // Legacy tab indices, in the old AppSection order:
      // 0 Calendar, 1 Tasks, 2 Matrix, 3 Habits, 4 Countdowns, 5 Focus,
      // 6 Notes, 7 Stream.
      final legacy = RegExp(r'^/tab([0-7])$').firstMatch(path);
      if (legacy != null) {
        final oldIndex = int.parse(legacy.group(1)!);
        final branch = AppDestination.legacyTabBranches[oldIndex];
        if (branch == AppDestination.stream.id && !await streamEnabled()) {
          return AppDestination.today.path;
        }
        return AppDestination.pathForBranch(branch);
      }
      // Widget taps deliver ephemeron://widget/... through the platform
      // intent; if one ever reaches the router as a path, open the calendar
      // instead of showing the error page.
      if (path == '/widget' || path.startsWith('/widget/')) {
        return AppDestination.calendar.path;
      }
      return null;
    },
    errorBuilder: (context, state) => const TodayScreen(),
  );
});

/// Renders the Stream only when the opt-in preference is on. While settings
/// load, Today is the safe surface; as soon as a disabled preference is known,
/// the route is replaced with /today so deep links never strand a user on a
/// hidden destination. A widget or ring request still wins because the gate
/// runs inside the shell after those handlers.
class _StreamGate extends ConsumerWidget {
  const _StreamGate({required this.date, required this.zoom});

  final DateTime? date;
  final String? zoom;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref
        .watch(settingsRepositoryProvider)
        .maybeWhen(data: (repo) => repo.streamEnabled, orElse: () => false);
    if (!enabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        final router = GoRouter.maybeOf(context);
        if (router != null && router.state.uri.path.startsWith('/stream')) {
          router.go(AppDestination.today.path);
        }
      });
      return const TodayScreen();
    }
    return StreamScreen(date: date, zoom: zoom);
  }
}
