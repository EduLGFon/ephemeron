import 'package:ephemeron/features/stream/presentation/peek/peek_data.dart';
import 'package:ephemeron/features/stream/presentation/peek/peek_editor.dart';
import 'package:ephemeron/features/stream/presentation/peek/peek_panel.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget home) => MaterialApp(home: Scaffold(body: home));

void main() {
  testWidgets('opening focuses the title', (tester) async {
    await tester.pumpWidget(
      _app(
        PeekEditor(
          data: const PeekData(id: '1', title: 't', startMs: 0),
          formatTime: (ms) => 'T',
          priorityLabels: const ['N', 'L', 'M', 'H'],
          saveLabel: 'Save',
          cancelLabel: 'Cancel',
          onSave: (_) {},
          onCancel: () {},
          onDiscardRequested: () {},
          titleKey: const ValueKey('title'),
        ),
      ),
    );
    await tester.pump();
    final state = tester.state<PeekEditorState>(find.byType(PeekEditor));
    expect(state.titleFocusNode.hasFocus, isTrue);
  });

  testWidgets('editing title and saving calls onSave with new PeekEdit', (
    tester,
  ) async {
    PeekEdit? saved;
    await tester.pumpWidget(
      _app(
        PeekEditor(
          data: const PeekData(
            id: '1',
            title: 'old',
            startMs: 5,
            endMs: 9,
            listId: 'l',
            priority: PeekPriority.low,
            notes: 'n',
          ),
          formatTime: (ms) => 'T$ms',
          priorityLabels: const ['N', 'L', 'M', 'H'],
          saveLabel: 'Save',
          cancelLabel: 'Cancel',
          onSave: (e) => saved = e,
          onCancel: () {},
          onDiscardRequested: () {},
          onPickTime: (ctx, cur) async => cur,
        ),
      ),
    );
    await tester.pump();
    await tester.enterText(find.byType(TextField).first, 'new title');
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(saved, isNotNull);
    expect(saved!.title, 'new title');
    expect(saved!.startMs, 5);
    expect(saved!.endMs, 9);
    expect(saved!.listId, 'l');
    expect(saved!.priority, PeekPriority.low);
    expect(saved!.notes, 'n');
  });

  testWidgets('Enter saves', (tester) async {
    var saved = false;
    await tester.pumpWidget(
      _app(
        PeekEditor(
          data: const PeekData(id: '1', title: 't', startMs: 0),
          formatTime: (ms) => 'T',
          priorityLabels: const ['N', 'L', 'M', 'H'],
          saveLabel: 'Save',
          cancelLabel: 'Cancel',
          onSave: (_) => saved = true,
          onCancel: () {},
          onDiscardRequested: () {},
        ),
      ),
    );
    await tester.pump();
    await tester.enterText(find.byType(TextField).first, 'x');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(saved, isTrue);
  });

  testWidgets('Esc cancels when clean and discards when dirty', (tester) async {
    var cancelled = false;
    var discarded = false;
    await tester.pumpWidget(
      _app(
        PeekEditor(
          data: const PeekData(id: '1', title: 't', startMs: 0),
          formatTime: (ms) => 'T',
          priorityLabels: const ['N', 'L', 'M', 'H'],
          saveLabel: 'Save',
          cancelLabel: 'Cancel',
          onSave: (_) {},
          onCancel: () => cancelled = true,
          onDiscardRequested: () => discarded = true,
        ),
      ),
    );
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(cancelled, isTrue);

    cancelled = false;
    await tester.pumpWidget(
      _app(
        PeekEditor(
          data: const PeekData(id: '1', title: 't', startMs: 0),
          formatTime: (ms) => 'T',
          priorityLabels: const ['N', 'L', 'M', 'H'],
          saveLabel: 'Save',
          cancelLabel: 'Cancel',
          onSave: (_) {},
          onCancel: () => cancelled = true,
          onDiscardRequested: () => discarded = true,
        ),
      ),
    );
    await tester.pump();
    await tester.enterText(find.byType(TextField).first, 'changed');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(discarded, isTrue);
  });

  testWidgets('cancel button dirty handling', (tester) async {
    var discarded = false;
    await tester.pumpWidget(
      _app(
        PeekEditor(
          data: const PeekData(id: '1', title: 't', startMs: 0),
          formatTime: (ms) => 'T',
          priorityLabels: const ['N', 'L', 'M', 'H'],
          saveLabel: 'Save',
          cancelLabel: 'Cancel',
          onSave: (_) {},
          onCancel: () {},
          onDiscardRequested: () => discarded = true,
        ),
      ),
    );
    await tester.pump();
    await tester.enterText(find.byType(TextField).first, 'changed');
    await tester.pump();
    await tester.tap(find.text('Cancel'));
    await tester.pump();
    expect(discarded, isTrue);
  });

  testWidgets('priority control changes value and labels caller-supplied', (
    tester,
  ) async {
    PeekEdit? saved;
    await tester.pumpWidget(
      _app(
        PeekEditor(
          data: const PeekData(id: '1', title: 't', startMs: 0),
          formatTime: (ms) => 'T',
          priorityLabels: const [
            'NoneLabel',
            'LowLabel',
            'MedLabel',
            'HighLabel',
          ],
          saveLabel: 'Save',
          cancelLabel: 'Cancel',
          onSave: (e) => saved = e,
          onCancel: () {},
          onDiscardRequested: () {},
        ),
      ),
    );
    await tester.pump();
    expect(find.text('HighLabel'), findsOneWidget);
    await tester.tap(find.text('HighLabel'));
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(saved!.priority, PeekPriority.high);
  });

  testWidgets('long title and notes at 320dp and 2.0 scale do not overflow', (
    tester,
  ) async {
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
                title: 'a' * 200,
                startMs: 0,
                notes: 'b' * 500,
              ),
              formatTime: (ms) => 'T' * 20,
              priorityLabels: const ['N', 'L', 'M', 'H'],
              saveLabel: 'Save',
              cancelLabel: 'Cancel',
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

  testWidgets('reduce-motion still builds and behaves', (tester) async {
    var saved = false;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: _app(
          PeekPanel(
            data: const PeekData(id: '1', title: 't', startMs: 0),
            expanded: true,
            formatTime: (ms) => 'T',
            priorityLabels: const ['N', 'L', 'M', 'H'],
            saveLabel: 'Save',
            cancelLabel: 'Cancel',
            closeLabel: 'Close',
            panelLabel: 'Peek panel',
            onSave: (_) => saved = true,
            onCancel: () {},
            onDiscardRequested: () {},
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(saved, isTrue);
  });

  testWidgets('semantics labels for save and cancel exist', (tester) async {
    await tester.pumpWidget(
      _app(
        PeekEditor(
          data: const PeekData(id: '1', title: 't', startMs: 0),
          formatTime: (ms) => 'T',
          priorityLabels: const ['N', 'L', 'M', 'H'],
          saveLabel: 'SaveBtn',
          cancelLabel: 'CancelBtn',
          onSave: (_) {},
          onCancel: () {},
          onDiscardRequested: () {},
        ),
      ),
    );
    await tester.pump();
    expect(find.text('SaveBtn'), findsOneWidget);
    expect(find.text('CancelBtn'), findsOneWidget);
  });

  testWidgets('panel semantics group label', (tester) async {
    await tester.pumpWidget(
      _app(
        PeekPanel(
          data: const PeekData(id: '1', title: 't', startMs: 0),
          expanded: true,
          formatTime: (ms) => 'T',
          priorityLabels: const ['N', 'L', 'M', 'H'],
          saveLabel: 'Save',
          cancelLabel: 'Cancel',
          closeLabel: 'Close',
          panelLabel: 'PeekGroup',
          onSave: (_) {},
          onCancel: () {},
          onDiscardRequested: () {},
        ),
      ),
    );
    await tester.pump();
    expect(find.bySemanticsLabel('PeekGroup'), findsOneWidget);
  });

  testWidgets('reseed on mark change', (tester) async {
    final data = ValueNotifier(const PeekData(id: 'a', title: 'A', startMs: 1));
    await tester.pumpWidget(
      _app(
        ValueListenableBuilder<PeekData>(
          valueListenable: data,
          builder: (_, d, _) => PeekEditor(
            data: d,
            formatTime: (ms) => 'T$ms',
            priorityLabels: const ['N', 'L', 'M', 'H'],
            saveLabel: 'Save',
            cancelLabel: 'Cancel',
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
    final state = tester.state<PeekEditorState>(find.byType(PeekEditor));
    expect(state.titleFocusNode, isNotNull);
    expect(find.text('B'), findsOneWidget);
    expect(state.hasChanges, isFalse);
  });

  testWidgets('add and clear end time', (tester) async {
    PeekEdit? saved;
    await tester.pumpWidget(
      _app(
        PeekEditor(
          data: const PeekData(id: '1', title: 't', startMs: 0),
          formatTime: (ms) => 'T$ms',
          priorityLabels: const ['N', 'L', 'M', 'H'],
          saveLabel: 'Save',
          cancelLabel: 'Cancel',
          addEndLabel: 'Add end',
          clearEndLabel: 'Clear end',
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

    // add path
    await tester.pumpWidget(
      _app(
        PeekEditor(
          data: const PeekData(id: '1', title: 't', startMs: 0),
          formatTime: (ms) => 'T$ms',
          priorityLabels: const ['N', 'L', 'M', 'H'],
          saveLabel: 'Save',
          cancelLabel: 'Cancel',
          addEndLabel: 'Add end',
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

  testWidgets('validation blocks empty title and end before start', (
    tester,
  ) async {
    var saved = false;
    await tester.pumpWidget(
      _app(
        PeekEditor(
          data: const PeekData(id: '1', title: 't', startMs: 10, endMs: 20),
          formatTime: (ms) => 'T$ms',
          priorityLabels: const ['N', 'L', 'M', 'H'],
          saveLabel: 'Save',
          cancelLabel: 'Cancel',
          emptyTitleLabel: 'Title required',
          endBeforeStartLabel: 'End after start',
          onSave: (_) => saved = true,
          onCancel: () {},
          onDiscardRequested: () {},
          onPickTime: (ctx, cur) async => cur,
        ),
      ),
    );
    await tester.pump();
    await tester.enterText(find.byType(TextField).first, '');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(saved, isFalse);
    expect(find.text('Title required'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'ok');
    // set end before start via direct state not possible; rely on end field picker returning earlier
    await tester.pumpWidget(
      _app(
        PeekEditor(
          data: const PeekData(id: '2', title: 't', startMs: 10, endMs: 5),
          formatTime: (ms) => 'T$ms',
          priorityLabels: const ['N', 'L', 'M', 'H'],
          saveLabel: 'Save',
          cancelLabel: 'Cancel',
          emptyTitleLabel: 'Title required',
          endBeforeStartLabel: 'End after start',
          onSave: (_) => saved = true,
          onCancel: () {},
          onDiscardRequested: () {},
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(saved, isFalse);
    expect(find.text('End after start'), findsOneWidget);
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
              priorityLabels: const ['N', 'L', 'M', 'H'],
              saveLabel: 'Save',
              cancelLabel: 'Cancel',
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

  testWidgets('dirty close button calls discard', (tester) async {
    var cancelled = false;
    var discarded = false;
    await tester.pumpWidget(
      _app(
        PeekPanel(
          data: const PeekData(id: '1', title: 't', startMs: 0),
          expanded: true,
          formatTime: (ms) => 'T',
          priorityLabels: const ['N', 'L', 'M', 'H'],
          saveLabel: 'Save',
          cancelLabel: 'Cancel',
          closeLabel: 'Close',
          panelLabel: 'PeekGroup',
          onSave: (_) {},
          onCancel: () => cancelled = true,
          onDiscardRequested: () => discarded = true,
        ),
      ),
    );
    await tester.pump();
    await tester.enterText(find.byType(TextField).first, 'changed');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();
    expect(discarded, isTrue);
    expect(cancelled, isFalse);
  });
}
