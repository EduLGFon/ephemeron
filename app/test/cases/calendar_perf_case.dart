// Calendar cache range: coverage checks and provider stability while
// navigating inside an already materialized range.
import 'package:ephemeron/features/calendar/application/calendar_providers.dart';
import 'package:ephemeron/features/calendar/application/calendar_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('range coverage includes fully contained windows', () {
    final built = CalendarRange(
      fromUtc: DateTime.utc(2026, 3, 1),
      toUtc: DateTime.utc(2026, 3, 10),
    );
    final inside = CalendarRange(
      fromUtc: DateTime.utc(2026, 3, 2),
      toUtc: DateTime.utc(2026, 3, 9),
    );
    final edge = CalendarRange(
      fromUtc: DateTime.utc(2026, 3, 1),
      toUtc: DateTime.utc(2026, 3, 10),
    );
    final outside = CalendarRange(
      fromUtc: DateTime.utc(2026, 3, 2),
      toUtc: DateTime.utc(2026, 3, 11),
    );

    expect(built.covers(inside), isTrue);
    expect(built.covers(edge), isTrue);
    expect(built.covers(outside), isFalse);
  });

  test(
    'agenda visible range starts at the anchor with a past cache buffer',
    () {
      final window = CalendarWindow(
        anchor: DateTime(2026, 11, 9),
        view: CalendarViewKind.agenda,
      );

      expect(window.visibleRange.fromUtc, DateTime.utc(2026, 11, 9));
      expect(window.visibleRange.toUtc, DateTime.utc(2027, 2, 7));
      expect(window.cacheRange.fromUtc, DateTime.utc(2026, 10, 10));
      expect(window.cacheRange.toUtc, DateTime.utc(2027, 2, 7));
    },
  );

  test('restored windows clamp their anchor only when today is hidden', () {
    final now = DateTime(2026, 11, 9, 15, 30);
    DateTime clamp(CalendarViewKind view, DateTime anchor, {int dayCount = 1}) {
      return calendarAnchorShowingToday(
        CalendarWindow(anchor: anchor, view: view, dayCount: dayCount),
        now,
      );
    }

    expect(
      clamp(CalendarViewKind.month, DateTime(2026, 3, 10)),
      DateTime(2026, 11, 9),
    );
    expect(
      clamp(CalendarViewKind.month, DateTime(2026, 11, 2)),
      DateTime(2026, 11, 2),
    );
    expect(
      clamp(CalendarViewKind.year, DateTime(2025, 1, 1)),
      DateTime(2026, 11, 9),
    );
    expect(
      clamp(CalendarViewKind.year, DateTime(2026, 1, 1)),
      DateTime(2026, 1, 1),
    );
    expect(
      clamp(CalendarViewKind.day, DateTime(2026, 11, 8)),
      DateTime(2026, 11, 9),
    );
    expect(
      clamp(CalendarViewKind.day, DateTime(2026, 11, 10)),
      DateTime(2026, 11, 9),
    );
    expect(
      clamp(CalendarViewKind.multiDay, DateTime(2026, 11, 6), dayCount: 7),
      DateTime(2026, 11, 6),
    );
    expect(
      clamp(CalendarViewKind.multiDay, DateTime(2026, 11, 10), dayCount: 7),
      DateTime(2026, 11, 9),
    );
    // Agenda starts at today: a past anchor moves forward even though today
    // is inside its forward window, and a future anchor also moves back.
    expect(
      clamp(CalendarViewKind.agenda, DateTime(2026, 10, 1)),
      DateTime(2026, 11, 9),
    );
    expect(
      clamp(CalendarViewKind.agenda, DateTime(2026, 2, 1)),
      DateTime(2026, 11, 9),
    );
    expect(
      clamp(CalendarViewKind.agenda, DateTime(2026, 11, 9)),
      DateTime(2026, 11, 9),
    );
    expect(
      clamp(CalendarViewKind.agenda, DateTime(2026, 11, 10)),
      DateTime(2026, 11, 9),
    );
  });

  test('selecting another day in the month view keeps the cache range', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(calendarStateProvider.notifier);
    notifier.restore(CalendarViewKind.month, DateTime(2026, 3, 10));
    final before = container.read(calendarCacheRangeProvider);
    var changes = 0;
    container.listen(calendarCacheRangeProvider, (_, _) => changes++);

    notifier.goTo(DateTime(2026, 3, 18));

    expect(container.read(calendarCacheRangeProvider), before);
    expect(changes, 0);
  });

  test('day swipes inside the buffer keep the cache range', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(calendarStateProvider.notifier);
    notifier.restore(CalendarViewKind.day, DateTime(2026, 3, 10));
    final before = container.read(calendarCacheRangeProvider);
    var changes = 0;
    container.listen(calendarCacheRangeProvider, (_, _) => changes++);

    notifier.shift(calendarDayBufferDays);
    expect(container.read(calendarCacheRangeProvider), before);
    expect(changes, 0);

    // One more day falls outside the built range and must request a rebuild.
    notifier.shift(1);
    expect(container.read(calendarCacheRangeProvider), isNot(before));
    expect(changes, 1);
  });
}
