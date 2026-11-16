import 'package:ephemeron/features/stream/presentation/tray/tray_item.dart';
import 'package:ephemeron/features/stream/presentation/tray/tray_panel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('panel groups by list in order with counts', (tester) async {
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
    expect(find.text('2'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('panel 0 items shows empty label', (tester) async {
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

  testWidgets('panel no overflow at 320dp 2.0 scale', (tester) async {
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

  testWidgets('panel semantics labels present', (tester) async {
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

  testWidgets('panel unnamed group fallback', (tester) async {
    final items = [
      TrayItem(
        id: 'a',
        title: 'Task A',
        listId: 'l1',
        listName: '',
        colorArgb: 0xFF000000,
      ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 400,
            width: 400,
            child: TrayPanel(
              items: items,
              emptyLabel: 'Empty',
              unnamedGroupLabel: 'Unnamed',
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.bySemanticsLabel('Unnamed, 1'), findsOneWidget);
  });

  testWidgets('panel duplicate ids deduped', (tester) async {
    final items = [
      TrayItem(
        id: 'dup',
        title: 'First',
        listId: 'l1',
        listName: 'Work',
        colorArgb: 0xFF000000,
      ),
      TrayItem(
        id: 'dup',
        title: 'Second',
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
    expect(find.text('First'), findsOneWidget);
    expect(find.text('Second'), findsNothing);
  });

  testWidgets('panel count over 1000', (tester) async {
    final items = List.generate(
      1001,
      (i) => TrayItem(
        id: 't$i',
        title: 'Task $i',
        listId: 'l1',
        listName: 'Work',
        colorArgb: 0xFF000000,
      ),
    );
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
    expect(find.text('1001'), findsOneWidget);
  });

  testWidgets('panel 500 items builds bounded rows', (tester) async {
    final items = List.generate(
      500,
      (i) => TrayItem(
        id: 't$i',
        title: 'Task $i',
        listId: 'l1',
        listName: 'Work',
        colorArgb: 0xFF000000,
      ),
    );
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
    // Count built item rows by key.
    var built = 0;
    for (var i = 0; i < 500; i++) {
      if (find.byKey(ValueKey('t$i')).evaluate().isNotEmpty) built++;
    }
    expect(built, lessThan(40));
  });

  testWidgets('panel stable keys per item', (tester) async {
    final items = [
      TrayItem(
        id: 'k1',
        title: 'Task',
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
    expect(find.byKey(const ValueKey('k1')), findsOneWidget);
  });

  testWidgets('panel item tap fires onItemTap', (tester) async {
    final fired = <String>[];
    final items = [
      TrayItem(
        id: 'k1',
        title: 'Task',
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
            child: TrayPanel(
              items: items,
              emptyLabel: 'Empty',
              onItemTap: fired.add,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('k1')));
    await tester.pump();
    expect(fired, ['k1']);
  });
}
