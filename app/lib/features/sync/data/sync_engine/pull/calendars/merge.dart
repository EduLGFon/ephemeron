part of '../../../sync_engine.dart';

extension on SyncEngine {
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
        Event? masterRow;
        if (isException && masterRemoteId != null) {
          masterRow =
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
            final companion = _inheritExceptionFields(
              g,
              masterRow,
              mapped.companion,
              isNew: true,
            );
            await _db
                .into(_db.events)
                .insert(
                  companion.copyWith(
                    googleAccount: Value(owner),
                    deletedAt: const Value(null),
                    status: const Value('cancelled'),
                  ),
                );
            n++;
          } else if (!localException.dirty) {
            final current = localException;
            final companion = _inheritExceptionFields(
              g,
              masterRow,
              mapped.companion,
              isNew: false,
            );
            await (_db.update(
              _db.events,
            )..where((e) => e.id.equals(current.id))).write(
              companion.copyWith(
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
          final companion = _inheritExceptionFields(
            g,
            masterRow,
            mapped.companion,
            isNew: true,
          );
          await _db
              .into(_db.events)
              .insert(
                companion.copyWith(
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
          final companion = _inheritExceptionFields(
            g,
            masterRow,
            mapped.companion,
            isNew: false,
          );
          await (_db.update(
            _db.events,
          )..where((e) => e.id.equals(existing.id))).write(
            companion.copyWith(
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

/// Keeps master-derived fields when a remote exception omits them.
///
/// New exception rows inherit the master's location, Meet link, visibility,
/// transparency, and local reminder/alarm values. Updates omit fields the
/// remote instance did not send so an existing local value is not nulled.
EventsCompanion _inheritExceptionFields(
  Map<String, dynamic> g,
  Event? master,
  EventsCompanion mapped, {
  required bool isNew,
}) {
  if (master == null) return mapped;
  var out = mapped;
  if (g['location'] == null) {
    out = out.copyWith(
      location: isNew ? Value(master.location) : const Value.absent(),
    );
  }
  if (g['hangoutLink'] == null) {
    out = out.copyWith(
      meetUrl: isNew ? Value(master.meetUrl) : const Value.absent(),
    );
  }
  if (g['visibility'] == null) {
    out = out.copyWith(
      visibility: isNew ? Value(master.visibility) : const Value.absent(),
    );
  }
  if (g['transparency'] == null) {
    out = out.copyWith(
      transparency: isNew ? Value(master.transparency) : const Value.absent(),
    );
  }
  if (isNew) {
    out = out.copyWith(
      reminders: Value(master.reminders),
      alarmPreset: Value(master.alarmPreset),
    );
  }
  return out;
}
