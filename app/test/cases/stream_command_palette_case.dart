import 'package:ephemeron/features/stream/presentation/commands/command_palette.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final candidates = List.generate(
    10,
    (i) => CommandCandidate(id: 'c$i', label: 'Command $i'),
  );

  testWidgets('max 6 rows', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CommandPalette(candidates: candidates, onSelected: (_) {}),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(InkWell), findsNWidgets(6));
  });

  testWidgets('arrow keys move selection and Enter selects', (tester) async {
    CommandCandidate? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CommandPalette(
            candidates: candidates,
            onSelected: (c) => selected = c,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(selected, isNotNull);
    expect(selected!.id, 'c1');
  });

  testWidgets('Enter calls onSelected once', (tester) async {
    var count = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CommandPalette(
            candidates: candidates,
            onSelected: (_) => count++,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(count, 1);
  });

  testWidgets('Esc calls onDismiss', (tester) async {
    var dismissed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CommandPalette(
            candidates: candidates,
            onSelected: (_) {},
            onDismiss: () => dismissed = true,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(dismissed, isTrue);
  });

  testWidgets('no overflow at 320dp and 2.0 scale', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
          child: Scaffold(
            body: SizedBox(
              width: 320,
              child: CommandPalette(
                candidates: [
                  CommandCandidate(
                    id: 'x',
                    label: 'A very long command label that should ellipsize',
                  ),
                ],
                onSelected: (_) {},
                emptyLabel: 'empty',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('query ValueListenable filters', (tester) async {
    final q = ValueNotifier<String>('');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CommandPalette(
            query: q,
            candidates: candidates,
            onSelected: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();
    q.value = 'Command 9';
    await tester.pump();
    expect(find.text('Command 9'), findsOneWidget);
  });

  testWidgets('empty state label', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CommandPalette(
            candidates: const [],
            onSelected: (_) {},
            emptyLabel: 'nothing here',
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('nothing here'), findsOneWidget);
  });
}
