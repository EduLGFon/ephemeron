import 'package:ephemeron/features/sync/application/sync_providers.dart';
import 'package:ephemeron/features/sync/data/sync_engine.dart';
import 'package:ephemeron/features/sync/presentation/sync_title.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeSyncStatusNotifier extends SyncStatusNotifier {
  _FakeSyncStatusNotifier(this._status);
  final SyncStatus _status;

  @override
  SyncStatus build() => _status;
}

void main() {
  testWidgets('shows spinner only while syncing', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          syncStatusProvider.overrideWith(
            () => _FakeSyncStatusNotifier(SyncStatus.syncing),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: SyncTitle(text: 'Calendar')),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Calendar'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpWidget(Container());
    await tester.pump();
  });

  testWidgets('hides spinner when not syncing', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          syncStatusProvider.overrideWith(
            () => _FakeSyncStatusNotifier(SyncStatus.synced),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: SyncTitle(text: 'Calendar')),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Calendar'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.pumpWidget(Container());
    await tester.pump();
  });
}
