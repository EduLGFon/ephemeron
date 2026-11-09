part of '../../event_editor_sheet.dart';

extension on _EventEditorState {
  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Title is required.')));
      return;
    }
    if (_calendarId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Select a calendar.')));
      return;
    }
    // Moment of need: reminders/alarms only prompt here, at save time.
    // Advisory only: the save always proceeds, alerts may stay silent.
    if (_reminders.isNotEmpty || _alarmPreset != null) {
      final preset = AlarmPreset.tryParse(_alarmPreset);
      await AppPermissions.ensureAlarmPrereqs(
        context,
        exactAlarm: preset?.needsAlarmClock ?? false,
        fullScreen: preset?.usesFullScreen ?? false,
      );
      if (!mounted) return;
    }
    if (widget.event != null && _isMicrosoftEvent) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microsoft events cannot be edited.')),
        );
      }
      return;
    }
    final repo = ref.read(eventRepositoryProvider);
    final existing = widget.event;
    // Exception editors carry the master id and the occurrence's original
    // start. Edits, moves and attendee changes target the series.
    final master = existing?.recurringMasterId == null
        ? existing
        : await repo.getEvent(existing!.recurringMasterId!);
    final seriesId = master?.id ?? existing?.id;
    final seriesRrule = master?.rrule;
    final isSeries = seriesRrule != null && seriesRrule.isNotEmpty;
    // Exception rows carry no rule of their own; recurrence belongs to the
    // master unless this is a master edit.
    final effectiveRrule = existing?.recurringMasterId != null
        ? seriesRrule
        : _rrule;
    if (existing != null &&
        _calendarId != null &&
        _calendarId != existing.calendarId) {
      try {
        await repo.moveEventToCalendar(seriesId ?? existing.id, _calendarId!);
      } on SourceMoveException catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(e.message)));
        }
        return;
      }
    }
    // Conflict hint: warn if overlapping a busy event. Exclude both the
    // selected row and its master so an exception does not conflict with
    // itself.
    if (!_allDay) {
      final overlaps = [
        for (final e in await repo.overlappingEvents(
          calendarId: _calendarId!,
          startUtc: _start.toUtc(),
          endUtc: _end.toUtc(),
          excludeId: seriesId,
        ))
          if (e.id != existing?.id) e,
      ];
      if (overlaps.isNotEmpty && mounted) {
        final proceed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Scheduling conflict'),
            content: Text(
              'This overlaps ${overlaps.length} existing event(s). Save anyway?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Save'),
              ),
            ],
          ),
        );
        if (proceed != true) return;
      }
    }
    final settings = await ref.read(settingsRepositoryProvider.future);
    _calendarId ??= settings.defaultCalendarId;
    final notesPayload = _notesPayload();
    final startDateKey = _allDay ? _fmtDate(_start) : null;
    final endDateKey = _allDay
        ? _fmtDate(DateTime(_end.year, _end.month, _end.day + 1))
        : null;
    if (existing == null || !isSeries) {
      if (existing == null) {
        final eventId = await repo.createEvent(
          calendarId: _calendarId!,
          title: title,
          startUtc: _allDay ? null : _start.toUtc(),
          endUtc: _allDay ? null : _end.toUtc(),
          startDate: startDateKey,
          endDate: endDateKey,
          allDay: _allDay,
          // SECURITY: store null (floating local time) for device-created
          // events. DateTime.now().timeZoneName yields abbreviations like
          // "-03" that are not IANA ids and crash tz.getLocation lookups.
          tzId: _tzId,
          colorId: _colorId,
          createMeet: _addMeet,
          rrule: _rrule,
          location: _location.text.trim().isEmpty
              ? null
              : _location.text.trim(),
          notes: notesPayload.stored,
          reminders: encodeReminderOffsets(_reminders),
          alarmPreset: _alarmPreset,
        );
        await _syncDescription(eventId, notesPayload.full);
        await repo.setAttendees(eventId, _attendees.text.split(','));
      } else {
        final eventId = await repo.editOccurrence(
          existing.id,
          _originalStartOf(existing),
          scope: EditScope.all,
          title: title,
          startUtc: _allDay ? null : _start.toUtc(),
          endUtc: _allDay ? null : _end.toUtc(),
          startDate: startDateKey,
          endDate: endDateKey,
          location: _location.text.trim().isEmpty
              ? null
              : _location.text.trim(),
          colorId: _colorId,
          tzId: _tzId,
          createMeet: _addMeet,
          reminders: () => encodeReminderOffsets(_reminders),
          alarmPreset: () => _alarmPreset,
          notes: () => notesPayload.stored,
        );
        await _syncDescription(eventId, notesPayload.full);
        await repo.setAttendees(
          seriesId ?? eventId,
          _attendees.text.split(','),
        );
      }
      await _clearDraftAfterSave();
      if (mounted) Navigator.of(context).pop();
      return;
    }
    if (!mounted) return;
    final scope = await showScopeSheet(
      context,
      allowSingle: effectiveRrule == seriesRrule,
    );
    if (scope == null) return;
    if (!mounted) return;
    final datesChanged = _allDay
        ? startDateKey != existing.startDate || endDateKey != existing.endDate
        : _start.toUtc().millisecondsSinceEpoch != existing.startUtc ||
              _end.toUtc().millisecondsSinceEpoch != existing.endUtc;
    if (scope == EditScope.all && datesChanged) {
      final keep =
          await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Keep per-event changes?'),
              content: const Text(
                'Some occurrences were changed individually.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('Keep'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Reset'),
                ),
              ],
            ),
          ) ??
          true;
      if (!mounted) return;
      final eventId = await repo.editOccurrence(
        seriesId!,
        _originalStartOf(existing),
        scope: EditScope.all,
        title: title,
        startUtc: _allDay ? null : _start.toUtc(),
        endUtc: _allDay ? null : _end.toUtc(),
        startDate: startDateKey,
        endDate: endDateKey,
        rrule: () => effectiveRrule,
        resetExceptions: !keep,
        notes: () => notesPayload.stored,
      );
      await _syncDescription(eventId, notesPayload.full);
      await repo.setAttendees(seriesId, _attendees.text.split(','));
      await _clearDraftAfterSave();
      if (mounted) Navigator.of(context).pop();
      return;
    }
    final eventId = await repo.editOccurrence(
      seriesId!,
      _originalStartOf(existing),
      scope: scope,
      title: title,
      startUtc: _allDay ? null : _start.toUtc(),
      endUtc: _allDay ? null : _end.toUtc(),
      startDate: startDateKey,
      endDate: endDateKey,
      rrule: scope == EditScope.single ? null : () => effectiveRrule,
      notes: () => notesPayload.stored,
    );
    if (mounted) {
      await _syncDescription(eventId, notesPayload.full);
      // A single-occurrence exception has nowhere to store attendees of its
      // own; keep the master untouched instead of silently editing the series.
      final updateSeriesAttendees =
          scope != EditScope.single || existing.recurringMasterId == null;
      if (updateSeriesAttendees) {
        await repo.setAttendees(seriesId, _attendees.text.split(','));
      }
      try {
        final range = ref.read(calendarCacheRangeProvider);
        await ref
            .read(occurrenceRepositoryProvider)
            .rebuildWindow(
              windowStartUtc: range.fromUtc,
              windowEndUtc: range.toUtc,
            );
      } catch (_) {
        // Best-effort; next navigation rebuilds.
      }
      await _clearDraftAfterSave();
      if (mounted) Navigator.of(context).pop();
    }
  }
}
