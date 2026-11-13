part of '../microsoft_sync_engine.dart';

/// Normalized owner address from Graph, or null when Graph did not provide one.
String? _ownerEmailOf(MsCalendar c) {
  final address = c.owner?.address?.trim().toLowerCase();
  return address == null || address.isEmpty ? null : address;
}

extension on MicrosoftSyncEngine {
  String get _accountKey => account.trim().toLowerCase();

  bool _isOwnAccount(String? value) =>
      value != null && value.trim().toLowerCase() == _accountKey;

  /// A calendar is shared for reader/403 purposes when Graph flags it or when
  /// its owner differs from the active account. The owner check covers missing
  /// or false `isSharedWithMe` flags.
  bool _isSharedCalendar(MsCalendar c) {
    final owner = _ownerEmailOf(c);
    return c.isSharedWithMe || (owner != null && owner != _accountKey);
  }

  Calendar _newestCalendarRow(List<Calendar> rows) {
    rows.sort((a, b) {
      final byUpdated = b.updatedAt.compareTo(a.updatedAt);
      return byUpdated != 0 ? byUpdated : a.id.compareTo(b.id);
    });
    return rows.first;
  }

  Future<({int count, Map<String, String> idsByRemote})> _syncCalendars(
    List<MsCalendar> calendars,
    int now,
  ) async {
    final calendarIdByRemote = <String, String>{};
    var calendarCount = 0;
    for (final c in calendars) {
      final remoteId = c.id;
      if (remoteId.isEmpty) continue;
      final ownerEmail = _ownerEmailOf(c);
      final ownerDiffers = ownerEmail != null && ownerEmail != _accountKey;
      final isShared = _isSharedCalendar(c);
      final ownRow = await _ownCalendarRow(remoteId);
      Calendar? sharedRow;
      var existing = ownRow;
      // SECURITY: a shared calendar is one logical calendar readable by several
      // accounts. Prefer the row stamped with the true Graph owner, then the
      // active account's own row, and only then any shared row. Only shared
      // calendars are deduped, so unrelated accounts with identical remote ids
      // stay isolated.
      if (ownerDiffers) {
        sharedRow = await _sharedCalendarRow(
          remoteId,
          preferredOwner: ownerEmail,
        );
        existing = sharedRow ?? ownRow;
      } else if (existing == null && isShared) {
        sharedRow = await _sharedCalendarRow(remoteId);
        existing = sharedRow;
      }
      if (existing == null) {
        final id = 'mscal_${account}_$remoteId';
        await _db
            .into(_db.calendars)
            .insert(
              CalendarsCompanion.insert(
                id: id,
                remoteId: Value(remoteId),
                name: c.name.isEmpty ? remoteId : c.name,
                color: Value(c.hexColor),
                source: const Value('microsoft'),
                // A delegate's copy carries the true owner address from Graph.
                microsoftAccount: Value(ownerEmail ?? account),
                readOnly: Value(!c.canEdit),
                enabled: const Value(true),
                createdAt: now,
                updatedAt: now,
              ),
            );
        calendarIdByRemote[remoteId] = id;
        calendarCount++;
        continue;
      }
      final row = existing;
      final owner = ownerEmail ?? row.microsoftAccount ?? account;
      await (_db.update(
        _db.calendars,
      )..where((t) => t.id.equals(row.id))).write(
        CalendarsCompanion(
          name: Value(c.name.isEmpty ? row.name : c.name),
          color: Value(c.hexColor ?? row.color),
          readOnly: Value(!c.canEdit),
          dirty: const Value(false),
          updatedAt: Value(now),
          // Graph's owner wins; otherwise keep the existing owner stamp.
          microsoftAccount: ownerEmail != null
              ? Value(ownerEmail)
              : (ownRow != null ? Value(account) : const Value.absent()),
          // A remote row reappeared in a complete listing, so revive a
          // reconciliation tombstone. Only rows matched by remote id reach this
          // path; local-only rows (null remoteId) are never updated here.
          deletedAt: const Value(null),
        ),
      );
      final canPull = isShared
          ? await _claimSharedReader(remoteId, owner)
          : true;
      if (canPull) calendarIdByRemote[remoteId] = row.id;
    }
    return (count: calendarCount, idsByRemote: calendarIdByRemote);
  }

  /// Finds the active account's row for [remoteId], ignoring email case.
  Future<Calendar?> _ownCalendarRow(String remoteId) async {
    final rows =
        await (_db.select(_db.calendars)..where(
              (t) => t.source.equals('microsoft') & t.remoteId.equals(remoteId),
            ))
            .get();
    final own = rows.where((r) => _isOwnAccount(r.microsoftAccount)).toList();
    if (own.isEmpty) return null;
    return _newestCalendarRow(own);
  }

  /// Finds a live local Microsoft calendar row for [remoteId] owned by another
  /// account, used to dedupe shared calendars across accounts. Soft-deleted rows
  /// are ignored. [preferredOwner] wins when present; legacy duplicates fall
  /// back to the newest `updatedAt`, then id, for determinism.
  Future<Calendar?> _sharedCalendarRow(
    String remoteId, {
    String? preferredOwner,
  }) async {
    final rows =
        await (_db.select(_db.calendars)..where(
              (t) =>
                  t.source.equals('microsoft') &
                  t.remoteId.equals(remoteId) &
                  t.microsoftAccount.isNotNull() &
                  t.deletedAt.isNull(),
            ))
            .get();
    final shared = rows.where((r) {
      final owner = r.microsoftAccount?.trim().toLowerCase();
      return owner != null && owner.isNotEmpty && owner != _accountKey;
    }).toList();
    if (shared.isEmpty) return null;
    if (preferredOwner != null) {
      final preferred = shared
          .where(
            (r) => r.microsoftAccount!.trim().toLowerCase() == preferredOwner,
          )
          .toList();
      if (preferred.isNotEmpty) return _newestCalendarRow(preferred);
    }
    return _newestCalendarRow(shared);
  }

  /// Decides which signed-in account pulls events for a shared calendar.
  ///
  /// The owner pulls whenever it is signed in. When the owner is absent, one
  /// reader is recorded in syncState so a second account does not pull the same
  /// calendar twice. A reader that is no longer signed in can be replaced.
  /// When the caller did not provide the account list this fails open and lets
  /// the active account pull, so shared events are not stranded. Production
  /// always passes the list.
  Future<bool> _claimSharedReader(String remoteId, String owner) async {
    final signedIn = _signedInAccounts;
    if (signedIn == null) return true;
    final ownerKey = owner.trim().toLowerCase();
    if (signedIn.contains(ownerKey)) return _accountKey == ownerKey;
    final key = 'ms:cal:reader:$remoteId';
    final reader = (await _syncValue(key))?.trim().toLowerCase();
    if (reader == _accountKey) return true;
    if (reader != null && signedIn.contains(reader)) return false;
    await _setSyncValue(key, _accountKey);
    return true;
  }

  Future<String?> _syncValue(String key) async {
    final row = await (_db.select(
      _db.syncState,
    )..where((s) => s.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<void> _setSyncValue(String key, String value) async {
    await _db
        .into(_db.syncState)
        .insertOnConflictUpdate(
          SyncStateCompanion.insert(
            key: key,
            value: Value(value),
            lastSyncAt: Value(DateTime.now().toUtc().millisecondsSinceEpoch),
          ),
        );
  }

  Future<int> _syncEvents(
    List<MsCalendar> calendars,
    Map<String, String> calendarIdByRemote,
  ) async {
    var eventCount = 0;
    for (final cal in calendars) {
      final localCalId = calendarIdByRemote[cal.id];
      if (localCalId == null) continue;
      final calRow = await (_db.select(
        _db.calendars,
      )..where((t) => t.id.equals(localCalId))).getSingleOrNull();
      // Keep events stamped with the original calendar owner so a shared
      // calendar pulled by a delegate does not duplicate them per account.
      final eventOwner = calRow?.microsoftAccount ?? account;
      late final List<MsEvent> events;
      try {
        events = await _client.calendarView(
          _windowStart,
          _windowEnd,
          calendarId: cal.id,
        );
      } on MicrosoftGraphException catch (e) {
        // One inaccessible/broken calendar must not abort the others or the
        // To Do sync. A 401 means the account credential is bad. A 403 on a
        // shared calendar means the grant predates Calendars.Read.Shared, so
        // the account needs to re-consent; a 403 elsewhere is a per-calendar
        // permission that must stay isolated. Shared includes an owner address
        // that differs from the active account, even if the flag is missing.
        if (e.isUnauthorized || (e.isForbidden && _isSharedCalendar(cal))) {
          _authFailure = true;
        }
        debugPrint('[ms-sync] calendarView failed status=${e.status}');
        continue;
      } on Exception catch (e) {
        debugPrint('[ms-sync] calendarView failed type=${e.runtimeType}');
        continue;
      }
      final remoteEventIds = {
        for (final e in events)
          if (e.id.isNotEmpty) e.id,
      };
      for (final e in events) {
        final remoteId = e.id;
        if (remoteId.isEmpty) continue;
        // Identity is the local calendar plus remote id, matching the Google
        // pull. A shared calendar can change its pulling account, so scoping by
        // microsoftAccount would miss the previous row and duplicate it.
        final existing =
            await (_db.select(_db.events)..where(
                  (t) =>
                      t.calendarId.equals(localCalId) &
                      t.remoteId.equals(remoteId),
                ))
                .getSingleOrNull();
        final isAllDay = e.isAllDay;
        final startUtc = e.start?.utc;
        final endUtc = e.end?.utc;
        final startDate = isAllDay && startUtc != null
            ? _dateStr(startUtc)
            : null;
        final endDate = isAllDay && endUtc != null ? _dateStr(endUtc) : null;
        final title = e.subject ?? '';
        final cancelled = e.isCancelled;
        final status = cancelled ? 'cancelled' : 'confirmed';
        final meetUrl = e.onlineMeetingUrl;
        final location = e.location?.displayName;
        final notes = e.bodyPreview;
        final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;
        if (existing == null) {
          await _db
              .into(_db.events)
              .insert(
                EventsCompanion.insert(
                  id: 'msevt_${eventOwner}_$remoteId',
                  calendarId: localCalId,
                  title: Value(title),
                  notes: Value(notes),
                  location: Value(location),
                  startUtc: Value(
                    isAllDay ? null : startUtc?.millisecondsSinceEpoch,
                  ),
                  endUtc: Value(
                    isAllDay ? null : endUtc?.millisecondsSinceEpoch,
                  ),
                  startDate: Value(startDate),
                  endDate: Value(endDate),
                  isAllDay: Value(isAllDay),
                  status: Value(status),
                  meetUrl: Value(meetUrl),
                  microsoftAccount: Value(eventOwner),
                  remoteId: Value(remoteId),
                  dirty: const Value(false),
                  createdAt: nowMs,
                  updatedAt: nowMs,
                ),
              );
          eventCount++;
        } else {
          await (_db.update(
            _db.events,
          )..where((t) => t.id.equals(existing.id))).write(
            EventsCompanion(
              calendarId: Value(localCalId),
              title: Value(title),
              notes: Value(notes ?? existing.notes),
              location: Value(location ?? existing.location),
              startUtc: Value(
                isAllDay ? null : startUtc?.millisecondsSinceEpoch,
              ),
              endUtc: Value(isAllDay ? null : endUtc?.millisecondsSinceEpoch),
              startDate: Value(startDate),
              endDate: Value(endDate),
              isAllDay: Value(isAllDay),
              status: Value(status),
              meetUrl: Value(meetUrl ?? existing.meetUrl),
              microsoftAccount: Value(eventOwner),
              remoteId: Value(remoteId),
              dirty: const Value(false),
              // A remote event reappeared in a complete calendarView, so revive
              // a reconciliation tombstone.
              deletedAt: const Value(null),
              updatedAt: Value(nowMs),
              // Preserve local-only fields.
              alarmPreset: Value(existing.alarmPreset),
              reminders: Value(existing.reminders),
              visibility: Value(existing.visibility),
              createMeet: Value(existing.createMeet),
              colorId: Value(existing.colorId),
            ),
          );
          eventCount++;
        }
        // TODO(#issue): map Graph recurrence to RRULE when representable; for now store occurrence as single event.
      }
      // Reconcile newly missing events only after a complete, successful fetch
      // for this calendar. A failed fetch is caught above and never reaches
      // this point, so per-calendar isolation is preserved.
      await _reconcileDeletedEvents(
        localCalId,
        remoteEventIds,
        DateTime.now().toUtc().millisecondsSinceEpoch,
      );
    }
    return eventCount;
  }
}
