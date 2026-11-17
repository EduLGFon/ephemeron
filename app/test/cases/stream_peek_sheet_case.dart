import 'dart:async';

import 'package:ephemeron/features/stream/application/stream_day_mark.dart';
import 'package:ephemeron/features/stream/application/stream_peek_actions.dart';
import 'package:ephemeron/features/stream/application/stream_peek_gateway.dart';
import 'package:ephemeron/features/stream/application/stream_peek_target.dart';
import 'package:ephemeron/features/stream/presentation/peek/peek_data.dart';
import 'package:ephemeron/features/stream/presentation/peek/peek_editor.dart';
import 'package:ephemeron/features/stream/presentation/surface/stream_peek_sheet.dart';
import 'package:ephemeron/l10n/src/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

class _UnusedGateway implements StreamPeekGateway {
  @override
  Future<Never> noSuchMethod(Invocation invocation) =>
      Future<Never>.error(UnimplementedError('unused peek gateway'));
}

class _FakeActions extends StreamPeekActions {
  _FakeActions() : super(_UnusedGateway());

  final List<(StreamPeekTarget, PeekEdit)> calls = [];
  Object? error;

  @override
  Future<StreamPeekResult> save(StreamPeekTarget target, PeekEdit edit) async {
    calls.add((target, edit));
    if (error != null) throw error!;
    return const StreamPeekSaved();
  }
}

class _Opener extends StatelessWidget {
  const _Opener({required this.mark});

  final StreamDayMark mark;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: TextButton(
          onPressed: () => unawaited(showStreamPeek(context, mark: mark)),
          child: const Text('open'),
        ),
      ),
    );
  }
}

int _at(int hour, [int minute = 0]) =>
    DateTime(2026, 11, 17, hour, minute).millisecondsSinceEpoch;

StreamDayMark _taskMark() => StreamDayMark(
  id: 'occurrence-1',
  kind: StreamDayMarkKind.task,
  startMs: _at(9),
  endMs: _at(10),
  title: 'Original',
  colorArgb: 0xFF123456,
  sourceTaskOrEventId: 't1',
);

StreamDayMark _eventMark() => StreamDayMark(
  id: 'occurrence-event',
  kind: StreamDayMarkKind.event,
  startMs: _at(11),
  endMs: _at(12),
  title: 'Meeting',
  colorArgb: 0xFF654321,
  sourceTaskOrEventId: 'e1',
);

StreamPeekTarget _taskTarget() => StreamPeekTarget(
  data: PeekData(
    id: 't1',
    title: 'Original',
    startMs: _at(9),
    endMs: _at(10),
    listId: 'l1',
    listName: 'Work',
  ),
  editable: true,
  sourceTaskId: 't1',
  sourcePriority: 0,
);

StreamPeekTarget _eventTarget() => StreamPeekTarget(
  data: PeekData(id: 'e1', title: 'Meeting', startMs: _at(11), endMs: _at(12)),
  editable: false,
);

Finder get _titleField => find.byWidgetPredicate(
  (widget) =>
      widget is TextField && widget.key == const ValueKey('peek_title_field'),
);

Future<AppLocalizations> _openSheet(
  WidgetTester tester, {
  required StreamDayMark mark,
  required AsyncValue<StreamPeekTarget?> target,
  StreamPeekActions? actions,
  double textScale = 1,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        streamPeekTargetProvider(mark).overrideWithValue(target),
        streamPeekActionsProvider.overrideWithValue(actions ?? _FakeActions()),
      ],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: _Opener(mark: mark),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return AppLocalizations.delegate.load(const Locale('en'));
}

void main() {
  testWidgets('editable task saves the edited title and closes', (
    tester,
  ) async {
    final mark = _taskMark();
    final target = _taskTarget();
    final actions = _FakeActions();
    final l = await _openSheet(
      tester,
      mark: mark,
      target: AsyncValue<StreamPeekTarget?>.data(target),
      actions: actions,
    );

    expect(find.text('Original'), findsOneWidget);
    await tester.enterText(_titleField, 'Edited');
    await tester.pump();
    await tester.tap(find.text(l.streamPeekSave));
    await tester.pumpAndSettle();

    expect(actions.calls, hasLength(1));
    expect(actions.calls.single.$1, same(target));
    expect(actions.calls.single.$2.title, 'Edited');
    expect(find.byType(StreamPeekSheet), findsNothing);
    expect(find.text(l.streamPeekSaved), findsOneWidget);
  });

  testWidgets('dirty close confirms and keep editing stays open', (
    tester,
  ) async {
    final mark = _taskMark();
    final l = await _openSheet(
      tester,
      mark: mark,
      target: AsyncValue<StreamPeekTarget?>.data(_taskTarget()),
    );

    await tester.enterText(_titleField, 'Edited');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.text(l.streamPeekDiscardTitle), findsOneWidget);
    expect(find.byType(StreamPeekSheet), findsOneWidget);

    await tester.tap(find.text(l.streamPeekKeepEditing));
    await tester.pumpAndSettle();
    expect(find.byType(StreamPeekSheet), findsOneWidget);
    expect(find.text(l.streamPeekDiscardTitle), findsNothing);
    expect(find.text('Edited'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l.streamPeekDiscardConfirm));
    await tester.pumpAndSettle();
    expect(find.byType(StreamPeekSheet), findsNothing);
  });

  testWidgets('clean close does not ask to discard', (tester) async {
    final mark = _taskMark();
    final l = await _openSheet(
      tester,
      mark: mark,
      target: AsyncValue<StreamPeekTarget?>.data(_taskTarget()),
    );

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.text(l.streamPeekDiscardTitle), findsNothing);
    expect(find.byType(StreamPeekSheet), findsNothing);
  });

  testWidgets('event target is read-only with no save', (tester) async {
    final mark = _eventMark();
    final l = await _openSheet(
      tester,
      mark: mark,
      target: AsyncValue<StreamPeekTarget?>.data(_eventTarget()),
    );

    expect(find.text('Meeting'), findsOneWidget);
    expect(find.text(l.streamPeekReadOnly), findsOneWidget);
    expect(find.text(l.streamPeekSave), findsNothing);
    expect(find.byType(TextField), findsNothing);
    expect(find.byIcon(Icons.close), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.byType(StreamPeekSheet), findsNothing);
  });

  testWidgets('missing target shows the localized not-found message', (
    tester,
  ) async {
    final mark = _taskMark();
    final l = await _openSheet(
      tester,
      mark: mark,
      target: const AsyncValue<StreamPeekTarget?>.data(null),
    );

    expect(find.text(l.streamPeekNotFound), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('save failure keeps the sheet open with an error', (
    tester,
  ) async {
    final mark = _taskMark();
    final actions = _FakeActions()
      ..error = const StreamPeekException(StreamPeekFailure.saveFailed);
    final l = await _openSheet(
      tester,
      mark: mark,
      target: AsyncValue<StreamPeekTarget?>.data(_taskTarget()),
      actions: actions,
    );

    await tester.enterText(_titleField, 'Edited');
    await tester.pump();
    await tester.tap(find.text(l.streamPeekSave));
    await tester.pumpAndSettle();

    expect(find.byType(StreamPeekSheet), findsOneWidget);
    expect(find.text(l.streamPeekSaveFailed), findsOneWidget);
  });

  testWidgets('320 dp at 2.0 text scale does not overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _openSheet(
      tester,
      mark: _taskMark(),
      target: AsyncValue<StreamPeekTarget?>.data(_taskTarget()),
      textScale: 2,
    );

    expect(find.byType(StreamPeekSheet), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('320 dp at 2.0 text scale can reach save', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final actions = _FakeActions();
    final l = await _openSheet(
      tester,
      mark: _taskMark(),
      target: AsyncValue<StreamPeekTarget?>.data(_taskTarget()),
      actions: actions,
      textScale: 2,
    );

    final editorScroll = find
        .descendant(
          of: find.byType(PeekEditor),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.drag(editorScroll, const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l.streamPeekSave));
    await tester.pumpAndSettle();

    expect(actions.calls, hasLength(1));
  });
}
