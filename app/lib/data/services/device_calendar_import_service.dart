// Device calendar import: reads OS calendars/events via device_calendar_plus
// and mirrors them into a local app calendar. Re-imports update the same local
// rows (keyed by event id) instead of creating duplicates, and mapped imports
// can be refreshed on demand. Degrades gracefully on platforms without native
// calendar access.
import 'package:device_calendar_plus/device_calendar_plus.dart';
import 'package:ephemeron/data/repositories/event_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DeviceCalendarInfo {
  const DeviceCalendarInfo({
    required this.id,
    required this.name,
    this.colorHex,
    this.readOnly = false,
  });
  final String id;
  final String name;
  final String? colorHex;
  final bool readOnly;
}

/// Counts from one import or refresh pass.
class DeviceImportResult {
  const DeviceImportResult({
    this.inserted = 0,
    this.updated = 0,
    this.deleted = 0,
    this.skipped = 0,
    this.completed = true,
  });

  final int inserted;
  final int updated;
  final int deleted;
  final int skipped;

  /// False only when the device read failed. A valid empty import is complete.
  final bool completed;

  DeviceImportResult operator +(DeviceImportResult other) => DeviceImportResult(
    inserted: inserted + other.inserted,
    updated: updated + other.updated,
    deleted: deleted + other.deleted,
    skipped: skipped + other.skipped,
    completed: completed && other.completed,
  );

  DeviceImportResult withDeleted(int count) => DeviceImportResult(
    inserted: inserted,
    updated: updated,
    deleted: count,
    skipped: skipped,
    completed: completed,
  );
}

/// One device event series. [event] is the earliest fetched occurrence, used
/// as the single local mirror row (the master when the series recurs).
class DeviceEventGroup {
  const DeviceEventGroup({required this.key, required this.event});
  final String key;
  final Event event;
}

/// Groups device instances by stable event id, falling back to instance id.
///
/// Recurring series share `eventId`; picking the earliest occurrence keeps one
/// master row and stores the RRULE once instead of duplicating it per instance.
/// Device recurrence exceptions are not represented as separate rows: the
/// earliest occurrence becomes the master and a local edit on that row wins
/// over later refreshes.
List<DeviceEventGroup> groupDeviceEvents(Iterable<Event> events) {
  final byKey = <String, DeviceEventGroup>{};
  for (final event in events) {
    final String key;
    if (event.eventId.isNotEmpty) {
      key = event.eventId;
    } else if (event.instanceId.isNotEmpty) {
      key = event.instanceId;
    } else {
      continue;
    }
    final current = byKey[key];
    if (current == null || _preferDeviceEvent(event, current.event)) {
      byKey[key] = DeviceEventGroup(key: key, event: event);
    }
  }
  return byKey.values.toList();
}

/// Prefers a rule-bearing occurrence over one without a rule so the grouped
/// master does not lose its RRULE; ties fall back to the earliest start.
bool _preferDeviceEvent(Event candidate, Event current) {
  final candidateHasRule = candidate.recurrenceRule != null;
  final currentHasRule = current.recurrenceRule != null;
  if (candidateHasRule != currentHasRule) return candidateHasRule;
  return candidate.startDate.isBefore(current.startDate);
}

class DeviceCalendarImportService {
  DeviceCalendarImportService(this._repo, {SharedPreferences? preferences})
    : _preferences = preferences;

  final EventRepository _repo;
  final SharedPreferences? _preferences;

  static const String mappingKeyPrefix = 'deviceImport.target.';

  bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<List<DeviceCalendarInfo>> listCalendars() async {
    if (!isSupported) return const [];
    try {
      final cals = await DeviceCalendar.instance.listCalendars();
      return cals
          .where((c) => !c.hidden)
          .map(
            (c) => DeviceCalendarInfo(
              id: c.id,
              name: c.name,
              colorHex: c.colorHex,
              readOnly: c.readOnly,
            ),
          )
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<int> requestPermission() async {
    if (!isSupported) return 0;
    try {
      final status = await DeviceCalendar.instance.requestPermissions();
      if (status == CalendarPermissionStatus.granted ||
          status == CalendarPermissionStatus.writeOnly) {
        return 1;
      }
      return 0;
    } catch (_) {
      return 0;
    }
  }

  /// Imports events from [deviceCalendarId] into [targetCalendarId].
  ///
  /// Re-importing updates existing rows instead of inserting duplicates.
  Future<DeviceImportResult> importCalendar({
    required String deviceCalendarId,
    required String targetCalendarId,
    DateTime? from,
    DateTime? to,
  }) async {
    if (!isSupported) return const DeviceImportResult();
    try {
      final groups = await _fetchGroups(
        deviceCalendarId: deviceCalendarId,
        from: from,
        to: to,
      );
      return await _importGroups(
        targetCalendarId: targetCalendarId,
        groups: groups,
      );
    } catch (_) {
      return const DeviceImportResult(completed: false);
    }
  }

  /// Applies already-fetched device events without touching the native plugin.
  ///
  /// Split out so the grouping and upsert behavior stays testable on hosts
  /// without calendar support.
  Future<DeviceImportResult> importEvents({
    required String targetCalendarId,
    required List<Event> events,
  }) {
    return _importGroups(
      targetCalendarId: targetCalendarId,
      groups: groupDeviceEvents(events),
    );
  }

  /// Re-imports every mapped device calendar and soft-deletes rows that no
  /// longer exist on the device. Skips mappings whose target disappeared.
  Future<DeviceImportResult> refreshMappedCalendars() async {
    if (!isSupported) return const DeviceImportResult();
    final mappings = await loadMappings();
    if (mappings.isEmpty) return const DeviceImportResult();
    final calendars = await _repo.watchCalendars().first;
    final existingIds = {for (final c in calendars) c.id};

    // Refresh must not keep offering calendars whose target was removed.
    final stale = [
      for (final entry in mappings.entries)
        if (!existingIds.contains(entry.value)) entry.key,
    ];
    if (stale.isNotEmpty) {
      await removeMappings(stale);
      for (final id in stale) {
        mappings.remove(id);
      }
    }
    if (mappings.isEmpty) return const DeviceImportResult();

    // Group by target so two device calendars imported into the same local
    // calendar cannot delete each other's rows during reconciliation.
    final byTarget = <String, List<String>>{};
    for (final entry in mappings.entries) {
      if (!existingIds.contains(entry.value)) continue;
      byTarget.putIfAbsent(entry.value, () => []).add(entry.key);
    }

    final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;
    var total = const DeviceImportResult();
    for (final entry in byTarget.entries) {
      final retained = <String>{};
      var imported = const DeviceImportResult();
      var failed = false;
      for (final deviceCalendarId in entry.value) {
        List<DeviceEventGroup> groups;
        try {
          groups = await _fetchGroups(deviceCalendarId: deviceCalendarId);
        } catch (_) {
          // A failed read is not a deletion: skip reconciling this target.
          failed = true;
          continue;
        }
        imported += await _importGroups(
          targetCalendarId: entry.key,
          groups: groups,
        );
        retained.addAll(
          groups.map((g) => '$deviceImportRemoteIdPrefix${g.key}'),
        );
      }
      if (!failed) {
        final deleted = await _repo.reconcileImportedDeviceEvents(
          calendarId: entry.key,
          retainedRemoteIds: retained,
          nowMs: nowMs,
        );
        imported = imported.withDeleted(deleted);
      }
      total += imported;
    }
    return total;
  }

  /// Persisted device calendar id -> local calendar id mappings. Only ids are
  /// stored, never calendar names or event content.
  Future<Map<String, String>> loadMappings() async {
    final prefs = await _prefs();
    final out = <String, String>{};
    for (final key in prefs.getKeys()) {
      if (!key.startsWith(mappingKeyPrefix)) continue;
      final target = prefs.getString(key);
      if (target == null || target.isEmpty) continue;
      out[key.substring(mappingKeyPrefix.length)] = target;
    }
    return out;
  }

  Future<void> saveMappings(Map<String, String> mappings) async {
    final prefs = await _prefs();
    for (final entry in mappings.entries) {
      await prefs.setString('$mappingKeyPrefix${entry.key}', entry.value);
    }
  }

  Future<void> removeMappings(Iterable<String> deviceCalendarIds) async {
    final prefs = await _prefs();
    for (final id in deviceCalendarIds) {
      await prefs.remove('$mappingKeyPrefix$id');
    }
  }

  Future<bool> hasMappings() async => (await loadMappings()).isNotEmpty;

  Future<SharedPreferences> _prefs() async =>
      _preferences ?? SharedPreferences.getInstance();

  Future<List<DeviceEventGroup>> _fetchGroups({
    required String deviceCalendarId,
    DateTime? from,
    DateTime? to,
  }) async {
    final now = DateTime.now();
    final start = from ?? now.subtract(const Duration(days: 30));
    final end = to ?? now.add(const Duration(days: 365));
    final events = await DeviceCalendar.instance.listEvents(
      start,
      end,
      calendarIds: [deviceCalendarId],
    );
    return groupDeviceEvents(events);
  }

  Future<DeviceImportResult> _importGroups({
    required String targetCalendarId,
    required List<DeviceEventGroup> groups,
  }) async {
    var inserted = 0;
    var updated = 0;
    var skipped = 0;
    for (final group in groups) {
      final event = group.event;
      final remoteId = '$deviceImportRemoteIdPrefix${group.key}';
      final existing = await _repo.findImportedDeviceEvent(
        calendarId: targetCalendarId,
        remoteId: remoteId,
      );
      final attendees = event.attendees
          ?.map((a) => a.emailAddress)
          .whereType<String>()
          .toList();
      await _repo.upsertImportedDeviceEvent(
        calendarId: targetCalendarId,
        remoteId: remoteId,
        title: event.title.isEmpty ? '(untitled)' : event.title,
        notes: event.description,
        location: event.location,
        startUtc: event.isAllDay ? null : event.startDate,
        endUtc: event.isAllDay ? null : event.endDate,
        startDate: event.isAllDay ? _dateStr(event.startDate) : null,
        endDate: event.isAllDay
            ? _exclusiveImportEnd(event.startDate, event.endDate)
            : null,
        allDay: event.isAllDay,
        tzId: event.timeZone,
        rrule: event.recurrenceRule?.rruleString,
        attendeeEmails: attendees ?? const [],
      );
      if (existing == null) {
        inserted++;
      } else if (existing.dirty) {
        skipped++;
      } else {
        updated++;
      }
    }
    return DeviceImportResult(
      inserted: inserted,
      updated: updated,
      skipped: skipped,
    );
  }

  String _dateStr(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // device_calendar_plus reports all-day end as EXCLUSIVE (half-open
  // [start, end)); keep it. Fall back to a single day when end <= start.
  String _exclusiveImportEnd(DateTime start, DateTime end) {
    if (!end.isAfter(start)) {
      return _dateStr(start.add(const Duration(days: 1)));
    }
    return _dateStr(end);
  }
}
