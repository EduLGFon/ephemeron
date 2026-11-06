import 'package:ephemeron/core/ui/app_sheet.dart';
import 'package:ephemeron/core/ui/dialogs.dart';
import 'package:ephemeron/core/ui/dirty_guard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget home) => MaterialApp(home: home);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('clean sheet closes without prompt', (tester) async {
    await tester.pumpWidget(
      _app(
        Scaffold(
          body: Builder(
            builder: (ctx) {
              return ElevatedButton(
                onPressed: () => showAppSheet<void>(
                  ctx,
                  builder: (sheetCtx) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ElevatedButton(
                        key: const Key('close'),
                        onPressed: () => Navigator.of(sheetCtx).pop(),
                        child: const Text('close'),
                      ),
                    ],
                  ),
                ),
                child: const Text('open'),
              );
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('close'), findsOneWidget);

    await tester.tap(find.byKey(const Key('close')));
    await tester.pumpAndSettle();
    expect(find.text('close'), findsNothing);
    expect(find.text('Unsaved changes'), findsNothing);
  });

  testWidgets('dirty sheet prompts and honors discard/cancel', (tester) async {
    await tester.pumpWidget(
      _app(
        Scaffold(
          body: Builder(
            builder: (ctx) {
              return ElevatedButton(
                onPressed: () => showAppSheet<void>(
                  ctx,
                  builder: (sheetCtx) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Builder(
                        builder: (c) => ElevatedButton(
                          key: const Key('mark'),
                          onPressed: () => DirtyGuard.of(c).markDirty(),
                          child: const Text('mark'),
                        ),
                      ),
                      Builder(
                        builder: (c) => ElevatedButton(
                          key: const Key('close'),
                          onPressed: () => Navigator.of(c).pop(),
                          child: const Text('close'),
                        ),
                      ),
                    ],
                  ),
                ),
                child: const Text('open'),
              );
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('mark')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('close')));
    await tester.pumpAndSettle();
    expect(find.text('Unsaved changes'), findsOneWidget);

    // Cancel keeps sheet open.
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Unsaved changes'), findsNothing);
    expect(find.text('close'), findsOneWidget);

    // Discard closes.
    await tester.tap(find.byKey(const Key('close')));
    await tester.pumpAndSettle();
    expect(find.text('Unsaved changes'), findsOneWidget);
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(find.text('close'), findsNothing);
  });

  testWidgets('guarded dialog prompts when dirty', (tester) async {
    var saved = false;
    await tester.pumpWidget(
      _app(
        Scaffold(
          body: Builder(
            builder: (ctx) {
              return ElevatedButton(
                onPressed: () => showGuardedDialog<void>(
                  ctx,
                  isDirty: () => true,
                  onSave: () async {
                    saved = true;
                    return true;
                  },
                  builder: (dialogCtx) => AlertDialog(
                    title: const Text('editor'),
                    actions: [
                      TextButton(
                        key: const Key('close'),
                        onPressed: () => Navigator.of(dialogCtx).pop(),
                        child: const Text('close'),
                      ),
                    ],
                  ),
                ),
                child: const Text('open'),
              );
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('editor'), findsOneWidget);

    await tester.tap(find.byKey(const Key('close')));
    await tester.pumpAndSettle();
    expect(find.text('Unsaved changes'), findsOneWidget);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(saved, isTrue);
    expect(find.text('editor'), findsNothing);
  });
}
