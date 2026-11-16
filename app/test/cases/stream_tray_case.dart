import 'package:ephemeron/features/stream/presentation/tray/tray_item.dart';
import 'package:ephemeron/features/stream/presentation/tray/tray_strip.dart';
import 'package:ephemeron/features/stream/presentation/tray/tray_panel.dart';
import 'package:ephemeron/features/stream/presentation/tray/tray_chip.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('TrayStrip shows right number of chips', (tester) async {
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
              onExpandRequested: () {},
              emptyLabel: 'Empty',
              onTap: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(TrayChip), findsNWidgets(3));
  });

  testWidgets('TrayStrip count badge text matches', (tester) async {
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
              onExpandRequested: () {},
              emptyLabel: 'Empty',
              onTap: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('TrayStrip tapping chip fires onTap with id', (tester) async {
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
              onExpandRequested: () {},
              emptyLabel: 'Empty',
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

  testWidgets('TrayStrip tapping handle fires onExpandRequested', (
    tester,
  ) async {
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
              onExpandRequested: () => expanded++,
              emptyLabel: 'Empty',
              onTap: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byType(GestureDetector).first);
    await tester.pump();
    expect(expanded, 1);
  });

  testWidgets('TrayStrip 500 items uses builder', (tester) async {
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
              onExpandRequested: () {},
              emptyLabel: 'Empty',
              onTap: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.widgetList(find.byType(TrayChip)).length, lessThan(20));
  });

  testWidgets('TrayStrip empty shows empty label', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            child: TrayStrip(
              items: const [],
              countSemanticsLabel: '0 tasks',
              onExpandRequested: () {},
              emptyLabel: 'Nothing here',
              onTap: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Nothing here'), findsOneWidget);
  });

  testWidgets('TrayStrip no overflow at 320dp 2.0 scale', (tester) async {
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
                onExpandRequested: () {},
                emptyLabel: 'Empty',
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

  testWidgets('TrayStrip semantics labels present', (tester) async {
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
              onExpandRequested: () {},
              emptyLabel: 'Empty',
              onTap: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.bySemanticsLabel('1 task'), findsOneWidget);
  });

  testWidgets('TrayPanel groups by list in order with counts', (tester) async {
    final items = [
      TrayItem(
        id: 'a',
        title: 'A',
        listId: 'l1',
        listName: 'Work',
        colorArgb: 0xFF000000,
      ),
      TrayItem(
        id: 'b',
        title: 'B',
        listId: 'l2',
        listName: 'Home',
        colorArgb: 0xFF111111,
      ),
      TrayItem(
        id: 'c',
        title: 'C',
        listId: 'l1',
        listName: 'Work',
        colorArgb: 0xFF000000,
      ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 400,
            width: 400,
            child: TrayPanel(items: items, emptyLabel: 'Empty'),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Work'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    // counts: Work 2, Home 1
    expect(find.text('2'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('TrayPanel 0 items shows empty label', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 400,
            width: 400,
            child: TrayPanel(items: const [], emptyLabel: 'Nothing'),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Nothing'), findsOneWidget);
  });

  testWidgets('TrayPanel no overflow at 320dp 2.0 scale', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final items = [
      TrayItem(
        id: 'a',
        title: 'A very long title that should ellipsize instead of overflowing',
        listId: 'l1',
        listName: 'A very long list name that should ellipsize',
        colorArgb: 0xFF000000,
      ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
          child: Scaffold(
            body: SizedBox(
              height: 400,
              width: 320,
              child: TrayPanel(items: items, emptyLabel: 'Empty'),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('TrayPanel semantics labels present', (tester) async {
    final items = [
      TrayItem(
        id: 'a',
        title: 'Task A',
        listId: 'l1',
        listName: 'Work',
        colorArgb: 0xFF000000,
      ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 400,
            width: 400,
            child: TrayPanel(items: items, emptyLabel: 'Empty'),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.bySemanticsLabel('Task A, Work'), findsOneWidget);
  });

  testWidgets('TrayChip min touch target 48', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TrayChip(
            item: TrayItem(
              id: 't',
              title: 'Task',
              listId: 'l',
              listName: 'List',
              colorArgb: 0xFF000000,
            ),
            onTap: () {},
          ),
        ),
      ),
    );
    await tester.pump();
    final size = tester.getSize(find.byType(TrayChip));
    expect(size.height, greaterThanOrEqualTo(48));
    expect(size.width, greaterThanOrEqualTo(48));
  });
}
