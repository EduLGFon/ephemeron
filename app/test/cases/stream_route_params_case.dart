import 'package:ephemeron/features/stream/presentation/stream_route_params.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  DateTime clock() => DateTime(2026, 11, 16);

  test('valid date and zoom', () {
    final p = parseStreamRouteParams(date: '2026-01-02', zoom: 'day');
    expect(formatStreamDate(p.date), '2026-01-02');
    expect(p.zoom, 'day');
  });

  test('invalid date falls back to today', () {
    final p = parseStreamRouteParams(date: 'not-a-date', clock: clock);
    expect(formatStreamDate(p.date), '2026-11-16');
    expect(p.zoom, 'day');
  });

  test('invalid zoom falls back to day', () {
    final p = parseStreamRouteParams(
      date: '2026-01-02',
      zoom: 'hour',
      clock: clock,
    );
    expect(formatStreamDate(p.date), '2026-01-02');
    expect(p.zoom, 'day');
  });

  test('missing values fall back', () {
    final p = parseStreamRouteParams(clock: clock);
    expect(formatStreamDate(p.date), '2026-11-16');
    expect(p.zoom, 'day');
  });

  test('injected DateTime argument', () {
    final p = parseStreamRouteParams(date: 'bad', now: DateTime(2025, 1, 1));
    expect(formatStreamDate(p.date), '2025-01-01');
  });

  final cases = <(String?, String?, String, String)>[
    ('2026-12-31', 'day', '2026-12-31', 'day'),
    (null, null, '2026-11-16', 'day'),
    ('2026-13-40', 'nope', '2026-11-16', 'day'),
  ];
  for (final c in cases) {
    test('table ${c.$1} ${c.$2}', () {
      final p = parseStreamRouteParams(date: c.$1, zoom: c.$2, clock: clock);
      expect(formatStreamDate(p.date), c.$3);
      expect(p.zoom, c.$4);
    });
  }
}
