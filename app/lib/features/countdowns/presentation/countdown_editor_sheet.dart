// Countdown editor bottom sheet: create and edit.
import 'package:material_ui/material_ui.dart';
import 'package:ephemeron/core/time/device_date_format.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/session/session_restore.dart';
import '../../../core/platform/app_permissions.dart';
import '../../../core/time/picker_memory.dart';
import '../../../core/ui/app_sheet.dart';
import '../../../core/ui/escape_to_close.dart';
import '../../../data/drift/app_database.dart';
import '../../../data/repositories/countdown_repository.dart';
import '../../../domain/alarms/alarm_preset.dart';
import '../../alarms/presentation/alarm_preset_picker.dart';
import '../../settings/application/settings_providers.dart';
import '../../settings/data/settings_repository.dart';
import '../application/countdowns_providers.dart';
import 'countdown_formatters.dart';

part 'countdown_editor_sheet/draft.dart';
part 'countdown_editor_sheet/form.dart';
part 'countdown_editor_sheet/actions.dart';

Future<void> showCountdownEditor(
  BuildContext context, {
  Countdown? countdown,
  Map<String, dynamic>? restoredDraft,
  String? linkedType,
  String? linkedId,
  String? initialTitle,
  DateTime? initialDate,
}) {
  return showAppSheet<void>(
    context,
    builder: (_) => EscapeToClose(
      child: _CountdownEditorSheet(
        countdown: countdown,
        restoredDraft: restoredDraft,
        linkedType: linkedType,
        linkedId: linkedId,
        initialTitle: initialTitle,
        initialDate: initialDate,
      ),
    ),
  );
}

class _CountdownEditorSheet extends ConsumerStatefulWidget {
  const _CountdownEditorSheet({
    this.countdown,
    this.restoredDraft,
    this.linkedType,
    this.linkedId,
    this.initialTitle,
    this.initialDate,
  });

  final Countdown? countdown;
  final Map<String, dynamic>? restoredDraft;
  final String? linkedType;
  final String? linkedId;
  final String? initialTitle;
  final DateTime? initialDate;

  @override
  ConsumerState<_CountdownEditorSheet> createState() =>
      _CountdownEditorSheetState();
}

class _CountdownEditorSheetState extends ConsumerState<_CountdownEditorSheet> {
  late final TextEditingController _title;
  late final TextEditingController _notes;
  DateTime? _date;
  bool _yearlyRepeat = false;
  bool _showAge = false;
  int _alertOffsetDays = 3;
  int _alertHour = 9;
  int _alertMinute = 0;
  String? _alarmPreset;
  String? _linkedType;
  String? _linkedId;
  DraftAutosaver? _saver;
  bool _saved = false;
  SettingsRepository? _settings;

  @override
  void initState() {
    super.initState();
    _initFromArgs();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _saver ??= DraftAutosaver(
      ref.read(draftStoreProvider),
      'countdown',
      _draftEntityId,
    );
    Future.microtask(() async {
      try {
        final repo = await ref.read(settingsRepositoryProvider.future);
        _settings = repo;
        await repo.setOpenSheet(
          widget.countdown == null
              ? 'countdown_new'
              : 'countdown:${widget.countdown!.id}',
        );
      } catch (_) {}
    });
  }

  void _changed(void Function() fn) {
    setState(fn);
    _queueDraft();
  }

  @override
  void dispose() {
    if (!_saved) {
      final snap = _snapshot();
      _saver?.changed(() => snap);
    }
    _saver?.dispose();
    final settings = _settings;
    // Normal close clears the marker; process kill skips dispose
    // so the marker survives kills. Drafts are kept for preload.
    if (settings != null) {
      final expected = _expectedSheet();
      Future.microtask(() async {
        try {
          if (settings.openSheet == expected) {
            await settings.setOpenSheet(null);
          }
        } catch (_) {}
      });
    }
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottom),
      child: SingleChildScrollView(child: _buildForm(context)),
    );
  }
}
