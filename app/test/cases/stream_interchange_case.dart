// Old UI <-> Stream interchangeability (widget proof).
import 'package:drift/native.dart';
import 'package:ephemeron/app/router/app_router.dart';
import 'package:ephemeron/core/db/db_provider.dart';
import 'package:ephemeron/data/drift/app_database.dart';
import 'package:ephemeron/features/stream/presentation/stream_screen.dart';
import 'package:ephemeron/l10n/src/app_localizations.dart';
import 'package:flutter/services.dart' show MethodChannel;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

const Map<String, Object> _basePrefs = <String, Object>{
  'settings.onboarded': true,
  'stream.school.completed': true,
};

Map<String, Object> _prefs({Object? lastTab}) => <String, Object>{
  ..._basePrefs,
  'session.lastTab': ?lastTab,
};

void _setPhoneView(WidgetTester tester) {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void _mockPlatformChannels() {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  for (final name in const ['ephemeron/system', 'ephemeron/alarms']) {
    messenger.setMockMethodCallHandler(
      MethodChannel(name),
      (call) async => null,
    );
  }
}

class _Harness {
  _Harness(this.router, this.db);

  final GoRouter router;
  final AppDatabase db;
}

Future<_Harness> _pumpApp(
  WidgetTester tester,
  Map<String, Object> prefs,
) async {
  _mockPlatformChannels();
  SharedPreferences.setMockInitialValues(prefs);
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  GoRouter? router;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
      child: Consumer(
        builder: (context, ref, _) {
          final r = ref.watch(appRouterProvider);
          router = r;
          return MaterialApp.router(
            routerConfig: r,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              ...GlobalMaterialLocalizations.delegates,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
          );
        },
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 500));
  return _Harness(router!, db);
}

/// Unmounts the tree while pumps still run so Riverpod disposes its drift
/// stream subscriptions before the database closes.
Future<void> _unmount(WidgetTester tester, AppDatabase db) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await db.close();
  await tester.pump();
}

String _location(GoRouter router) =>
    router.routerDelegate.currentConfiguration.last.matchedLocation;

void main() {
  testWidgets('interchange round trip tabs->stream->tab + persisted lastTab', (
    tester,
  ) async {
    _setPhoneView(tester);
    final app = await _pumpApp(tester, _prefs(lastTab: 1));
    final router = app.router;
    try {
      expect(_location(router), '/tab1');

      await tester.tap(find.byIcon(Icons.more_horiz));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.byKey(const ValueKey('more-stream')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(StreamScreen), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('session.lastTab'), 7);

      await tester.tap(find.byIcon(Icons.checklist_outlined));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(_location(router), '/tab1');
      expect(prefs.getInt('session.lastTab'), 1);
    } finally {
      await _unmount(tester, app.db);
    }
  });

  testWidgets('cold start with lastTab=1 restores tab (old UI reachable)', (
    tester,
  ) async {
    _setPhoneView(tester);
    final app = await _pumpApp(tester, _prefs(lastTab: 1));
    final router = app.router;
    try {
      expect(_location(router), '/tab1');
    } finally {
      await _unmount(tester, app.db);
    }
  });
}
