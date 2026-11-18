// User-visible copy for global search. English only for now; localized title,
// hint and scope labels stay in the shared ARB files because existing tests
// and the locale switch depend on them.
import 'package:material_ui/material_ui.dart';

class SearchStrings {
  const SearchStrings._(this.localeCode);

  final String localeCode;

  static SearchStrings of(BuildContext context) =>
      SearchStrings._(Localizations.localeOf(context).languageCode);

  String get back => 'Back';

  String get examplesIntro => 'Try one of these searches:';

  List<String> get examples => const ['milk', 'meeting', 'gym'];

  String get searchFailedTitle => 'Search failed';

  String get searchFailedMessage => 'Some results could not be loaded.';

  String get retry => 'Retry';

  String get noResults => 'No results';

  String nothingMatched(String query) => 'Nothing matched "$query".';

  String get clearSearch => 'Clear search';

  String groupFailed(String group) => '$group failed to load';

  String get noOpenTasks => 'No open tasks';

  String get couldNotLoadTasks => 'Could not load tasks';

  String tagTaskCap(int limit) => 'Showing the first $limit open tasks';

  String get noTitle => '(no title)';

  String get listColor => 'List color';
}
