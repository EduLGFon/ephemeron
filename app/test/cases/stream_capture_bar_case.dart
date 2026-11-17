import 'package:ephemeron/features/stream/capture/capture_parser.dart';
import 'package:ephemeron/features/stream/capture/capture_priority.dart';
import 'package:ephemeron/features/stream/presentation/capture/capture_bar.dart';
import 'package:ephemeron/features/stream/presentation/capture/capture_preview_chips.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:material_ui/material_ui.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

String _fmt(DateTime dt) =>
    '${dt.year.toString().padLeft(4, '0')}-'
    '${dt.month.toString().padLeft(2, '0')}-'
    '${dt.day.toString().padLeft(2, '0')} '
    '${dt.hour.toString().padLeft(2, '0')}:'
    '${dt.minute.toString().padLeft(2, '0')}';

void main() {
  final now = DateTime(2026, 11, 16, 9, 0);

  List<CapturePreviewChip> chipsFor(CaptureDraft d) => <CapturePreviewChip>[
    CapturePreviewChip(
      kind: CaptureChipKind.kind,
      label: 'kind:${d.kind.name}',
    ),
    if (d.date != null)
      CapturePreviewChip(
        kind: CaptureChipKind.date,
        label: 'date:${_fmt(d.date!)}',
      ),
    if (d.startTime != null)
      CapturePreviewChip(
        kind: CaptureChipKind.time,
        label: 'time:${_fmt(d.startTime!)}',
      ),
    if (d.repeat != null)
      CapturePreviewChip(
        kind: CaptureChipKind.repeat,
        label: 'repeat:${d.repeat}',
      ),
    if (d.listTag != null)
      CapturePreviewChip(
        kind: CaptureChipKind.list,
        label: 'list:${d.listTag}',
      ),
    if (d.priority != CapturePriority.none)
      CapturePreviewChip(
        kind: CaptureChipKind.priority,
        label: 'prio:${d.priority.name}',
      ),
  ];

  testWidgets('typing produces kind task plus date and time chips', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CaptureBar(
            now: now,
            locale: CaptureLocale.en,
            hintText: 'hint',
            label: 'capture',
            chipsBuilder: chipsFor,
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'call dentist tomorrow 3pm');
    await tester.pump();
    expect(find.textContaining('kind:task'), findsOneWidget);
    expect(find.textContaining('date:'), findsOneWidget);
    expect(find.textContaining('time:'), findsOneWidget);
  });

  testWidgets('tapping a chip fires onChipTapped with right kind', (
    tester,
  ) async {
    CaptureChipKind? tapped;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CaptureBar(
            now: now,
            locale: CaptureLocale.en,
            hintText: 'hint',
            label: 'capture',
            onChipTapped: (k) => tapped = k,
            chipsBuilder: (d) => <CapturePreviewChip>[
              CapturePreviewChip(
                kind: CaptureChipKind.date,
                label: 'date chip',
              ),
            ],
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'call dentist tomorrow 3pm');
    await tester.pump();
    await tester.tap(find.text('date chip'));
    await tester.pump();
    expect(tapped, CaptureChipKind.date);
  });

  testWidgets('Enter fires onSubmitted once, clears text, keeps focus', (
    tester,
  ) async {
    var count = 0;
    CaptureDraft? received;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CaptureBar(
            now: now,
            locale: CaptureLocale.en,
            hintText: 'hint',
            label: 'capture',
            onSubmitted: (d) {
              count++;
              received = d;
            },
            chipsBuilder: chipsFor,
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'hello');
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(count, 1);
    expect(received, isNotNull);
    expect(find.text('hello'), findsNothing);
    expect(
      tester.widget<TextField>(find.byType(TextField)).focusNode?.hasFocus,
      isTrue,
    );
    await tester.enterText(find.byType(TextField), 'world');
    await tester.pump();
    expect(find.text('world'), findsOneWidget);
  });

  testWidgets('Esc fires onDismiss', (tester) async {
    var dismissed = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CaptureBar(
            now: now,
            locale: CaptureLocale.en,
            hintText: 'hint',
            label: 'capture',
            onDismiss: () => dismissed++,
            chipsBuilder: chipsFor,
          ),
        ),
      ),
    );
    await tester.tap(find.byType(TextField));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(dismissed, 1);
  });

  testWidgets('unknown-only input produces only kind chip and keeps title', (
    tester,
  ) async {
    CaptureDraft? received;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CaptureBar(
            now: now,
            locale: CaptureLocale.en,
            hintText: 'hint',
            label: 'capture',
            onSubmitted: (d) => received = d,
            chipsBuilder: chipsFor,
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'xyz');
    await tester.pump();
    expect(find.byType(ActionChip), findsOneWidget);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(received, isNotNull);
    expect(received!.title, 'xyz');
  });

  testWidgets('320 dp width at textScaler 2.0 does not overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2.0)),
            child: Scaffold(
              body: SizedBox(
                width: 320,
                child: CaptureBar(
                  now: now,
                  locale: CaptureLocale.en,
                  hintText: 'a very long hint text that should not overflow the available width',
                  label: 'capture field label',
                  semanticsLabel: 'capture field',
                  submitLabel: 'submit',
                  clearLabel: 'clear',
                  closeLabel: 'close',
                  chipsBuilder: chipsFor,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'call dentist tomorrow 3pm');
    await tester.pump();
    expect(tester.takeException(), isNull);
    final fieldNode = tester.getSemantics(find.byType(TextField));
    expect(fieldNode.label, startsWith('capture field'));
    expect(fieldNode.label, isNot(contains('capture field label')));
    expect(find.bySemanticsLabel('submit'), findsOneWidget);
    expect(find.bySemanticsLabel('clear'), findsOneWidget);
    expect(find.bySemanticsLabel('close'), findsOneWidget);
    // Input stays usable at narrow widths.
    final inputWidth = tester.getSize(find.byType(TextField)).width;
    expect(inputWidth, greaterThanOrEqualTo(140));
  });

  testWidgets('one semantics node per chip', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CapturePreviewChips(
            chips: const <CapturePreviewChip>[
              CapturePreviewChip(kind: CaptureChipKind.kind, label: 'kind'),
              CapturePreviewChip(kind: CaptureChipKind.date, label: 'date'),
            ],
            onChipTapped: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();
    for (final label in <String>['kind', 'date']) {
      final chipFinder = find.text(label);
      final node = tester.getSemantics(chipFinder);
      expect(node.label, label);
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      expect(find.bySemanticsLabel(label), findsOneWidget);
    }
  });

  testWidgets('didUpdateWidget re-parses chips', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CaptureBar(
            now: now,
            locale: CaptureLocale.en,
            hintText: 'hint',
            label: 'capture',
            chipsBuilder: chipsFor,
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'tomorrow 3pm');
    await tester.pump();
    expect(find.textContaining('date:2026-11-17'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CaptureBar(
            now: now.add(const Duration(days: 1)),
            locale: CaptureLocale.en,
            hintText: 'hint',
            label: 'capture',
            chipsBuilder: chipsFor,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.textContaining('date:2026-11-18'), findsOneWidget);
  });
}
