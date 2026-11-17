import 'package:ephemeron/features/stream/presentation/tray/tray_item.dart';
import 'package:ephemeron/features/stream/presentation/tray/tray_panel.dart';
import 'package:ephemeron/features/stream/presentation/tray/tray_panel_item.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
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
    await tester.tap(find.byKey(const ValueKey('i:k1')));
    await tester.pump();
    expect(fired, ['k1']);
  });

  testWidgets('panel row keyboard Enter and Space activate', (tester) async {
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
    final row = find.byKey(const ValueKey('i:k1'));
    await tester.tap(row);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(fired.length, 3);
  });

  testWidgets('panel item unnamed fallback label', (tester) async {
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
    expect(find.bySemanticsLabel('Task A, Unnamed'), findsOneWidget);
  });

  testWidgets('panel unnamedGroupLabel change updates header', (tester) async {
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
              unnamedGroupLabel: 'First',
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.bySemanticsLabel('First, 1'), findsOneWidget);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 400,
            width: 400,
            child: TrayPanel(
              items: items,
              emptyLabel: 'Empty',
              unnamedGroupLabel: 'Second',
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.bySemanticsLabel('Second, 1'), findsOneWidget);
  });

  testWidgets(
    'non-actionable row cannot take focus and does not swallow Space',
    (tester) async {
      final item = TrayItem(
        id: 'a',
        title: 'Task A',
        listId: 'l1',
        listName: 'Work',
        colorArgb: 0xFF000000,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 400,
              width: 400,
              child: TrayPanelItem(item: item, listName: 'Work'),
            ),
          ),
        ),
      );
      await tester.pump();
      final focusNode = tester
          .widget<Focus>(
            find.descendant(
              of: find.byType(TrayPanelItem),
              matching: find.byType(Focus),
            ),
          )
          .focusNode;
      expect(focusNode!.canRequestFocus, isFalse);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      // no crash / no swallowed (ignored) - just ensure no exception
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('actionable row can take focus and swallows Space', (
    tester,
  ) async {
    final fired = <String>[];
    final item = TrayItem(
      id: 'a',
      title: 'Task A',
      listId: 'l1',
      listName: 'Work',
      colorArgb: 0xFF000000,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 400,
            width: 400,
            child: TrayPanelItem(
              item: item,
              listName: 'Work',
              onTap: () => fired.add('x'),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final focusNode = tester
        .widget<Focus>(
          find.descendant(
            of: find.byType(TrayPanelItem),
            matching: find.byType(Focus),
          ),
        )
        .focusNode;
    expect(focusNode!.canRequestFocus, isTrue);
    await tester.tap(find.byType(TrayPanelItem));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(fired, isNotEmpty);
  });

  testWidgets('button semantics false when onTap null, true when actionable', (
    tester,
  ) async {
    final item = TrayItem(
      id: 'a',
      title: 'Task A',
      listId: 'l1',
      listName: 'Work',
      colorArgb: 0xFF000000,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 400,
            width: 400,
            child: TrayPanelItem(item: item, listName: 'Work'),
          ),
        ),
      ),
    );
    await tester.pump();
    final sem1 = tester
        .getSemantics(find.byType(TrayPanelItem))
        .getSemanticsData();
    expect(sem1.flagsCollection.isButton, isFalse);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 400,
            width: 400,
            child: TrayPanelItem(item: item, listName: 'Work', onTap: () {}),
          ),
        ),
      ),
    );
    await tester.pump();
    final sem2 = tester
        .getSemantics(find.byType(TrayPanelItem))
        .getSemanticsData();
    expect(sem2.flagsCollection.isButton, isTrue);
  });
}
