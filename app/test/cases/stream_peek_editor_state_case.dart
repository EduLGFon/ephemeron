import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ephemeron/features/stream/presentation/peek/peek_data.dart';
import 'package:ephemeron/features/stream/presentation/peek/peek_editor.dart';
import 'package:ephemeron/features/stream/presentation/peek/peek_editor_state.dart';
import 'package:ephemeron/features/stream/presentation/peek/peek_list_selector.dart';

Widget _app(Widget home) => MaterialApp(home: Scaffold(body: home));

class _BuildCounter extends StatelessWidget {
  const _BuildCounter({required this.onBuild, required this.child});
  final VoidCallback onBuild;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    onBuild();
    return child;
  }
}

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
    int builds = 0;
    PeekData data = PeekData(id: 'a', title: 'A', startMs: 1);
    Widget wrap(PeekData d) => _app(
      _BuildCounter(
        onBuild: () => builds++,
        child: PeekEditor(
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
    );
    await tester.pumpWidget(wrap(data));
    await tester.pump();
    final titleFinder = find.byWidgetPredicate(
      (w) => w is TextField && w.key == const ValueKey('peek_title_field'),
    );
    await tester.enterText(titleFinder, 'A typed');
    await tester.pump();
    final controller = tester.widget<TextField>(titleFinder).controller!;
    controller.selection = const TextSelection.collapsed(offset: 2);
    await tester.pump();
    final beforeBuilds = builds;
    data = PeekData(id: 'a', title: 'A', startMs: 1);
    await tester.pumpWidget(wrap(data));
    await tester.pump();
    expect(builds, greaterThan(beforeBuilds));
    final afterController = tester.widget<TextField>(titleFinder).controller!;
    expect(afterController.text, 'A typed');
    expect(afterController.selection, const TextSelection.collapsed(offset: 2));
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
    final state = tester.state<PeekEditorState>(find.byType(PeekEditor));
    expect(state.hasChanges, isFalse);
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(saved!.endMs, 50);
  });

  testWidgets('list picker null result is cancel, never a clear', (
    tester,
  ) async {
    String? changedId = 'unchanged';
    await tester.pumpWidget(
      _app(
        PeekListSelector(
          listId: 'l1',
          listName: 'Work',
          onPickList: (_) async => null,
          onChanged: (id, _) => changedId = id,
        ),
      ),
    );

    await tester.tap(find.byType(InkWell));
    await tester.pumpAndSettle();

    expect(changedId, 'unchanged');
  });

  testWidgets('list dropdown offers no clear item', (tester) async {
    await tester.pumpWidget(
      _app(
        PeekListSelector(
          options: const [PeekListOption(id: 'l1', name: 'Work')],
          listId: 'l1',
          listName: 'Work',
          onChanged: (_, _) {},
        ),
      ),
    );

    await tester.tap(find.byType(DropdownButtonFormField<String?>));
    await tester.pumpAndSettle();

    final items = tester.widgetList<DropdownMenuItem<String?>>(
      find.byType(DropdownMenuItem<String?>),
    );
    expect(items.where((item) => item.value == null), isEmpty);
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
