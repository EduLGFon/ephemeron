import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../shell/app_shell.dart';
import '../../features/calendar/presentation/calendar_screen.dart';
import '../../features/countdowns/presentation/countdowns_screen.dart';
import '../../features/focus/presentation/focus_screen.dart';
import '../../features/habits/presentation/habits_screen.dart';
import '../../features/tasks/presentation/matrix_screen.dart';
import '../../features/tasks/presentation/tasks_screen.dart';
import '../../features/alarms/application/alarm_providers.dart';
import '../../features/alarms/presentation/alarm_settings_screen.dart';
import '../../features/alarms/presentation/ring_screen.dart';
import '../../features/notes/presentation/notes_screen.dart';
import '../../features/search/presentation/search_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/stream/presentation/stream_screen.dart';
import '../../features/stream/presentation/stream_route_params.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  // A verified cold-start ring request must be the very first route; AppShell
  // (and its alarm action handler) is not built above /ring.
  final startAtRing = ref.read(activeRingRequestProvider) != null;
  return GoRouter(
    initialLocation: startAtRing ? '/ring' : '/',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/tab0',
                builder: (context, state) => const CalendarScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/tab1',
                builder: (context, state) => const TasksScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/tab2',
                builder: (context, state) => const MatrixScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/tab3',
                builder: (context, state) => const HabitsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/tab4',
                builder: (context, state) => const CountdownsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/tab5',
                builder: (context, state) => const FocusScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/tab6',
                builder: (context, state) => const NotesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            // Stream is the 8th branch (index 7); the legacy tabs keep
            // indices 0..6. A concrete initialLocation is required because
            // goBranch(7) cannot fill this route's date/zoom parameters, and
            // the branch must stay inside AppShell so restore, sync and
            // alarm window handling still run on a Stream cold start.
            initialLocation: '/stream/${formatStreamDate(DateTime.now())}/day',
            routes: [
              GoRoute(
                path: '/stream/:date/:zoom',
                builder: (context, state) => StreamScreen(
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
    redirect: (context, state) {
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
      // The root opens today's Stream day view. Stream lives inside
      // AppShell, so this cold start still restores the session, syncs and
      // rebuilds the alarm window.
      if (state.uri.path == '/') {
        return '/stream/${formatStreamDate(DateTime.now())}/day';
      }
      // Widget taps deliver ephemeron://widget/... through the platform
      // intent; if one ever reaches the router as a path, open the
      // calendar instead of showing the error page.
      if (state.uri.path == '/widget' ||
          state.uri.path.startsWith('/widget/')) {
        return '/tab0';
      }
      return null;
    },
    errorBuilder: (context, state) => const CalendarScreen(),
  );
});
