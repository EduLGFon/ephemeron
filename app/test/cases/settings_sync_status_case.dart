import 'package:ephemeron/core/time/device_date_format.dart';
import 'package:ephemeron/features/settings/presentation/settings_screen.dart';
import 'package:ephemeron/features/sync/application/sync_providers.dart';
import 'package:ephemeron/features/sync/data/sync_engine.dart';
import 'package:ephemeron/l10n/src/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _SyncingStatusNotifier extends SyncStatusNotifier {
  @override
  SyncStatus build() => SyncStatus.syncing;
}

Widget _settingsApp({List overrides = const []}) {
  return ProviderScope(
    overrides: overrides.cast(),
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const SettingsScreen(),
    ),
  );
}

void main() {
  testWidgets('last sync row shows persisted timestamp and status', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(500, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const ms = 1700000000000;
    SharedPreferences.setMockInitialValues({'sync.lastGoogleSyncAtMs': ms});
    await tester.pumpWidget(_settingsApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.drag(find.byType(ListView), const Offset(0, -1200));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.textContaining('Synced'), findsWidgets);

    final date = DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toLocal();
    final context = tester.element(find.byType(SettingsScreen));
    final formatted = DeviceDateFormat.dateTime(context, date);
    expect(find.textContaining(formatted), findsOneWidget);
  });

  testWidgets('last sync row shows progress while syncing', (tester) async {
    tester.view.physicalSize = const Size(500, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      _settingsApp(
        overrides: [
          syncStatusProvider.overrideWith(_SyncingStatusNotifier.new),
        ],
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.drag(find.byType(ListView), const Offset(0, -1200));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.textContaining('Syncing'), findsWidgets);
  });

  testWidgets('last sync row shows not synced yet when no timestamp', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(500, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(_settingsApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.drag(find.byType(ListView), const Offset(0, -1200));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.textContaining('Not synced yet'), findsOneWidget);
    expect(find.textContaining('Synced'), findsNothing);
  });
}
