import 'package:ephemeron/features/stream/capture/capture_parser.dart';
import 'package:ephemeron/features/stream/presentation/capture/capture_bar.dart';
import 'package:ephemeron/features/stream/presentation/capture/capture_preview_chips.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 11, 16, 9, 0);

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
            chipsBuilder: (draft) => <CapturePreviewChip>[
              CapturePreviewChip(
                kind: CaptureChipKind.kind,
                label: draft.kind.name,
              ),
              if (draft.date != null)
                const CapturePreviewChip(
                  kind: CaptureChipKind.date,
                  label: 'date',
                ),
              if (draft.startTime != null)
                const CapturePreviewChip(
                  kind: CaptureChipKind.time,
                  label: 'time',
                ),
            ],
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'call dentist tomorrow 3pm');
    await tester.pump();
    expect(find.text('task'), findsOneWidget);
    expect(find.text('date'), findsOneWidget);
    expect(find.text('time'), findsOneWidget);
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
            chipsBuilder: (draft) => <CapturePreviewChip>[
              if (draft.date != null)
                const CapturePreviewChip(
                  kind: CaptureChipKind.date,
                  label: 'date',
                ),
            ],
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'call dentist tomorrow 3pm');
    await tester.pump();
    await tester.tap(find.text('date'));
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
    expect(_focusHasFocus(tester), isTrue);
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
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CaptureBar(
            now: now,
            locale: CaptureLocale.en,
            hintText: 'hint',
            label: 'capture',
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'xyz');
    await tester.pump();
    expect(find.byType(ActionChip), findsOneWidget);
    expect(find.text('xyz'), findsOneWidget);
  });

  testWidgets('320 dp width at textScaler 2.0 does not overflow', (
    tester,
  ) async {
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
              child: CaptureBar(
                now: now,
                locale: CaptureLocale.en,
                hintText: 'hint',
                label: 'capture',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'call dentist tomorrow 3pm');
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}

bool _focusHasFocus(WidgetTester tester) {
  final tf = tester.widget<TextField>(find.byType(TextField));
  return tf.focusNode?.hasFocus ?? false;
}
