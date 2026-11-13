part of '../../sync_engine.dart';

extension on SyncEngine {
  Future<int> _pullCalendars(GoogleApiClient client) async {
    await _cleanupLegacyCalendarTokens();
    final calendars =
        await (_db.select(_db.calendars)..where(
              (c) =>
                  c.source.equals('google') &
                  c.enabled.equals(true) &
                  c.deletedAt.isNull(),
            ))
            .get();
    debugPrint('[sync] pulling ${calendars.length} google calendars');
    var total = 0;
    for (final cal in calendars) {
      if (!await _pullableCalendar(cal)) continue;
      debugPrint('[sync] pulling calendar id=${cal.id} enabled=${cal.enabled}');
      final token = await _syncValue('cal:v2:${cal.id}:token');
      final remoteId = cal.remoteId;
      if (remoteId == null) {
        debugPrint('[sync] skip calendar with null remoteId');
        continue;
      }
      try {
        if (token == null) {
          total += await _fullCalendarResync(cal, client, keepDirty: true);
        } else {
          final page = await client.eventsList(remoteId, syncToken: token);
          debugPrint(
            '[sync] incremental pull got ${page.items.length} items (has remoteId=${cal.remoteId != null})',
          );
          total += await _mergeEvents(cal, page.items);
          if (page.nextSyncToken != null) {
            await _setSyncValue('cal:v2:${cal.id}:token', page.nextSyncToken!);
            // Best-effort cleanup of legacy token key.
            await (_db.delete(
              _db.syncState,
            )..where((s) => s.key.equals('cal:${cal.id}:token'))).go();
          }
        }
        await _setSyncMeta('cal:${cal.id}', error: null);
        // 404 stays enabled (fail-open) to avoid hiding shared calendars; transient
        // non-auth per-calendar failures are recorded in syncState meta and retried
        // next run instead of aborting the whole account.
      } on GoogleApiException catch (e) {
        debugPrint('[sync] calendar pull failed status=${e.status}');
        if (e.isGone) {
          // Drop the stale token before retrying: if the resync itself fails,
          // a surviving token would repeat 410 forever. A successful resync
          // writes a fresh token.
          await (_db.delete(
            _db.syncState,
          )..where((s) => s.key.equals('cal:v2:${cal.id}:token'))).go();
          // Full resync from inside a catch must not escape this calendar and
          // abort the remaining pull.
          try {
            total += await _fullCalendarResync(cal, client, keepDirty: true);
            await _setSyncMeta('cal:${cal.id}', error: null);
          } on Exception catch (retryError) {
            debugPrint(
              '[sync] calendar resync failed type=${retryError.runtimeType}',
            );
            _recordFailure(retryError);
            await _clearReaderClaim(remoteId);
            await _setSyncMeta('cal:${cal.id}', error: 'sync failed');
          }
        } else if (e.isAuthFailure) {
          _recordFailure(e);
          await _clearReaderClaim(remoteId);
          await _setSyncMeta('cal:${cal.id}', error: 'Google auth');
        } else if (e.isRateLimited) {
          _recordFailure(e);
          await _clearReaderClaim(remoteId);
          await _setSyncMeta('cal:${cal.id}', error: 'rate limited');
        } else if (e.isForbidden) {
          // Permanently inaccessible calendar (for example freeBusyReader or
          // a shared calendar this account cannot read). Record and skip; do
          // not demand reconnect for the whole account.
          await _clearReaderClaim(remoteId);
          await _setSyncMeta('cal:${cal.id}', error: 'forbidden');
        } else if (e.status == 404) {
          await _clearReaderClaim(remoteId);
          await _setSyncMeta('cal:${cal.id}', error: 'Google 404');
        } else {
          _recordFailure(e);
          await _clearReaderClaim(remoteId);
          await _setSyncMeta('cal:${cal.id}', error: 'Google ${e.status}');
        }
      } on Exception catch (e) {
        debugPrint('[sync] calendar pull failed type=${e.runtimeType}');
        _recordFailure(e);
        await _clearReaderClaim(remoteId);
        await _setSyncMeta('cal:${cal.id}', error: 'sync failed');
      }
    }
    return total;
  }

  /// Whether [cal] may be pulled under the active account.
  ///
  /// A calendar stamped to the active account is always pulled. A calendar
  /// stamped to another signed-in account belongs to that owner and is
  /// skipped here, so a shared calendar is not fetched once per account.
  /// A calendar whose stamp names an account that is not signed in is pulled
  /// by a single deterministic reader recorded in syncState, so the same
  /// calendar is not pulled by every account in turn. With an unknown account
  /// list, another owner's shared calendar fails closed instead of pulling
  /// once per account. Entries that are freeBusyReader-only have no event
  /// details and are skipped.
  Future<bool> _pullableCalendar(Calendar cal) async {
    final remoteId = cal.remoteId;
    final discovered = _accountCalendarIds;
    final readable = _readableCalendarIds;
    if (remoteId != null &&
        discovered != null &&
        readable != null &&
        discovered.contains(remoteId) &&
        !readable.contains(remoteId)) {
      return false;
    }
    if (account == null) return true;
    final owner = cal.googleAccount;
    if (owner == account) return true;
    if (owner == null) {
      // Legacy unstamped rows keep discovery gating and are not claimed:
      // there is no host account whose absence needs a reader.
      if (discovered == null) return true;
      return remoteId == null || discovered.contains(remoteId);
    }
    final signedIn = signedInAccounts;
    if (signedIn == null) {
      // Fail closed: without the signed-in set we cannot tell another active
      // account's shared calendar from a signed-out owner's. Pulling would
      // duplicate a shared calendar once per account, so only the stamped
      // owner above may pull.
      return false;
    }
    if (signedIn.contains(owner)) return false;
    if (remoteId == null) return false;
    final key = 'cal:reader:$remoteId';
    final reader = await _syncValue(key);
    if (reader == account) return true;
    if (reader != null && signedIn.contains(reader)) return false;
    // Claim only when the calendar is actually readable under this account,
    // otherwise a freeBusyReader or inaccessible entry would occupy the slot.
    if (readable == null || !readable.contains(remoteId)) return false;
    await _setSyncValue(key, account!);
    debugPrint('[sync] claimed shared calendar reader id=$remoteId');
    return true;
  }

  /// Best-effort release of a shared-calendar reader claim after a failed
  /// pull. Clears only when the key still names the active account so a
  /// concurrent account's claim is never stolen. Never throws into the pull
  /// loop: a cleanup failure must not abort remaining calendars.
  Future<void> _clearReaderClaim(String? remoteId) async {
    final active = account;
    if (remoteId == null || active == null) return;
    final key = 'cal:reader:$remoteId';
    try {
      final reader = await _syncValue(key);
      if (reader != active) return;
      await (_db.delete(_db.syncState)..where((s) => s.key.equals(key))).go();
      debugPrint('[sync] released shared calendar reader id=$remoteId');
    } catch (e) {
      debugPrint('[sync] reader claim cleanup failed type=${e.runtimeType}');
    }
  }

  /// Removes stale legacy `cal:<localId>:token` rows once the v2 key exists.
  /// Runs before every pull so old installs are cleaned on the next normal
  /// sync, including runs where a specific calendar pull fails.
  Future<void> _cleanupLegacyCalendarTokens() async {
    final rows = await (_db.select(
      _db.syncState,
    )..where((s) => s.key.like('cal:%:token'))).get();
    if (rows.isEmpty) return;
    final v2Keys = {
      for (final row in rows)
        if (row.key.startsWith('cal:v2:')) row.key,
    };
    for (final row in rows) {
      final key = row.key;
      if (key.startsWith('cal:v2:')) continue;
      if (!key.startsWith('cal:') || !key.endsWith(':token')) continue;
      final localId = key.substring(
        'cal:'.length,
        key.length - ':token'.length,
      );
      if (localId.isEmpty || localId.contains(':')) continue;
      if (!v2Keys.contains('cal:v2:$localId:token')) continue;
      await (_db.delete(_db.syncState)..where((s) => s.key.equals(key))).go();
    }
  }

  /// Conservative cleanup for `cal:reader:<remoteId>` claims.
  ///
  /// A claim is stale when its calendar row is gone, disabled or soft-deleted,
  /// or when the true owner is signed in again (the owner pulls directly).
  /// A claim is kept while its reader is signed in and the owner is absent.
  /// With an unknown account list only provably stale rows are removed.
  Future<void> _cleanupReaderClaims() async {
    final claims = await (_db.select(
      _db.syncState,
    )..where((s) => s.key.like('cal:reader:%'))).get();
    if (claims.isEmpty) return;
    final calendars = await (_db.select(
      _db.calendars,
    )..where((c) => c.source.equals('google') & c.remoteId.isNotNull())).get();
    final byRemote = <String, List<Calendar>>{};
    for (final calendar in calendars) {
      byRemote.putIfAbsent(calendar.remoteId!, () => []).add(calendar);
    }
    for (final claim in claims) {
      final remoteId = claim.key.substring('cal:reader:'.length);
      final rows = byRemote[remoteId];
      if (rows == null || rows.isEmpty) {
        await _deleteReaderClaim(claim.key);
        continue;
      }
      if (rows.any((row) => _readerClaimIsLive(row, claim.value))) continue;
      await _deleteReaderClaim(claim.key);
    }
  }

  bool _readerClaimIsLive(Calendar calendar, String? reader) {
    if (calendar.deletedAt != null || !calendar.enabled) return false;
    if (reader == null || reader.isEmpty) return false;
    final owner = calendar.googleAccount;
    if (owner == null) return false;
    if (owner == account) return false;
    final signedIn = signedInAccounts;
    if (signedIn == null) return true;
    if (signedIn.contains(owner)) return false;
    return signedIn.contains(reader);
  }

  Future<void> _deleteReaderClaim(String key) async {
    await (_db.delete(_db.syncState)..where((s) => s.key.equals(key))).go();
    debugPrint('[sync] cleaned stale shared calendar reader');
  }

  Future<int> _fullCalendarResync(
    Calendar cal,
    GoogleApiClient client, {
    required bool keepDirty,
  }) async {
    final page = await client.eventsList(cal.remoteId ?? cal.id);
    debugPrint(
      '[sync] full resync got ${page.items.length} items (has remoteId=${cal.remoteId != null})',
    );
    return _db.transaction(() async {
      // Drop synced rows in the window; keep dirty local rows.
      final local =
          await (_db.select(_db.events)..where(
                (e) => e.calendarId.equals(cal.id) & e.deletedAt.isNull(),
              ))
              .get();
      for (final e in local) {
        if (e.remoteId != null && !(keepDirty && e.dirty)) {
          // Keep occurrence rows until the single post-pull rebuild replaces
          // the window atomically; deleting per calendar makes events flicker
          // out mid-sync.
          await (_db.delete(_db.events)..where((x) => x.id.equals(e.id))).go();
        }
      }
      final n = await _mergeEvents(cal, page.items);
      debugPrint('[sync] full resync merged $n events');
      if (page.nextSyncToken != null) {
        await _setSyncValue('cal:v2:${cal.id}:token', page.nextSyncToken!);
      }
      // Best-effort cleanup of legacy token key.
      await (_db.delete(
        _db.syncState,
      )..where((s) => s.key.equals('cal:${cal.id}:token'))).go();
      return n;
    });
  }

  Future<int> _mergeEvents(
    Calendar cal,
    List<Map<String, dynamic>> items,
  ) async {
    var n = 0;
    // Keep event ownership anchored to the calendar owner when known so a
    // shared calendar pulled under another account does not flap ownership.
    final owner = cal.googleAccount ?? account;
    // Process non-exception masters/singles first, then exceptions.
    final nonExceptions = items
        .where((g) => g['recurringEventId'] == null)
        .toList();
    final exceptions = items
        .where((g) => g['recurringEventId'] != null)
        .toList();
    for (final g in [...nonExceptions, ...exceptions]) {
      final remoteId = g['id'] as String?;
      if (remoteId == null) continue;
      try {
        final isException = g['recurringEventId'] != null;
        final masterRemoteId = g['recurringEventId'] as String?;
        String? masterLocalId;
        if (isException && masterRemoteId != null) {
          final masterRow =
              await (_db.select(_db.events)..where(
                    (e) =>
                        e.remoteId.equals(masterRemoteId) &
                        e.calendarId.equals(cal.id),
                  ))
                  .getSingleOrNull();
          masterLocalId = masterRow?.id;
        }
        final existing =
            await (_db.select(_db.events)..where(
                  (e) =>
                      e.remoteId.equals(remoteId) & e.calendarId.equals(cal.id),
                ))
                .getSingleOrNull();
        final cancelled = g['status'] == 'cancelled';
        if (cancelled && !isException) {
          // Standalone cancelled event keeps tombstone behavior.
          if (existing != null && !existing.dirty) {
            await (_db.update(
              _db.events,
            )..where((e) => e.id.equals(existing.id))).write(
              EventsCompanion(
                status: const Value('cancelled'),
                deletedAt: Value(_now()),
                dirty: const Value(false),
              ),
            );
          }
          continue;
        }
        if (cancelled && isException) {
          // Cancelled exception: exception row, status cancelled, deletedAt NULL.
          if (masterLocalId == null) {
            // Fallback: store as normal single event (tombstone for cancelled).
            if (existing != null && !existing.dirty) {
              await (_db.update(
                _db.events,
              )..where((e) => e.id.equals(existing.id))).write(
                EventsCompanion(
                  status: const Value('cancelled'),
                  deletedAt: Value(_now()),
                  dirty: const Value(false),
                ),
              );
            }
            continue;
          }
          // A delete clears the local instance id, so the echoed cancelled
          // instance must re-link by master and original occurrence rather
          // than insert a second tombstone for the same occurrence.
          var localException = existing;
          final originalStartMs = originalStartMsFromGoogle(g);
          if (localException == null && originalStartMs != null) {
            final localMasterId = masterLocalId;
            localException =
                await (_db.select(_db.events)..where(
                      (e) =>
                          e.calendarId.equals(cal.id) &
                          e.recurringMasterId.equals(localMasterId) &
                          e.originalStart.equals(originalStartMs) &
                          e.deletedAt.isNull(),
                    ))
                    .getSingleOrNull();
          }
          final localId = localException?.id ?? newId();
          final mapped = eventFromGoogle(
            g,
            cal.id,
            localId,
            recurringMasterLocalId: masterLocalId,
          );
          if (localException == null) {
            await _db
                .into(_db.events)
                .insert(
                  mapped.companion.copyWith(
                    googleAccount: Value(owner),
                    deletedAt: const Value(null),
                    status: const Value('cancelled'),
                  ),
                );
            n++;
          } else if (!localException.dirty) {
            final current = localException;
            await (_db.update(
              _db.events,
            )..where((e) => e.id.equals(current.id))).write(
              mapped.companion.copyWith(
                alarmPreset: const Value.absent(),
                deletedAt: const Value(null),
                status: const Value('cancelled'),
              ),
            );
            n++;
          }
          continue;
        }
        // Non-cancelled.
        late String localId;
        if (existing == null) {
          final mapped = eventFromGoogle(
            g,
            cal.id,
            newId(),
            recurringMasterLocalId: isException ? masterLocalId : null,
          );
          await _db
              .into(_db.events)
              .insert(
                mapped.companion.copyWith(
                  googleAccount: Value(owner),
                  deletedAt: const Value(null),
                ),
              );
          localId = mapped.companion.id.value;
          n++;
        } else if (!existing.dirty) {
          final mapped = eventFromGoogle(
            g,
            cal.id,
            existing.id,
            recurringMasterLocalId: isException ? masterLocalId : null,
          );
          await (_db.update(
            _db.events,
          )..where((e) => e.id.equals(existing.id))).write(
            mapped.companion.copyWith(
              alarmPreset: const Value.absent(),
              // A confirmed remote event revives a previously cancelled or
              // soft-deleted local tombstone.
              deletedAt: const Value(null),
            ),
          );
          localId = existing.id;
          n++;
        } else {
          localId = existing.id;
        }
        // Local row wins: do not overwrite hangout/attendees when dirty.
        if (!(existing?.dirty ?? false)) {
          final hangout = g['hangoutLink'] as String?;
          if (hangout != null) {
            await (_db.update(_db.events)..where((e) => e.id.equals(localId)))
                .write(EventsCompanion(meetUrl: Value(hangout)));
          }
          await _mergeAttendees(localId, g);
        }
      } catch (e) {
        // Deliberate external-data isolation, not silent swallowing: a
        // malformed remote item is skipped so the rest of the batch merges,
        // and the failure is still logged by type. Never log titles, attendee
        // emails, or remote ids here.
        debugPrint('[sync] merge item failed type=${e.runtimeType}');
        continue;
      }
    }
    return n;
  }

  Future<void> _mergeAttendees(String eventId, Map<String, dynamic> g) async {
    final atts = g['attendees'] as List?;
    if (atts == null) return;
    final organizerEmail = (g['organizer'] as Map?)?['email'] as String?;
    await _db.transaction(() async {
      await (_db.delete(
        _db.eventAttendees,
      )..where((a) => a.eventId.equals(eventId))).go();
      for (final a in atts) {
        final m = a as Map<String, dynamic>;
        final email = m['email'] as String?;
        if (email == null || email.isEmpty) continue;
        // SECURITY: isSelf/isOrganizer come from the signed-in user's own
        // Google data; never trust client-side state for access control.
        final isSelfFlag =
            m['self'] == true ||
            (account != null && email.toLowerCase() == account!.toLowerCase());
        final isOrganizerFlag =
            m['organizer'] == true ||
            (organizerEmail != null &&
                email.toLowerCase() == organizerEmail.toLowerCase());
        await _db
            .into(_db.eventAttendees)
            .insert(
              EventAttendeesCompanion.insert(
                id: newId(),
                eventId: eventId,
                email: email,
                name: Value(m['displayName'] as String?),
                rsvp: Value(m['responseStatus'] as String?),
                isOrganizer: Value(isOrganizerFlag),
                isSelf: Value(isSelfFlag),
              ),
            );
      }
    });
  }
}
