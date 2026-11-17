import 'package:ephemeron/features/stream/presentation/peek/peek_data.dart';
import 'package:ephemeron/features/stream/presentation/peek/peek_editor.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget home) => MaterialApp(home: Scaffold(body: home));

void main() {
  testWidgets('reseed on mark change', (tester) async {
    final data = ValueNotifier(const PeekData(id: 'a', title: 'A', startMs: 1));
    await tester.pumpWidget(
      _app(
        ValueListenableBuilder<PeekData>(
          valueListenable: data,
          builder: (_, d, _) => PeekEditor(
            data: d,
            formatTime: (ms) => 'T$ms',
            priorityLabels: const ['None', 'Low', 'Medium', 'High'],
            saveLabel: 'Save',
            cancelLabel: 'Cancel',
            emptyTitleLabel: 'Title required',
            endBeforeStartLabel: 'End after start',
            onSave: (_) {},
            onCancel: () {},
            onDiscardRequested: () {},
          ),
        ),
      ),
    );
    await tester.pump();
    data.value = const PeekData(id: 'b', title: 'B', startMs: 2);
    await tester.pump();
    expect(find.text('B'), findsOneWidget);
    final state = tester.state<PeekEditorState>(find.byType(PeekEditor));
    expect(state.hasChanges, isFalse);
  });

  testWidgets('equal data preserves typing and cursor', (tester) async {
    final data = ValueNotifier(const PeekData(id: 'a', title: 'A', startMs: 1));
    await tester.pumpWidget(
      _app(
        ValueListenableBuilder<PeekData>(
          valueListenable: data,
          builder: (_, d, _) => PeekEditor(
            data: d,
            formatTime: (ms) => 'T$ms',
            priorityLabels: const ['None', 'Low', 'Medium', 'High'],
            saveLabel: 'Save',
            cancelLabel: 'Cancel',
            emptyTitleLabel: 'Title required',
            endBeforeStartLabel: 'End after start',
            onSave: (_) {},
            onCancel: () {},
            onDiscardRequested: () {},
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.enterText(find.byType(TextField).first, 'A typed');
    await tester.pump();
    data.value = const PeekData(id: 'a', title: 'A', startMs: 1);
    await tester.pump();
    expect(find.text('A typed'), findsOneWidget);
  });

  testWidgets('add and clear end time', (tester) async {
    PeekEdit? saved;
    await tester.pumpWidget(
      _app(
        PeekEditor(
          data: const PeekData(id: '1', title: 't', startMs: 0),
          formatTime: (ms) => 'T$ms',
          priorityLabels: const ['None', 'Low', 'Medium', 'High'],
          saveLabel: 'Save',
          cancelLabel: 'Cancel',
          addEndLabel: 'Add end',
          clearEndLabel: 'Clear end',
          emptyTitleLabel: 'Title required',
          endBeforeStartLabel: 'End after start',
          onSave: (e) => saved = e,
          onCancel: () {},
          onDiscardRequested: () {},
          onPickTime: (ctx, cur) async => cur + 10,
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Add end'));
    await tester.pump();
    await tester.tap(find.text('Clear end'));
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(saved!.endMs, isNull);

    await tester.pumpWidget(
      _app(
        PeekEditor(
          data: const PeekData(id: '1', title: 't', startMs: 0),
          formatTime: (ms) => 'T$ms',
          priorityLabels: const ['None', 'Low', 'Medium', 'High'],
          saveLabel: 'Save',
          cancelLabel: 'Cancel',
          addEndLabel: 'Add end',
          emptyTitleLabel: 'Title required',
          endBeforeStartLabel: 'End after start',
          onSave: (e) => saved = e,
          onCancel: () {},
          onDiscardRequested: () {},
          onPickTime: (ctx, cur) async => cur + 10,
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Add end'));
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(saved!.endMs, 30 * 60 * 1000 + 10);
  });

  testWidgets('cancelling end picker keeps end', (tester) async {
    PeekEdit? saved;
    await tester.pumpWidget(
      _app(
        PeekEditor(
          data: const PeekData(id: '1', title: 't', startMs: 0, endMs: 50),
          formatTime: (ms) => 'T$ms',
          priorityLabels: const ['None', 'Low', 'Medium', 'High'],
          saveLabel: 'Save',
          cancelLabel: 'Cancel',
          emptyTitleLabel: 'Title required',
          endBeforeStartLabel: 'End after start',
          onSave: (e) => saved = e,
          onCancel: () {},
          onDiscardRequested: () {},
          onPickTime: (ctx, cur) async => null,
        ),
      ),
    );
    await tester.pump();
    final field = find.text('T50');
    await tester.tap(field);
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(saved!.endMs, 50);
  });

  testWidgets('long list name does not overflow', (tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(320, 640),
          textScaler: TextScaler.linear(2.0),
        ),
        child: _app(
          SizedBox(
            width: 320,
            child: PeekEditor(
              data: PeekData(
                id: '1',
                title: 't',
                startMs: 0,
                listId: 'l',
                listName: 'x' * 300,
              ),
              formatTime: (ms) => 'T',
              priorityLabels: const ['None', 'Low', 'Medium', 'High'],
              saveLabel: 'Save',
              cancelLabel: 'Cancel',
              emptyTitleLabel: 'Title required',
              endBeforeStartLabel: 'End after start',
              listOptions: [PeekListOption(id: 'l', name: 'x' * 300)],
              onSave: (_) {},
              onCancel: () {},
              onDiscardRequested: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
