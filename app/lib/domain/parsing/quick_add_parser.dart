// Quick-add shorthand parser. Pure Dart.
// Shorthands: #tag, ~list, -p1..-p4. Quoted names (#"my tag",
// ~"My List") preserve spaces. Remainder goes through natural parsing.
import 'natural_date_parser.dart';

class QuickAddParsed {
  QuickAddParsed({
    required this.title,
    required this.tags,
    this.list,
    this.priority = 0,
    this.due,
    this.rrule,
  });

  final String title;
  final List<String> tags;
  final String? list;
  final int priority;
  final DateTime? due;
  final String? rrule;
}

QuickAddParsed parseQuickAdd(String input, {DateTime? now}) {
  var working = ' $input ';
  final tags = <String>[];
  final tagPattern = RegExp(r'#(?:"([^"]+)"|([\p{L}\p{N}_-]+))', unicode: true);
  for (final m in tagPattern.allMatches(working)) {
    tags.add((m.group(1) ?? m.group(2)!).toLowerCase());
  }
  working = working.replaceAll(tagPattern, ' ');

  String? list;
  final listPattern = RegExp(
    r'~(?:"([^"]+)"|([\p{L}\p{N}_-]+))',
    unicode: true,
  );
  final listM = listPattern.firstMatch(working);
  if (listM != null) {
    list = listM.group(1) ?? listM.group(2)!;
    working = working.replaceFirst(listM.group(0)!, ' ');
  }

  var priority = 0;
  final priM = RegExp(r'-p([1-4])').firstMatch(working);
  if (priM != null) {
    // -p1 is highest urgency -> priority 4 .. -p4 -> priority 1.
    priority = 5 - int.parse(priM.group(1)!);
    working = working.replaceFirst(priM.group(0)!, ' ');
  }

  final natural = parseNatural(working, now: now);
  return QuickAddParsed(
    title: natural.title,
    tags: tags,
    list: list,
    priority: priority,
    due: natural.due,
    rrule: natural.rrule,
  );
}
