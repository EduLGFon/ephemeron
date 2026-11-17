import 'package:ephemeron/features/stream/presentation/commands/fuzzy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('exact match ranks first', () {
    final r = fuzzyRank<String>('abc', ['xabc', 'abc', 'zzz'], (s) => s);
    expect(r.first, 'abc');
  });

  test('prefix ranks above mid-word', () {
    final r = fuzzyRank<String>('ab', ['xab', 'abc'], (s) => s);
    expect(r.first, 'abc');
  });

  test('no match excluded', () {
    final r = fuzzyRank<String>('zzz', ['abc', 'def'], (s) => s);
    expect(r, isEmpty);
  });

  test('stable order equal scores', () {
    final r = fuzzyRank<String>('a', ['a1', 'a2'], (s) => s);
    expect(r, ['a1', 'a2']);
  });

  test('case insensitive', () {
    final r = fuzzyRank<String>('ABC', ['abc', 'ABC'], (s) => s);
    expect(r.length, 2);
  });

  test('empty query returns all', () {
    final r = fuzzyRank<String>('', ['b', 'a'], (s) => s);
    expect(r, ['b', 'a']);
  });

  test('consecutive bonus', () {
    expect(fuzzyScore('ab', 'ab'), greaterThan(fuzzyScore('ab', 'a b')));
  });

  test('word start bonus', () {
    expect(fuzzyScore('ab', 'a-b'), greaterThan(0));
  });

  test('subsequence match', () {
    expect(fuzzyScore('ac', 'abc'), greaterThan(0));
  });

  test('no match -1', () {
    expect(fuzzyScore('z', 'abc'), -1);
  });

  test('prefix bonus', () {
    expect(fuzzyScore('ab', 'abc'), greaterThan(fuzzyScore('ab', 'xab')));
  });

  test('stable with three equal', () {
    final r = fuzzyRank<int>('i', [1, 2, 3], (n) => 'item');
    expect(r, [1, 2, 3]);
  });
}
