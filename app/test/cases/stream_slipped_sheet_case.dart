import 'package:ephemeron/features/stream/application/stream_slipped_data.dart';
import 'package:ephemeron/features/stream/presentation/slipped/slipped_item.dart';
import 'package:ephemeron/features/stream/presentation/surface/stream_slipped_sheet.dart';
import 'package:ephemeron/l10n/src/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../support/test_fixtures.dart';

const _oneItem = [
  SlippedItem(
    id: 'x',
    title: 'Slip',
    daysOverdue: 2,
    listColorArgb: 0xFF336699,
  ),
];

const _twoItems = [
  SlippedItem(
    id: 'a',
    title: 'First slipped',
    daysOverdue: 1,
    listColorArgb: 0xFF336699,
  ),
  SlippedItem(
    id: 'b',
    title: 'Second slipped',
    daysOverdue: 4,
    listColorArgb: 0xFF336699,
  ),
];

void main() {
  testWidgets('renders items with titles and localized days overdue', (
    tester,
  ) async {
    final l = await _en();
    await tester.pumpWidget(_app(items: _twoItems));
    await settle(tester);

    expect(find.text('First slipped'), findsOneWidget);
    expect(find.text('Second slipped'), findsOneWidget);
    expect(find.text(l.streamSlippedDaysOverdue(1)), findsOneWidget);
    expect(find.text(l.streamSlippedDaysOverdue(4)), findsOneWidget);
    expect(find.text(l.streamSlippedEmpty), findsNothing);
  });

  testWidgets('empty state shows the localized empty label and close', (
    tester,
  ) async {
    final l = await _en();
    await tester.pumpWidget(_app());
    await settle(tester);

    expect(find.text(l.streamSlippedEmpty), findsOneWidget);
    expect(find.byKey(const Key('streamSlippedClose')), findsOneWidget);
  });

  testWidgets('done runs the action and its undo', (tester) async {
    final l = await _en();
    final actions = _FakeSlippedActions();
    await tester.pumpWidget(_app(items: _oneItem, actions: actions));
    await settle(tester);

    await tester.tap(find.byTooltip(l.streamSlippedDone));
    await _settleAction(tester);

    expect(actions.doneIds, ['x']);
    expect(find.text(l.streamSlippedDoneMessage), findsOneWidget);
    expect(find.text(l.streamSlippedTomorrowMessage), findsNothing);

    await tester.tap(find.text('Undo'));
    await tester.pump();
    expect(actions.undoCalls, 1);
  });

  testWidgets('tomorrow runs the action and its undo', (tester) async {
    final l = await _en();
    final actions = _FakeSlippedActions();
    await tester.pumpWidget(_app(items: _oneItem, actions: actions));
    await settle(tester);

    await tester.tap(find.byTooltip(l.streamSlippedTomorrow));
    await _settleAction(tester);

    expect(actions.tomorrowIds, ['x']);
    expect(find.text(l.streamSlippedTomorrowMessage), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pump();
    expect(actions.undoCalls, 1);
  });

  testWidgets('drop runs the action and its undo', (tester) async {
    final l = await _en();
    final actions = _FakeSlippedActions();
    await tester.pumpWidget(_app(items: _oneItem, actions: actions));
    await settle(tester);

    await tester.tap(find.byTooltip(l.streamSlippedDrop));
    await _settleAction(tester);

    expect(actions.dropIds, ['x']);
    expect(find.text(l.streamSlippedDropMessage), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pump();
    expect(actions.undoCalls, 1);
  });

  testWidgets('pick time passes the chosen time and offers undo', (
    tester,
  ) async {
    final l = await _en();
    final actions = _FakeSlippedActions();
    final picked = DateTime(2026, 11, 18, 14, 30);
    await tester.pumpWidget(
      _app(
        items: _oneItem,
        actions: actions,
        picker: (context, id) async => picked,
      ),
    );
    await settle(tester);

    await tester.tap(find.byTooltip(l.streamSlippedPickTime));
    await _settleAction(tester);

    expect(actions.pickTimeIds, ['x']);
    expect(actions.pickTimeStarts, [picked]);
    expect(find.text(l.streamSlippedPickTimeMessage), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pump();
    expect(actions.undoCalls, 1);
  });

  testWidgets('canceling the time picker does not run the action', (
    tester,
  ) async {
    final l = await _en();
    final actions = _FakeSlippedActions();
    await tester.pumpWidget(
      _app(
        items: _oneItem,
        actions: actions,
        picker: (context, id) async => null,
      ),
    );
    await settle(tester);

    await tester.tap(find.byTooltip(l.streamSlippedPickTime));
    await _settleAction(tester);

    expect(actions.pickTimeIds, isEmpty);
    expect(find.text(l.streamSlippedPickTimeMessage), findsNothing);
    expect(find.text(l.streamSlippedActionError), findsNothing);
  });

  testWidgets('action failure shows the localized error', (tester) async {
    final l = await _en();
    final actions = _FakeSlippedActions()
      ..failure = const StreamSlippedException.repository(cause: 'boom');
    await tester.pumpWidget(_app(items: _oneItem, actions: actions));
    await settle(tester);

    await tester.tap(find.byTooltip(l.streamSlippedDone));
    await _settleAction(tester);

    expect(find.text(l.streamSlippedActionError), findsOneWidget);
    expect(find.text(l.streamSlippedDoneMessage), findsNothing);
    expect(find.text('Undo'), findsNothing);
  });

  testWidgets('sheet chrome does not overflow at 320dp and 2.0 scale', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final l = await _en();

    await tester.pumpWidget(
      _app(media: (mq) => mq.copyWith(textScaler: const TextScaler.linear(2))),
    );
    await settle(tester);

    expect(find.text(l.streamSlippedTitle), findsOneWidget);
    expect(find.text(l.streamSlippedEmpty), findsOneWidget);
    expect(find.byKey(const Key('streamSlippedClose')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<AppLocalizations> _en() =>
    AppLocalizations.delegate.load(const Locale('en'));

Future<void> _settleAction(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

Widget _app({
  _FakeSlippedActions? actions,
  List<SlippedItem> items = const [],
  StreamSlippedTimePicker? picker,
  MediaQueryData Function(MediaQueryData)? media,
}) {
  return ProviderScope(
    overrides: [
      streamSlippedItemsProvider.overrideWith((_) => Stream.value(items)),
      streamSlippedActionsProvider.overrideWithValue(
        actions ?? _FakeSlippedActions(),
      ),
    ],
    child: MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) {
          final mq = MediaQuery.of(context);
          return Scaffold(
            body: MediaQuery(
              data: media?.call(mq) ?? mq,
              child: StreamSlippedSheet(onClose: () {}, timePicker: picker),
            ),
          );
        },
      ),
    ),
  );
}

class _FakeSlippedActions extends StreamSlippedActions {
  _FakeSlippedActions() : super(_UnusedGateway());

  final List<String> doneIds = [];
  final List<String> tomorrowIds = [];
  final List<String> pickTimeIds = [];
  final List<DateTime> pickTimeStarts = [];
  final List<String> dropIds = [];
  int undoCalls = 0;
  Object? failure;

  StreamSlippedResult _ok(String id) => StreamSlippedResult(
    taskId: id,
    undo: () async {
      undoCalls++;
    },
  );

  @override
  Future<StreamSlippedResult> done(String id) async {
    if (failure != null) throw failure!;
    doneIds.add(id);
    return _ok(id);
  }

  @override
  Future<StreamSlippedResult> tomorrow(String id) async {
    if (failure != null) throw failure!;
    tomorrowIds.add(id);
    return _ok(id);
  }

  @override
  Future<StreamSlippedResult> pickTime(
    String id,
    DateTime start, {
    Duration duration = const Duration(minutes: 30),
  }) async {
    if (failure != null) throw failure!;
    pickTimeIds.add(id);
    pickTimeStarts.add(start);
    return _ok(id);
  }

  @override
  Future<StreamSlippedResult> drop(String id) async {
    if (failure != null) throw failure!;
    dropIds.add(id);
    return _ok(id);
  }
}

class _UnusedGateway implements StreamSlippedGateway {
  @override
  Future<StreamSlippedTask?> taskById(String id) => throw UnimplementedError();

  @override
  Future<void> completeTask(String id) => throw UnimplementedError();

  @override
  Future<void> uncompleteTask(String id) => throw UnimplementedError();

  @override
  Future<void> updateTask(
    String id, {
    required String? dueDate,
    required String? plannedDate,
    required String? plannedStart,
    required String? plannedEnd,
  }) => throw UnimplementedError();

  @override
  Future<void> softDeleteTask(String id) => throw UnimplementedError();

  @override
  Future<void> restoreTask(String id) => throw UnimplementedError();

  @override
  Future<void> rebuildDay(DateTime localDay) => throw UnimplementedError();
}
