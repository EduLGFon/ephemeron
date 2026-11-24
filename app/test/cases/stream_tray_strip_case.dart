import 'package:ephemeron/features/stream/presentation/tray/tray_item.dart';
import 'package:ephemeron/features/stream/presentation/tray/tray_strip.dart';
import 'package:ephemeron/features/stream/presentation/tray/tray_chip.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';


void main() {
  testWidgets('strip shows right number of chips', (tester) async {
    final items = List.generate(
      3,
      (i) => TrayItem(
        id: 't$i',
        title: 'Task $i',
        listId: 'l1',
        listName: 'List',
        colorArgb: 0xFF000000,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            child: TrayStrip(
              items: items,
              countSemanticsLabel: '3 tasks',
              handleSemanticsLabel: 'expand',
              emptyLabel: 'Empty',
              onExpandRequested: () {},
              onTap: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(TrayChip), findsNWidgets(3));
  });

  testWidgets('strip count badge text matches', (tester) async {
    final items = List.generate(
      2,
      (i) => TrayItem(
        id: 't$i',
        title: 'Task $i',
        listId: 'l1',
        listName: 'List',
        colorArgb: 0xFF000000,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            child: TrayStrip(
              items: items,
              countSemanticsLabel: '2 tasks',
              handleSemanticsLabel: 'expand',
              emptyLabel: 'Empty',
              onExpandRequested: () {},
              onTap: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('strip tapping chip fires onTap with id', (tester) async {
    final fired = <String>[];
    final items = [
      TrayItem(
        id: 'abc',
        title: 'Task',
        listId: 'l1',
        listName: 'List',
        colorArgb: 0xFF000000,
      ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            child: TrayStrip(
              items: items,
              countSemanticsLabel: '1 task',
              handleSemanticsLabel: 'expand',
              emptyLabel: 'Empty',
              onExpandRequested: () {},
              onTap: fired.add,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byType(TrayChip));
    await tester.pump();
    expect(fired, ['abc']);
  });

  testWidgets('strip tapping handle fires onExpandRequested', (tester) async {
    var expanded = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            child: TrayStrip(
              items: [
                TrayItem(
                  id: 't0',
                  title: 'Task',
                  listId: 'l1',
                  listName: 'List',
                  colorArgb: 0xFF000000,
                ),
              ],
              countSemanticsLabel: '1 task',
              handleSemanticsLabel: 'expand',
              emptyLabel: 'Empty',
              onExpandRequested: () => expanded++,
              onTap: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('expand'));
    await tester.pump();
    expect(expanded, 1);
  });

  testWidgets('strip 500 items uses builder', (tester) async {
    final items = List.generate(
      500,
      (i) => TrayItem(
        id: 't$i',
        title: 'Task $i',
        listId: 'l1',
        listName: 'List',
        colorArgb: 0xFF000000,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            child: TrayStrip(
              items: items,
              countSemanticsLabel: '500 tasks',
              handleSemanticsLabel: 'expand',
              emptyLabel: 'Empty',
              onExpandRequested: () {},
              onTap: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.widgetList(find.byType(TrayChip)).length, lessThan(20));
  });

  testWidgets('strip empty shows empty label', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            child: TrayStrip(
              items: const [],
              countSemanticsLabel: '0 tasks',
              handleSemanticsLabel: 'expand',
              emptyLabel: 'Nothing here',
              onExpandRequested: () {},
              onTap: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Nothing here'), findsOneWidget);
  });

  testWidgets('strip empty keeps handle', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            child: TrayStrip(
              items: const [],
              countSemanticsLabel: '0 tasks',
              handleSemanticsLabel: 'expand',
              emptyLabel: 'Empty',
              onExpandRequested: () {},
              onTap: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.bySemanticsLabel('expand'), findsOneWidget);
  });

  testWidgets('strip no overflow at 320dp 2.0 scale', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final items = List.generate(
      3,
      (i) => TrayItem(
        id: 't$i',
        title: 'A very long task title that should not overflow',
        listId: 'l1',
        listName: 'List',
        colorArgb: 0xFF000000,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
          child: Scaffold(
            body: SizedBox(
              width: 320,
              child: TrayStrip(
                items: items,
                countSemanticsLabel: '3 tasks',
                handleSemanticsLabel: 'expand',
                emptyLabel: 'Empty',
                onExpandRequested: () {},
                onTap: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('strip semantics labels present', (tester) async {
    final items = [
      TrayItem(
        id: 't0',
        title: 'Task',
        listId: 'l1',
        listName: 'List',
        colorArgb: 0xFF000000,
      ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            child: TrayStrip(
              items: items,
              countSemanticsLabel: '1 task',
              handleSemanticsLabel: 'expand',
              emptyLabel: 'Empty',
              onExpandRequested: () {},
              onTap: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.bySemanticsLabel('1 task'), findsOneWidget);
  });
  testWidgets('strip expand handle at least 48x48', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            child: TrayStrip(
              items: const [],
              countSemanticsLabel: '0 tasks',
              handleSemanticsLabel: 'expand',
              emptyLabel: 'Empty',
              onExpandRequested: () {},
              onTap: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final size = tester.getSize(find.bySemanticsLabel('expand'));
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
  });
}
