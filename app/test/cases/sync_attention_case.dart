import 'package:ephemeron/features/settings/application/settings_providers.dart';
import 'package:ephemeron/features/settings/data/settings_repository.dart';
import 'package:ephemeron/features/settings/presentation/settings_screen.dart';
import 'package:ephemeron/features/sync/application/sync_providers.dart';
import 'package:ephemeron/features/sync/data/sync_engine.dart';
import 'package:ephemeron/features/sync/presentation/sync_reconnect_banner.dart';
import 'package:ephemeron/l10n/src/app_localizations.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _ErrorStatusNotifier extends SyncStatusNotifier {
  @override
  SyncStatus build() => SyncStatus.error;
}

class _ReconsentNotifier extends GoogleReconsentAccounts {
  _ReconsentNotifier(this._accounts);

  final List<String> _accounts;

  @override
  List<String> build() => _accounts;
}

class _ReconnectNeededNotifier extends GoogleReconnectNeededNotifier {
  _ReconnectNeededNotifier(this._value);

  final bool _value;

  @override
  bool? build() => _value;
}

class _UnknownReconnectNotifier extends GoogleReconnectNeededNotifier {
  @override
  bool? build() => null;
}

Widget _settingsApp({List overrides = const []}) {
  return ProviderScope(
    overrides: overrides.cast(),
    child: MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: const SettingsScreen(),
    ),
  );
}

Widget _bannerApp({List overrides = const []}) {
  return ProviderScope(
    overrides: overrides.cast(),
    child: const MaterialApp(home: Scaffold(body: SyncReconnectBanner())),
  );
}

Future<void> _scrollToLastSync(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.drag(find.byType(ListView), const Offset(0, -1200));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
}

void main() {
  test('google reconnect needed persists without account emails', () async {
    SharedPreferences.setMockInitialValues({});
    final repo = SettingsRepository(await SharedPreferences.getInstance());

    expect(repo.googleReconnectNeeded, isFalse);
    await repo.setGoogleReconnectNeeded(true);

    final prefs = await SharedPreferences.getInstance();
    expect(repo.googleReconnectNeeded, isTrue);
    expect(prefs.getBool('sync.googleReconnectNeeded'), isTrue);

    await repo.setGoogleReconnectNeeded(false);
    expect(repo.googleReconnectNeeded, isFalse);
  });

  test('syncIssueMessage maps every sync error kind', () {
    expect(
      syncIssueMessage(SyncErrorKind.auth),
      'Sync needs permission. Reconnect your Google account.',
    );
    expect(
      syncIssueMessage(SyncErrorKind.rateLimited),
      'Google is rate-limiting sync. Try again later.',
    );
    expect(
      syncIssueMessage(SyncErrorKind.network),
      'No connection. Changes are queued.',
    );
    expect(
      syncIssueMessage(SyncErrorKind.server),
      'Google returned an error. Try again later.',
    );
    expect(syncIssueMessage(SyncErrorKind.unknown), 'Sync failed. Try again.');
    expect(syncIssueMessage(SyncErrorKind.none), 'Sync failed. Try again.');
    expect(syncIssueMessage(null), 'Sync failed. Try again.');
  });

  testWidgets('reconnect banner is hidden with no issue', (tester) async {
    await tester.pumpWidget(
      _bannerApp(
        overrides: [
          googleReconsentAccountsProvider.overrideWith(
            () => _ReconsentNotifier(const []),
          ),
          googleReconnectNeededProvider.overrideWith(
            () => _ReconnectNeededNotifier(false),
          ),
        ],
      ),
    );
    await tester.pump();

    expect(find.byKey(SyncReconnectBanner.bannerKey), findsNothing);
    expect(find.text('Review accounts'), findsNothing);
  });

  testWidgets('reconnect banner lists every account needing consent', (
    tester,
  ) async {
    await tester.pumpWidget(
      _bannerApp(
        overrides: [
          googleReconsentAccountsProvider.overrideWith(
            () => _ReconsentNotifier(const [
              'alice@example.com',
              'bob@example.com',
            ]),
          ),
          googleReconnectNeededProvider.overrideWith(
            () => _ReconnectNeededNotifier(false),
          ),
        ],
      ),
    );
    await tester.pump();

    expect(find.byKey(SyncReconnectBanner.bannerKey), findsOneWidget);
    expect(find.textContaining('alice@example.com'), findsOneWidget);
    expect(find.textContaining('bob@example.com'), findsOneWidget);
    expect(find.text('Review accounts'), findsOneWidget);
  });

  testWidgets('reconnect banner seeds the persisted flag on the first frame', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'sync.googleReconnectNeeded': true,
    });
    final prefs = await SharedPreferences.getInstance();
    final repo = SettingsRepository(prefs);
    await tester.pumpWidget(
      _bannerApp(
        overrides: [
          settingsRepositoryProvider.overrideWith((ref) => repo),
          googleReconsentAccountsProvider.overrideWith(
            () => _ReconsentNotifier(const []),
          ),
        ],
      ),
    );

    expect(find.byKey(SyncReconnectBanner.bannerKey), findsOneWidget);
    expect(find.textContaining('needs permission'), findsOneWidget);
    expect(find.textContaining('@'), findsNothing);
  });

  testWidgets('reconnect banner treats an unloaded flag as unknown', (
    tester,
  ) async {
    await tester.pumpWidget(
      _bannerApp(
        overrides: [
          googleReconsentAccountsProvider.overrideWith(
            () => _ReconsentNotifier(const []),
          ),
          googleReconnectNeededProvider.overrideWith(
            _UnknownReconnectNotifier.new,
          ),
        ],
      ),
    );
    await tester.pump();

    expect(find.byKey(SyncReconnectBanner.bannerKey), findsNothing);
  });

  testWidgets('reconnect banner shows generic text for persisted flag only', (
    tester,
  ) async {
    await tester.pumpWidget(
      _bannerApp(
        overrides: [
          googleReconsentAccountsProvider.overrideWith(
            () => _ReconsentNotifier(const []),
          ),
          googleReconnectNeededProvider.overrideWith(
            () => _ReconnectNeededNotifier(true),
          ),
        ],
      ),
    );
    await tester.pump();

    expect(find.byKey(SyncReconnectBanner.bannerKey), findsOneWidget);
    expect(find.textContaining('needs permission'), findsOneWidget);
    expect(find.textContaining('@example.com'), findsNothing);
    expect(find.text('Review accounts'), findsOneWidget);
  });

  testWidgets('last sync tile shows error and last success timestamp', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(500, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const ms = 1700000000000;
    SharedPreferences.setMockInitialValues({'sync.lastGoogleSyncAtMs': ms});
    await tester.pumpWidget(
      _settingsApp(
        overrides: [syncStatusProvider.overrideWith(_ErrorStatusNotifier.new)],
      ),
    );
    await _scrollToLastSync(tester);

    expect(find.textContaining('Error - last success'), findsOneWidget);
  });

  testWidgets('last sync tile says has not synced yet on error without time', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(500, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      _settingsApp(
        overrides: [syncStatusProvider.overrideWith(_ErrorStatusNotifier.new)],
      ),
    );
    await _scrollToLastSync(tester);

    expect(find.textContaining('Error - has not synced yet'), findsOneWidget);
  });
}
