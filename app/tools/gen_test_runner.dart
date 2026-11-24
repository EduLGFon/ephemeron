// Generates four parallel test entrypoints: test/shard{0,1,2,3}_test.dart.
//
// Why shards: `flutter test` only parallelizes across test files, and its
// default concurrency is CPUs/2. A single entrypoint wastes the other cores.
// Four contiguous, cost-balanced entrypoints let every core run cases at once
// while still paying only one kernel compile per entrypoint.
//
// Run from app/: dart run tools/gen_test_runner.dart
import 'dart:io';

const _casesDir = 'test/cases';
const _testDir = 'test';
const _shardCount = 4;
const _legacyRunner = 'test/all_test.dart';

// TODO: Remove when wheel_picker_test.dart is registered as a case under
// test/cases.
const _temporarilyAllowedStrayEntrypoints = <String>{
  'test/wheel_picker_test.dart',
};

void main() {
  final files =
      Directory(_casesDir)
          .listSync()
          .whereType<File>()
          .map((f) => f.uri.pathSegments.last)
          .where((name) => name.endsWith('_case.dart'))
          .toList()
        ..sort();
  if (files.isEmpty) {
    stderr.writeln('No *_case.dart files found in $_casesDir.');
    exit(1);
  }

  final shards = _balancedShards(files);
  for (var i = 0; i < _shardCount; i++) {
    _writeShard(index: i, shard: shards[i], allCases: files);
  }

  // Generated import lines exceed the formatter's line limit, so format the
  // entrypoints here: `dart format --set-exit-if-changed` must pass right after
  // regeneration without requiring a separate manual step.
  final formatted = Process.runSync(Platform.resolvedExecutable, [
    'format',
    for (var i = 0; i < _shardCount; i++) '$_testDir/shard${i}_test.dart',
  ]);
  if (formatted.exitCode != 0) {
    stderr.writeln(formatted.stderr);
    exit(formatted.exitCode);
  }

  // The old single entrypoint must not survive regeneration: `flutter test`
  // would discover it alongside the shards and run every case twice.
  final legacy = File(_legacyRunner);
  if (legacy.existsSync()) legacy.deleteSync();

  stdout.writeln('Wrote $_shardCount shard runners for ${files.length} cases.');
}

/// Splits the sorted files into [_shardCount] contiguous ranges whose
/// estimated costs are as close as possible, walking left to right.
List<List<String>> _balancedShards(List<String> files) {
  final cost = {for (final file in files) file: _cost(file)};
  final total = cost.values.fold<int>(0, (sum, value) => sum + value);
  final target = total / _shardCount;
  final shards = List.generate(_shardCount, (_) => <String>[]);

  var index = 0;
  var sum = 0;
  for (final file in files) {
    final value = cost[file]!;
    final canSplit = index < _shardCount - 1 && shards[index].isNotEmpty;
    if (canSplit && (sum + value - target).abs() > (sum - target).abs()) {
      index++;
      sum = 0;
    }
    shards[index].add(file);
    sum += value;
  }
  return shards;
}

/// Cheap proxy for case runtime: widget tests cost more than plain tests.
int _cost(String fileName) {
  final source = File('$_casesDir/$fileName').readAsStringSync();
  return RegExp(r'\btestWidgets\s*\(').allMatches(source).length * 3 +
      RegExp(r'\btest\s*\(').allMatches(source).length;
}

void _writeShard({
  required int index,
  required List<String> shard,
  required List<String> allCases,
}) {
  final out = StringBuffer()
    ..writeln('// GENERATED CODE - DO NOT MODIFY BY HAND.')
    ..writeln('// Run: dart run tools/gen_test_runner.dart')
    ..writeln('//')
    ..writeln('// Shard $index of $_shardCount. Each shard owns a contiguous')
    ..writeln('// range of cases and pays one kernel compile.')
    ..writeln("import 'dart:io';")
    ..writeln()
    ..writeln("import 'package:flutter_test/flutter_test.dart';")
    ..writeln();

  for (final name in shard) {
    out.writeln("import 'cases/$name' as ${_alias(name)};");
  }

  // Every shard carries the full manifest so the stale-runner guard holds
  // even when a single shard is executed on its own.
  out
    ..writeln()
    ..writeln('const _allCases = <String>{');
  for (final name in allCases) {
    out.writeln("  '$name',");
  }
  out
    ..writeln('};')
    ..writeln()
    ..writeln('void main() {')
    ..writeln("  test('test runner includes every case file', () {")
    ..writeln('    expect(_caseFilesOnDisk(), _allCases,')
    ..writeln("        reason: 'test runners are stale. Run: '")
    ..writeln("            'dart run tools/gen_test_runner.dart');")
    ..writeln('  });')
    ..writeln();

  for (final name in shard) {
    out.writeln("  group('${_alias(name)}', ${_alias(name)}.main);");
  }

  out
    ..writeln('}')
    ..writeln()
    ..writeln('Set<String> _caseFilesOnDisk() {')
    ..writeln('  _checkNoStrayEntrypoints();')
    ..writeln("  return Directory('$_casesDir')")
    ..writeln('      .listSync()')
    ..writeln('      .whereType<File>()')
    ..writeln('      .map((f) => f.uri.pathSegments.last)')
    ..writeln("      .where((name) => name.endsWith('_case.dart'))")
    ..writeln('      .toSet();')
    ..writeln('}')
    ..writeln()
    ..writeln(
      '// TODO: Remove when wheel_picker_test.dart is registered as a case under',
    )
    ..writeln('// test/cases.')
    ..writeln('const _temporarilyAllowedStrayEntrypoints = <String>{');
  for (final path in _temporarilyAllowedStrayEntrypoints) {
    out.writeln("  '$path',");
  }
  out
    ..writeln('};')
    ..writeln()
    ..writeln('void _checkNoStrayEntrypoints() {')
    ..writeln("  final shard = RegExp(r'^test/shard[0-9]+_test\\.dart\$');")
    ..writeln("  final stray = Directory('$_testDir')")
    ..writeln('      .listSync(recursive: true)')
    ..writeln('      .whereType<File>()')
    ..writeln("      .map((f) => f.path.replaceAll(r'\\', '/'))")
    ..writeln("      .where((path) => path.endsWith('_test.dart'))")
    ..writeln('      .where((path) => !shard.hasMatch(path))')
    ..writeln(
      '      .where((path) => !_temporarilyAllowedStrayEntrypoints.contains(path))',
    )
    ..writeln('      .toSet();')
    ..writeln('  expect(stray, isEmpty,')
    ..writeln("      reason: 'Move top-level test files under test/cases/ as '")
    ..writeln("          '*_case.dart and regenerate the test runners.');")
    ..writeln('}');

  File('$_testDir/shard${index}_test.dart').writeAsStringSync(out.toString());
}

String _alias(String fileName) =>
    fileName.substring(0, fileName.length - '_case.dart'.length);
