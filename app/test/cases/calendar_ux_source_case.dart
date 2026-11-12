import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ephemeron/features/calendar/presentation/timeline/timeline_utils.dart';
import 'package:ephemeron/features/settings/data/settings_repository.dart';

void main() {
  test('timeline selection helper: same slot is 30 minutes', () {
    final r = timelineSelectionBounds(
      anchorDay: 0,
      anchorMin: 540,
      pointerDay: 0,
      pointerMin: 540,
      stripCount: 3,
    );
    expect(r.startDay, 0);
    expect(r.startMin, 540);
    expect(r.endDay, 0);
    expect(r.endMin, 570);
  });

  test('timeline selection helper: downward 9:00 to 10:00', () {
    final r = timelineSelectionBounds(
      anchorDay: 0,
      anchorMin: 540,
      pointerDay: 0,
      pointerMin: 600,
      stripCount: 3,
    );
    expect(r.startMin, 540);
    expect(r.endMin, 630);
  });

  test('timeline selection helper: upward normalizes', () {
    final r = timelineSelectionBounds(
      anchorDay: 0,
      anchorMin: 600,
      pointerDay: 0,
      pointerMin: 540,
      stripCount: 3,
    );
    expect(r.startMin, 540);
    expect(r.endMin, 630);
  });

  test('timeline selection helper: cross-day spans', () {
    final r = timelineSelectionBounds(
      anchorDay: 0,
      anchorMin: 1380,
      pointerDay: 1,
      pointerMin: 60,
      stripCount: 3,
    );
    expect(r.startDay, 0);
    expect(r.startMin, 1380);
    expect(r.endDay, 1);
    expect(r.endMin, 90);
  });

  test('timeline selection helper: no zero or negative duration', () {
    final r = timelineSelectionBounds(
      anchorDay: 0,
      anchorMin: 0,
      pointerDay: 0,
      pointerMin: 0,
      stripCount: 1,
    );
    expect(
      r.endMin - r.startMin + (r.endDay - r.startDay) * 1440,
      greaterThan(0),
    );
  });

  test('last event calendar and task list persist', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final repo = SettingsRepository(await SharedPreferences.getInstance());
    await repo.setDefaultCalendarId('cal-1');
    await repo.setSelectedTaskListId('list-1');
    expect(repo.defaultCalendarId, 'cal-1');
    expect(repo.selectedTaskListId, 'list-1');
  });
}
