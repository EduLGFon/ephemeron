import 'package:ephemeron/features/stream/presentation/commands/command_parser.dart';
import 'package:ephemeron/features/stream/presentation/commands/command_request.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 11, 16);

  test('empty string -> none', () {
    final r = parseCommand('', now: now);
    expect(r.kind, CommandKind.none);
  });

  test('whitespace -> none', () {
    final r = parseCommand('   ', now: now);
    expect(r.kind, CommandKind.none);
  });

  test('> prefix go to date', () {
    final r = parseCommand('> go to 2026-12-01', now: now);
    expect(r.kind, CommandKind.goToDate);
    expect(r.date, DateTime(2026, 12, 1));
  });

  test('case insensitive ZOOM', () {
    final r = parseCommand('ZOOM Week', now: now);
    expect(r.kind, CommandKind.zoom);
    expect(r.level, 'week');
  });

  test('go to today', () {
    final r = parseCommand('go to today', now: now);
    expect(r.kind, CommandKind.goToDate);
    expect(r.date, DateTime(2026, 11, 16));
  });

  test('go to tomorrow', () {
    final r = parseCommand('go to tomorrow', now: now);
    expect(r.kind, CommandKind.goToDate);
    expect(r.date, DateTime(2026, 11, 17));
  });

  test('go to weekday', () {
    final r = parseCommand('go to monday', now: now);
    expect(r.kind, CommandKind.goToDate);
    expect(r.date!.weekday, DateTime.monday);
  });

  test('bad date -> unknown', () {
    final r = parseCommand('go to 2026-13-40', now: now);
    expect(r.kind, CommandKind.unknown);
  });

  test('zoom hour', () {
    final r = parseCommand('zoom hour', now: now);
    expect(r.kind, CommandKind.zoom);
    expect(r.level, 'hour');
  });

  test('focus minutes', () {
    final r = parseCommand('focus 25', now: now);
    expect(r.kind, CommandKind.startFocus);
    expect(r.minutes, 25);
  });

  test('focus 0', () {
    final r = parseCommand('focus 0', now: now);
    expect(r.kind, CommandKind.startFocus);
    expect(r.minutes, 0);
  });

  test('focus 999', () {
    final r = parseCommand('focus 999', now: now);
    expect(r.kind, CommandKind.startFocus);
    expect(r.minutes, 999);
  });

  test('start focus', () {
    final r = parseCommand('start focus 10', now: now);
    expect(r.kind, CommandKind.startFocus);
    expect(r.minutes, 10);
  });

  test('complete title', () {
    final r = parseCommand('complete Buy milk', now: now);
    expect(r.kind, CommandKind.complete);
    expect(r.title, 'Buy milk');
  });

  test('search text', () {
    final r = parseCommand('search dentist', now: now);
    expect(r.kind, CommandKind.search);
    expect(r.text, 'dentist');
  });

  test('bare agenda', () {
    final r = parseCommand('agenda', now: now);
    expect(r.kind, CommandKind.agenda);
  });

  test('settings', () {
    final r = parseCommand('settings', now: now);
    expect(r.kind, CommandKind.settings);
  });

  test('sync now', () {
    final r = parseCommand('sync now', now: now);
    expect(r.kind, CommandKind.syncNow);
  });

  test('sync', () {
    final r = parseCommand('sync', now: now);
    expect(r.kind, CommandKind.syncNow);
  });

  test('theme dark', () {
    final r = parseCommand('theme dark', now: now);
    expect(r.kind, CommandKind.theme);
    expect(r.mode, 'dark');
  });

  test('help', () {
    final r = parseCommand('help', now: now);
    expect(r.kind, CommandKind.help);
  });

  test('unknown', () {
    final r = parseCommand('xyz foo', now: now);
    expect(r.kind, CommandKind.unknown);
    expect(r.raw, 'xyz foo');
  });

  test('extra whitespace', () {
    final r = parseCommand('  agenda  ', now: now);
    expect(r.kind, CommandKind.agenda);
  });

  test('pt ir para', () {
    final r = parseCommand(
      'ir para hoje',
      now: now,
      locale: StreamLocaleOrModeResolver.pt,
    );
    expect(r.kind, CommandKind.goToDate);
  });

  test('pt focar', () {
    final r = parseCommand(
      'focar 15',
      now: now,
      locale: StreamLocaleOrModeResolver.pt,
    );
    expect(r.kind, CommandKind.startFocus);
    expect(r.minutes, 15);
  });

  test('pt tema', () {
    final r = parseCommand(
      'tema light',
      now: now,
      locale: StreamLocaleOrModeResolver.pt,
    );
    expect(r.kind, CommandKind.theme);
    expect(r.mode, 'light');
  });

  test('pt ajuda', () {
    final r = parseCommand(
      'ajuda',
      now: now,
      locale: StreamLocaleOrModeResolver.pt,
    );
    expect(r.kind, CommandKind.help);
  });
}
