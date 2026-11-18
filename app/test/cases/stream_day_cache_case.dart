import 'dart:async';

import 'package:ephemeron/features/calendar/application/calendar_providers.dart';
import 'package:ephemeron/features/calendar/application/calendar_state.dart';
import 'package:ephemeron/features/stream/application/stream_day_cache.dart';
import 'package:ephemeron/features/stream/application/stream_day_cache_scope.dart';
import 'package:ephemeron/features/stream/application/stream_day_providers.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeGateway implements StreamDayCacheGateway {
  final List<CalendarRange> calls = <CalendarRange>[];
  Object? error;
  Completer<void>? gate;

  @override
  Future<void> rebuild(CalendarRange range) async {
    calls.add(range);
    if (error != null) throw error!;
    final pending = gate;
    if (pending != null) await pending.future;
  }
}

class _FixedBuiltRange extends CalendarBuiltRange {
  _FixedBuiltRange(this._range);

  final CalendarRange? _range;

  @override
  CalendarRange? build() => _range;
}

class _FixedBuilding extends CalendarCacheBuilding {
  _FixedBuilding(this._value);

  final bool _value;

  @override
  bool build() => _value;
}

class _RecordingController extends StreamDayCacheController {
  int ensureCalls = 0;

  @override
  Future<void> ensure(CalendarRange requested) {
    ensureCalls++;
    return super.ensure(requested);
  }
}

CalendarRange _range(DateTime from, DateTime to) =>
    CalendarRange(fromUtc: from, toUtc: to);

ProviderContainer _container({
  required StreamDayCacheGateway gateway,
  CalendarRange? built,
  bool building = false,
}) {
  return ProviderContainer(
    overrides: [
      streamDayCacheGatewayProvider.overrideWithValue(gateway),
      calendarBuiltRangeProvider.overrideWith(() => _FixedBuiltRange(built)),
      calendarCacheBuildingProvider.overrideWith(
        () => _FixedBuilding(building),
      ),
    ],
  );
}

void main() {
  final requested = _range(
    DateTime.utc(2026, 11, 16),
    DateTime.utc(2026, 11, 19),
  );

  group('needsStreamDayCacheRebuild', () {
    test('uncovered range needs a rebuild', () {
      expect(
        needsStreamDayCacheRebuild(
          built: _range(DateTime.utc(2026, 11, 1), DateTime.utc(2026, 11, 10)),
          requested: requested,
          building: false,
        ),
        isTrue,
      );
    });

    test('missing built range needs a rebuild', () {
      expect(
        needsStreamDayCacheRebuild(
          built: null,
          requested: requested,
          building: false,
        ),
        isTrue,
      );
    });

    test('covered range does not need a rebuild', () {
      expect(
        needsStreamDayCacheRebuild(
          built: _range(DateTime.utc(2026, 11, 1), DateTime.utc(2026, 12, 1)),
          requested: requested,
          building: false,
        ),
        isFalse,
      );
    });

    test('a build in progress always wins', () {
      expect(
        needsStreamDayCacheRebuild(
          built: null,
          requested: requested,
          building: true,
        ),
        isFalse,
      );
    });

    test('abutting ranges still need a rebuild', () {
      expect(
        needsStreamDayCacheRebuild(
          built: _range(DateTime.utc(2026, 11, 10), requested.fromUtc),
          requested: requested,
          building: false,
        ),
        isTrue,
      );
      expect(
        needsStreamDayCacheRebuild(
          built: _range(requested.toUtc, DateTime.utc(2026, 11, 25)),
          requested: requested,
          building: false,
        ),
        isTrue,
      );
    });

    test('partial overlap needs a rebuild', () {
      expect(
        needsStreamDayCacheRebuild(
          built: _range(DateTime.utc(2026, 11, 1), DateTime.utc(2026, 11, 17)),
          requested: requested,
          building: false,
        ),
        isTrue,
      );
    });
  });

  group('StreamDayCacheController', () {
    test('uncovered range rebuilds once', () async {
      final gateway = _FakeGateway();
      final container = _container(gateway: gateway, built: null);
      addTearDown(container.dispose);

      await container
          .read(streamDayCacheControllerProvider.notifier)
          .ensure(requested);

      expect(gateway.calls, [requested]);
      expect(
        container.read(streamDayCacheControllerProvider),
        StreamDayCacheStatus.ready,
      );
    });

    test('covered range does not rebuild', () async {
      final gateway = _FakeGateway();
      final container = _container(
        gateway: gateway,
        built: _range(DateTime.utc(2026, 11, 1), DateTime.utc(2026, 12, 1)),
      );
      addTearDown(container.dispose);

      await container
          .read(streamDayCacheControllerProvider.notifier)
          .ensure(requested);

      expect(gateway.calls, isEmpty);
    });

    test('a build in progress does not rebuild', () async {
      final gateway = _FakeGateway();
      final container = _container(
        gateway: gateway,
        built: null,
        building: true,
      );
      addTearDown(container.dispose);

      await container
          .read(streamDayCacheControllerProvider.notifier)
          .ensure(requested);

      expect(gateway.calls, isEmpty);
    });

    test('concurrent ensure calls rebuild once', () async {
      final gateway = _FakeGateway()..gate = Completer<void>();
      final container = _container(gateway: gateway, built: null);
      addTearDown(container.dispose);
      final controller = container.read(
        streamDayCacheControllerProvider.notifier,
      );

      final first = controller.ensure(requested);
      final second = controller.ensure(requested);
      expect(gateway.calls, [requested]);
      gateway.gate!.complete();
      await Future.wait([first, second]);

      expect(gateway.calls, [requested]);
    });

    test('a new range after completion rebuilds again', () async {
      final gateway = _FakeGateway();
      final container = _container(gateway: gateway, built: null);
      addTearDown(container.dispose);
      final controller = container.read(
        streamDayCacheControllerProvider.notifier,
      );
      final next = _range(DateTime.utc(2026, 12, 1), DateTime.utc(2026, 12, 4));

      await controller.ensure(requested);
      await controller.ensure(next);

      expect(gateway.calls, [requested, next]);
    });

    test('a throwing gateway sets error and does not throw', () async {
      final gateway = _FakeGateway()..error = StateError('rebuild failed');
      final container = _container(gateway: gateway, built: null);
      addTearDown(container.dispose);
      final controller = container.read(
        streamDayCacheControllerProvider.notifier,
      );

      await expectLater(controller.ensure(requested), completes);

      expect(
        container.read(streamDayCacheControllerProvider),
        StreamDayCacheStatus.error,
      );
      expect(controller.lastError, isA<StateError>());
    });
  });

  group('StreamDayCacheScope', () {
    testWidgets('ensures once per day and not on unrelated rebuilds', (
      tester,
    ) async {
      final recording = _RecordingController();
      final gateway = _FakeGateway();
      var day = StreamDayKey(year: 2099, month: 1, day: 15);
      late StateSetter setHostState;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            streamDayCacheGatewayProvider.overrideWithValue(gateway),
            calendarBuiltRangeProvider.overrideWith(
              () => _FixedBuiltRange(null),
            ),
            streamDayCacheControllerProvider.overrideWith(() => recording),
          ],
          child: StatefulBuilder(
            builder: (context, setState) {
              setHostState = setState;
              return StreamDayCacheScope(day: day, child: const SizedBox());
            },
          ),
        ),
      );
      await tester.pump();
      expect(recording.ensureCalls, 1);

      setHostState(() {});
      await tester.pump();
      expect(recording.ensureCalls, 1);

      day = StreamDayKey(year: 2099, month: 1, day: 16);
      setHostState(() {});
      await tester.pump();
      expect(recording.ensureCalls, 2);
    });
  });
}
