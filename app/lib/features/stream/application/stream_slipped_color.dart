// ARGB colour for a slipped item, matching taskListColor without importing
// presentation code from the application layer.
import '../../../core/theme/theme_tokens.dart'
    show isValidHex, parseHex, primaryPresets;
import '../../../data/drift/app_database.dart' show TaskList;

int slippedListColorArgb(TaskList? list) {
  if (list == null) return primaryPresets.first.toARGB32();
  final raw = list.color;
  if (raw != null && isValidHex(raw)) return parseHex(raw).toARGB32();
  var hash = 0;
  for (final unit in list.id.codeUnits) {
    hash = (hash * 31 + unit) & 0x7fffffff;
  }
  return primaryPresets[hash % primaryPresets.length].toARGB32();
}
