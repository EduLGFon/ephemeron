import 'package:drift/native.dart';
import 'package:ephemeron/core/db/db_provider.dart';
import 'package:ephemeron/core/design/components/app_fields.dart';
import 'package:ephemeron/core/design/components/app_headers.dart';
import 'package:ephemeron/data/drift/app_database.dart';
import 'package:ephemeron/features/auth/application/auth_providers.dart';
import 'package:ephemeron/features/auth/data/backend_auth.dart';
import 'package:ephemeron/features/auth/presentation/auth_screen.dart';
import 'package:ephemeron/features/notes/presentation/note_editor_screen.dart';
import 'package:ephemeron/features/notes/presentation/notes_screen.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'backend_auth_case.dart' show FakeBackend, MemoryTokenStore;

void main() {
  group('savedAgeLabel', () {
    final now = DateTime(2026, 1, 1, 12);

    test('uses calm wording under a minute', () {
      expect(savedAgeLabel(now, now: now), 'Saved just now');
      expect(
        savedAgeLabel(now.subtract(const Duration(seconds: 59)), now: now),
        'Saved just now',
      );
    });

    test('counts minutes, hours and days', () {
      expect(
        savedAgeLabel(now.subtract(const Duration(minutes: 1)), now: now),
        'Saved 1m ago',
      );
      expect(
        savedAgeLabel(now.subtract(const Duration(minutes: 42)), now: now),
        'Saved 42m ago',
      );
      expect(
        savedAgeLabel(now.subtract(const Duration(hours: 3)), now: now),
        'Saved 3h ago',
      );
      expect(
        savedAgeLabel(now.subtract(const Duration(days: 2)), now: now),
        'Saved 2d ago',
      );
    });
  });

  group('highlightSnippetSpans', () {
    const baseStyle = TextStyle(color: Colors.black);
    const highlight = Colors.blue;

    test('highlights real query hits case-insensitively', () {
      final spans = highlightSnippetSpans(
        'Alpha beta GAMMA beta',
        query: 'beta',
        baseStyle: baseStyle,
        highlightColor: highlight,
      );

      expect(spans.map((s) => s.text).toList(), [
        'Alpha ',
        'beta',
        ' GAMMA ',
        'beta',
      ]);
      expect(spans[0].style?.color, Colors.black);
      expect(spans[1].style?.fontWeight, FontWeight.bold);
      expect(spans[1].style?.color, highlight);
      expect(spans[3].style?.fontWeight, FontWeight.bold);
    });

    test('preserves literal markup and text around hits', () {
      const snippet = 'literal <b>tag</b> and Beta';
      final spans = highlightSnippetSpans(
        snippet,
        query: 'beta',
        baseStyle: baseStyle,
        highlightColor: highlight,
      );

      expect(spans.map((s) => s.text).join(), snippet);
      expect(spans.first.text, 'literal <b>tag</b> and ');
      expect(spans.last.text, 'Beta');
      expect(spans.last.style?.fontWeight, FontWeight.bold);
    });

    test('returns the snippet unchanged without a hit', () {
      final spans = highlightSnippetSpans(
        'plain snippet',
        query: 'missing',
        baseStyle: baseStyle,
        highlightColor: highlight,
      );

      expect(spans, hasLength(1));
      expect(spans.single.text, 'plain snippet');
      expect(spans.single.style?.fontWeight, isNot(FontWeight.bold));
    });
  });

  testWidgets('notes home exposes header actions and empty state', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: NotesScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();

    expect(find.text('Notes'), findsOneWidget);
    expect(find.byTooltip('Search'), findsOneWidget);
    expect(find.byTooltip('New note'), findsOneWidget);
    expect(find.byTooltip('New folder'), findsOneWidget);
    expect(find.byTooltip('Trash'), findsOneWidget);
    expect(find.byTooltip('List view'), findsOneWidget);
    expect(find.text('All notes'), findsOneWidget);
    expect(find.text('No notes here'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await db.close();
    await tester.pumpWidget(Container());
    await tester.pump();
  });

  testWidgets('notes search is a title-row button with no inline field', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: NotesScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();

    expect(
      find.descendant(
        of: find.byType(AppPageHeader),
        matching: find.byTooltip('Search'),
      ),
      findsOneWidget,
    );
    expect(find.byType(AppSearchField), findsNothing);
    expect(find.byKey(const Key('notes-search-field')), findsNothing);
    expect(tester.takeException(), isNull);

    await db.close();
    await tester.pumpWidget(Container());
    await tester.pump();
  });

  testWidgets('password visibility toggle updates the obscure flag', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final auth = BackendAuth(
      client: FakeBackend(),
      tokenStore: MemoryTokenStore(),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          backendAuthProvider.overrideWithValue(auth),
        ],
        child: const MaterialApp(home: AuthScreen()),
      ),
    );
    await tester.pump();

    final password = find.widgetWithText(TextField, 'Password (8+ characters)');
    expect(tester.widget<TextField>(password).obscureText, isTrue);
    expect(find.byTooltip('Show password'), findsOneWidget);

    await tester.tap(find.byKey(const Key('password-visibility-toggle')));
    await tester.pump();

    expect(tester.widget<TextField>(password).obscureText, isFalse);
    expect(find.byTooltip('Hide password'), findsOneWidget);

    await tester.tap(find.byKey(const Key('password-visibility-toggle')));
    await tester.pump();
    expect(tester.widget<TextField>(password).obscureText, isTrue);

    await db.close();
    await tester.pumpWidget(Container());
    await tester.pump();
  });
}
