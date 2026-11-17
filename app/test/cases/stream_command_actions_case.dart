import 'package:ephemeron/features/stream/application/stream_command_actions.dart';
import 'package:ephemeron/features/stream/application/stream_theme_provider.dart';
import 'package:ephemeron/features/stream/design/stream_theme_mode.dart';
import 'package:ephemeron/features/stream/presentation/commands/command_parser.dart';
import 'package:ephemeron/features/sync/application/sync_providers.dart';
import 'package:ephemeron/features/sync/data/sync_engine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeThemeNotifier extends StreamThemeNotifier {
  int setModeCalls = 0;
  StreamThemeMode? lastMode;
  bool throwOnSetMode = false;

  @override
  StreamThemeMode build() => StreamThemeMode.system;

  @override
  Future<void> setMode(StreamThemeMode mode) async {
    setModeCalls++;
    lastMode = mode;
    if (throwOnSetMode) throw StateError('theme failure');
  }
}

class _FakeSyncNotifier extends SyncStatusNotifier {
  int syncCalls = 0;
  bool throwOnSync = false;

  @override
  SyncStatus build() => SyncStatus.synced;

  @override
  Future<void> syncNow() async {
    syncCalls++;
    if (throwOnSync) throw StateError('sync failure');
  }
}

void main() {
  final now = DateTime(2026, 11, 16);

  StreamCommandIntent map(String input) =>
      mapStreamCommand(parseCommand(input, now: now));

  test('maps goToDate', () {
    expect(
      map('go to 2026-12-01'),
      isA<StreamCommandGoToDate>().having(
        (i) => i.date,
        'date',
        DateTime(2026, 12, 1),
      ),
    );
  });

  test('maps zoom day/week/month', () {
    for (final level in ['day', 'week', 'month']) {
      expect(
        map('zoom $level'),
        isA<StreamCommandZoom>().having((i) => i.level, 'level', level),
      );
    }
  });

  test('maps agenda, settings, help, syncNow, search', () {
    expect(map('agenda'), isA<StreamCommandAgenda>());
    expect(map('settings'), isA<StreamCommandSettings>());
    expect(map('help'), isA<StreamCommandHelp>());
    expect(map('sync now'), isA<StreamCommandSyncNow>());
    expect(map('search notes'), isA<StreamCommandSearch>());
  });

  test('maps every theme mode', () {
    const expected = {
      'light': StreamThemeMode.light,
      'dark': StreamThemeMode.dark,
      'trueblack': StreamThemeMode.trueBlack,
      'system': StreamThemeMode.system,
    };
    for (final entry in expected.entries) {
      expect(
        map('theme ${entry.key}'),
        isA<StreamCommandTheme>().having((i) => i.mode, 'mode', entry.value),
      );
    }
  });

  test('none and unknown are unsupported', () {
    expect(map(''), isA<StreamCommandUnsupported>());
    expect(map('nonsense'), isA<StreamCommandUnsupported>());
  });

  test('complete and focus are unsupported with reasons', () {
    final complete = map('complete Buy milk');
    expect(complete, isA<StreamCommandUnsupported>());
    if (complete case StreamCommandUnsupported(:final reason)) {
      expect(reason, contains('completion'));
    }
    final focus = map('focus 25');
    expect(focus, isA<StreamCommandUnsupported>());
    if (focus case StreamCommandUnsupported(:final reason)) {
      expect(reason, contains('focus'));
    }
  });

  test('invalid zoom is unsupported', () {
    for (final level in ['hour', 'year']) {
      final intent = map('zoom $level');
      expect(intent, isA<StreamCommandUnsupported>());
      if (intent case StreamCommandUnsupported(:final reason)) {
        expect(reason, contains(level));
      }
    }
  });

  group('StreamCommandExecutor', () {
    late _FakeThemeNotifier theme;
    late _FakeSyncNotifier sync;
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer(
        overrides: [
          streamThemeProvider.overrideWith(() {
            theme = _FakeThemeNotifier();
            return theme;
          }),
          syncStatusProvider.overrideWith(() {
            sync = _FakeSyncNotifier();
            return sync;
          }),
        ],
      );
      addTearDown(container.dispose);
    });

    StreamCommandExecutor executor() =>
        container.read(streamCommandExecutorProvider);

    test('theme calls setMode with the exact mode', () async {
      final exec = executor();
      for (final mode in StreamThemeMode.values) {
        expect(
          await exec.execute(StreamCommandTheme(mode)),
          isA<StreamCommandHandled>(),
        );
        expect(theme.lastMode, mode);
      }
      expect(theme.setModeCalls, StreamThemeMode.values.length);
    });

    test('syncNow calls the sync notifier once', () async {
      final result = await executor().execute(const StreamCommandSyncNow());
      expect(result, isA<StreamCommandHandled>());
      expect(sync.syncCalls, 1);
    });

    test('navigation intents return without side effects', () async {
      final exec = executor();
      container.read(streamThemeProvider.notifier);
      container.read(syncStatusProvider.notifier);
      final intents = <StreamCommandIntent>[
        StreamCommandGoToDate(DateTime(2026, 12, 1)),
        const StreamCommandZoom('week'),
        const StreamCommandAgenda(),
        const StreamCommandSettings(),
        const StreamCommandSearch(),
        const StreamCommandHelp(),
      ];
      for (final intent in intents) {
        expect(
          await exec.execute(intent),
          isA<StreamCommandNavigate>().having(
            (r) => r.intent,
            'intent',
            same(intent),
          ),
        );
      }
      expect(theme.setModeCalls, 0);
      expect(sync.syncCalls, 0);
    });

    test('side-effect errors map to a typed failure', () async {
      final exec = executor();
      container.read(streamThemeProvider.notifier);
      theme.throwOnSetMode = true;
      expect(
        await exec.execute(const StreamCommandTheme(StreamThemeMode.dark)),
        isA<StreamCommandFailed>(),
      );
      container.read(syncStatusProvider.notifier);
      sync.throwOnSync = true;
      expect(
        await exec.execute(const StreamCommandSyncNow()),
        isA<StreamCommandFailed>(),
      );
    });
  });
}
