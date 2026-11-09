import 'package:drift/native.dart';
import 'package:ephemeron/core/db/db_provider.dart';
import 'package:ephemeron/data/drift/app_database.dart';
import 'package:ephemeron/data/repositories/event_repository.dart';
import 'package:ephemeron/data/repositories/note_repository.dart';
import 'package:ephemeron/data/repositories/occurrence_repository.dart';
import 'package:ephemeron/features/notes/presentation/markdown_editing_controller.dart';
import 'package:ephemeron/features/notes/presentation/markdown_preview.dart';
import 'package:ephemeron/features/notes/presentation/note_editor_screen.dart';
import 'package:ephemeron/features/settings/application/settings_providers.dart';
import 'package:ephemeron/features/settings/data/settings_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

List<TextSpan> _flatten(TextSpan span) {
  final out = <TextSpan>[];
  void walk(InlineSpan node) {
    if (node is TextSpan) {
      if (node.text != null) out.add(node);
      for (final child in node.children ?? const <InlineSpan>[]) {
        walk(child);
      }
    }
  }

  walk(span);
  return out;
}

void main() {
  testWidgets('opens in Read mode and edits one inline-styled body field', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = NoteRepository(db, attachmentDir: null);
    final id = await repo.createNote(
      title: 'Read me',
      body: '# Heading\n\nHello **world**',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          settingsRepositoryProvider.overrideWith(
            (ref) async => SettingsRepository(prefs),
          ),
        ],
        child: MaterialApp(home: NoteEditorScreen(noteId: id)),
      ),
    );
    await tester.pumpAndSettle();

    // Read mode renders the body and shows the title as a heading.
    expect(find.text('Read me'), findsOneWidget);
    expect(find.byType(MarkdownPreview), findsOneWidget);
    expect(find.text('Heading'), findsOneWidget);
    expect(find.byTooltip('Edit'), findsOneWidget);
    expect(find.byKey(const Key('note-body')), findsNothing);

    await tester.tap(find.byTooltip('Edit'));
    await tester.pump();

    expect(find.byTooltip('Read'), findsOneWidget);
    expect(find.byKey(const Key('note-title')), findsOneWidget);
    final body = find.byKey(const Key('note-body'));
    expect(body, findsOneWidget);
    // Edit mode is one field; the old split preview pane is gone.
    expect(find.byKey(const Key('note-live-preview')), findsNothing);
    expect(find.byType(MarkdownPreview), findsNothing);

    await tester.enterText(body, '# Live\n\nTyped **now**');
    await tester.pump();

    final field = tester.widget<TextField>(body);
    expect(field.controller, isA<MarkdownEditingController>());
    expect(field.keyboardType, TextInputType.multiline);
    expect(field.textInputAction, TextInputAction.newline);
    final controller = field.controller! as MarkdownEditingController;
    final span = controller.buildTextSpan(
      context: tester.element(body),
      style: DefaultTextStyle.of(tester.element(body)).style,
      withComposing: false,
    );
    expect(_flatten(span).map((s) => s.text).join(), controller.text);
    expect(
      _flatten(
        span,
      ).any((s) => s.text == 'now' && s.style?.fontWeight == FontWeight.bold),
      isTrue,
    );

    await tester.tap(find.byTooltip('Read'));
    await tester.pump();
    expect(find.byTooltip('Edit'), findsOneWidget);
    expect(find.byType(MarkdownPreview), findsOneWidget);
    expect(find.byKey(const Key('note-body')), findsNothing);

    // Autosave flushes the latest text; leaving the screen also flushes.
    await tester.pump(const Duration(seconds: 1));
    final saved = await repo.getNote(id);
    expect(saved!.body, contains('Typed **now**'));

    await tester.pumpWidget(Container());
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('typing then back saves and closes exactly once', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = NoteRepository(db, attachmentDir: null);
    final id = await repo.createNote(title: 'Back test');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          settingsRepositoryProvider.overrideWith(
            (ref) async => SettingsRepository(prefs),
          ),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => NoteEditorScreen(noteId: id),
                    ),
                  ),
                  child: const Text('Open note'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open note'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Edit'));
    await tester.pump();

    await tester.enterText(
      find.byKey(const Key('note-body')),
      'Saved on the way out',
    );
    await tester.pump();

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('Open note'), findsOneWidget);
    expect(find.byType(NoteEditorScreen), findsNothing);
    final saved = await repo.getNote(id);
    expect(saved!.body, 'Saved on the way out');

    await tester.pumpWidget(Container());
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('shows a missing linked event indicator for a deleted event', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = NoteRepository(db, attachmentDir: null);
    final events = EventRepository(db, OccurrenceRepository(db));
    final calendar = await events.createCalendar('C');
    final eventId = await events.createEvent(
      calendarId: calendar,
      title: 'Meeting',
    );
    final id = await repo.createNote(
      title: 'Prep',
      body: 'notes',
      linkedEventId: eventId,
    );
    await events.deleteEvent(eventId);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          settingsRepositoryProvider.overrideWith(
            (ref) async => SettingsRepository(prefs),
          ),
        ],
        child: MaterialApp(home: NoteEditorScreen(noteId: id)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Linked event not found'), findsOneWidget);
    expect(find.byKey(const Key('linked-event-missing')), findsOneWidget);

    await tester.pumpWidget(Container());
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('preview keeps single and hard line breaks', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MarkdownPreview(body: 'alpha\nbeta\n\ngamma  \ndelta'),
        ),
      ),
    );
    final paragraphs = find.descendant(
      of: find.byType(MarkdownPreview),
      matching: find.byType(RichText),
    );
    expect(paragraphs, findsNWidgets(2));
    expect(
      tester
          .widgetList<RichText>(paragraphs)
          .map((r) => r.text.toPlainText())
          .toList(),
      ['alpha\nbeta', 'gamma\ndelta'],
    );
    // Two rendered lines per paragraph, not one collapsed line.
    expect(tester.getSize(paragraphs.at(0)).height, greaterThan(24));
    expect(tester.getSize(paragraphs.at(1)).height, greaterThan(24));
  });

  testWidgets('preview normalizes CRLF/CR and keeps backslash breaks', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MarkdownPreview(body: 'one\r\ntwo\rthree\\\nfour'),
        ),
      ),
    );
    final paragraphs = find.descendant(
      of: find.byType(MarkdownPreview),
      matching: find.byType(RichText),
    );
    expect(paragraphs, findsOneWidget);
    expect(
      tester.widget<RichText>(paragraphs).text.toPlainText(),
      'one\ntwo\nthree\nfour',
    );
  });

  testWidgets('typed single newlines render as line breaks in Read mode', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = NoteRepository(db, attachmentDir: null);
    final id = await repo.createNote(title: 'Breaks');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          settingsRepositoryProvider.overrideWith(
            (ref) async => SettingsRepository(prefs),
          ),
        ],
        child: MaterialApp(home: NoteEditorScreen(noteId: id)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Edit'));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('note-body')),
      'first line\nsecond line',
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Read'));
    await tester.pump();

    final paragraphs = find.descendant(
      of: find.byType(MarkdownPreview),
      matching: find.byType(RichText),
    );
    expect(paragraphs, findsOneWidget);
    final text = tester.widget<RichText>(paragraphs).text.toPlainText();
    expect(text, 'first line\nsecond line');
    // Two rendered lines, not one collapsed line.
    expect(tester.getSize(paragraphs).height, greaterThan(24));

    await tester.pump(const Duration(seconds: 1));
    final saved = await repo.getNote(id);
    expect(saved!.body, 'first line\nsecond line');

    await tester.pumpWidget(Container());
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('preview keeps paragraphs, list items and bold on new lines', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MarkdownPreview(
            body:
                'alpha\nbeta\n\n- one\n  continued\n- two\n\n'
                '**bold one\nbold two**',
          ),
        ),
      ),
    );
    final richTexts = tester
        .widgetList<RichText>(
          find.descendant(
            of: find.byType(MarkdownPreview),
            matching: find.byType(RichText),
          ),
        )
        .map((r) => r.text.toPlainText())
        .toList();
    expect(richTexts, contains('alpha\nbeta'));
    expect(richTexts, contains('bold one\nbold two'));
    expect(find.text('- one\ncontinued'), findsOneWidget);
    expect(find.text('- two'), findsOneWidget);
  });

  testWidgets('preview normalizes Unicode line and paragraph separators', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: MarkdownPreview(body: 'one\u2028two\u2029three')),
      ),
    );
    final paragraph = find.descendant(
      of: find.byType(MarkdownPreview),
      matching: find.byType(RichText),
    );
    expect(paragraph, findsOneWidget);
    expect(
      tester.widget<RichText>(paragraph).text.toPlainText(),
      'one\ntwo\nthree',
    );
  });

  testWidgets('preview leaves fenced code blocks unchanged', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MarkdownPreview(
            body: 'before\n\n```dart\nline one\nline two\n```\n\nafter',
          ),
        ),
      ),
    );
    final code = tester
        .widgetList<Text>(
          find.descendant(
            of: find.byType(MarkdownPreview),
            matching: find.byType(Text),
          ),
        )
        .map((t) => t.data)
        .whereType<String>()
        .firstWhere((t) => t.contains('line one'));
    expect(code, contains('line one\nline two'));
    expect(code, isNot(contains('line one  ')));
    expect(code, isNot(contains('line two  ')));
  });
}
