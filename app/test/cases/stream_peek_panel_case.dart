import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ephemeron/features/stream/presentation/peek/peek_data.dart';
import 'package:ephemeron/features/stream/presentation/peek/peek_editor.dart';
import 'package:ephemeron/features/stream/presentation/peek/peek_panel.dart';


Widget _app(Widget home) => MaterialApp(home: Scaffold(body: home));

void main() {
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
            priorityLabels: const ['None', 'Low', 'Medium', 'High'],
            saveLabel: 'Save',
            cancelLabel: 'Cancel',
            closeLabel: 'Close',
            panelLabel: 'Peek panel',
            emptyTitleLabel: 'Title required',
            endBeforeStartLabel: 'End after start',
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

  testWidgets('panel semantics group label', (tester) async {
    await tester.pumpWidget(
      _app(
        PeekPanel(
          data: const PeekData(id: '1', title: 't', startMs: 0),
          expanded: true,
          formatTime: (ms) => 'T',
          priorityLabels: const ['None', 'Low', 'Medium', 'High'],
          saveLabel: 'Save',
          cancelLabel: 'Cancel',
          closeLabel: 'Close',
          panelLabel: 'PeekGroup',
          emptyTitleLabel: 'Title required',
          endBeforeStartLabel: 'End after start',
          onSave: (_) {},
          onCancel: () {},
          onDiscardRequested: () {},
        ),
      ),
    );
    await tester.pump();
    expect(find.bySemanticsLabel('PeekGroup'), findsOneWidget);
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
          priorityLabels: const ['None', 'Low', 'Medium', 'High'],
          saveLabel: 'Save',
          cancelLabel: 'Cancel',
          closeLabel: 'Close',
          panelLabel: 'PeekGroup',
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
    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();
    expect(discarded, isTrue);
    expect(cancelled, isFalse);
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
    await tester.enterText(find.byType(TextField).first, '');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(saved, isFalse);
    expect(find.text('Title required'), findsOneWidget);

    await tester.pumpWidget(
      _app(
        PeekEditor(
          data: const PeekData(id: '2', title: 't', startMs: 10, endMs: 5),
          formatTime: (ms) => 'T$ms',
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
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(saved, isFalse);
    expect(find.text('End after start'), findsOneWidget);
  });
}
