import 'package:ephemeron/features/search/presentation/search_screen.dart';
import 'package:ephemeron/features/settings/data/settings_repository.dart';
import 'package:ephemeron/l10n/src/app_localizations.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/test_fixtures.dart';

void main() {
  testWidgets('search screen localizes titles', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    for (final entry in {'en': 'Search', 'pt': 'Buscar'}.entries) {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            locale: Locale(entry.key),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              ...GlobalMaterialLocalizations.delegates,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: const SearchScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text(entry.value), findsOneWidget);
    }
    await tester.pumpWidget(const SizedBox.shrink());
    await settle(tester);
  });

  test('locale code defaults to system and persists', () async {
    SharedPreferences.setMockInitialValues({});
    final repo = SettingsRepository(await SharedPreferences.getInstance());
    expect(repo.localeCode, 'system');
    await repo.setLocaleCode('pt');
    expect(repo.localeCode, 'pt');
  });
}
