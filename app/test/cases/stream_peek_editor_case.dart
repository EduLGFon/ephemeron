import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ephemeron/features/stream/presentation/peek/peek_data.dart';
import 'package:ephemeron/features/stream/presentation/peek/peek_editor.dart';
import 'package:ephemeron/features/stream/presentation/peek/peek_editor_state.dart';


Widget _app(Widget home) => MaterialApp(home: Scaffold(body: home));

void main() {
  testWidgets('opening focuses the title', (tester) async {
    await tester.pumpWidget(
      _app(
        PeekEditor(
          data: const PeekData(id: '1', title: 't', startMs: 0),
          formatTime: (ms) => 'T',
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
          priorityLabels: const ['None', 'Low', 'Medium', 'High'],
          saveLabel: 'Save',
          cancelLabel: 'Cancel',
          emptyTitleLabel: 'Title required',
          endBeforeStartLabel: 'End after start',
          onSave: (e) => saved = e,
          onCancel: () {},
          onDiscardRequested: () {},
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
          priorityLabels: const ['None', 'Low', 'Medium', 'High'],
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
          priorityLabels: const ['None', 'Low', 'Medium', 'High'],
          saveLabel: 'Save',
          cancelLabel: 'Cancel',
          emptyTitleLabel: 'Title required',
          endBeforeStartLabel: 'End after start',
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
          priorityLabels: const ['None', 'Low', 'Medium', 'High'],
          saveLabel: 'Save',
          cancelLabel: 'Cancel',
          emptyTitleLabel: 'Title required',
          endBeforeStartLabel: 'End after start',
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
          priorityLabels: const ['None', 'Low', 'Medium', 'High'],
          saveLabel: 'Save',
          cancelLabel: 'Cancel',
          emptyTitleLabel: 'Title required',
          endBeforeStartLabel: 'End after start',
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
          emptyTitleLabel: 'Title required',
          endBeforeStartLabel: 'End after start',
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
              priorityLabels: const [
                'Minimal',
                'LowPrio',
                'MediumPrio',
                'Critical',
              ],
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
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('semantics labels for save and cancel exist', (tester) async {
    await tester.pumpWidget(
      _app(
        PeekEditor(
          data: const PeekData(id: '1', title: 't', startMs: 0),
          formatTime: (ms) => 'T',
          priorityLabels: const ['None', 'Low', 'Medium', 'High'],
          saveLabel: 'SaveBtn',
          cancelLabel: 'CancelBtn',
          emptyTitleLabel: 'Title required',
          endBeforeStartLabel: 'End after start',
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
}
