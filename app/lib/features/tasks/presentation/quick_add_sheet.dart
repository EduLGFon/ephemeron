// Quick-add sheet: one autofocused field for tasks, events, habits and
// countdowns. Type/date/list/priority chips adjust the parsed result and the
// preview stays a fixed height so typing never shifts the sheet.
//
// Unsaved text autosaves (debounced) and restores after restart. The sheet is
// a single Dart library split into `part` files under
// presentation/quick_add_sheet/ so shorthand helpers, lifecycle, save, preview
// and view stay focused while private members remain shared within the library.
// The entry point and import path are unchanged for existing importers.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/session/session_restore.dart';
import '../../../core/design/components/app_buttons.dart';
import '../../../core/design/components/app_chips.dart';
import '../../../core/design/components/app_fields.dart';
import '../../../core/design/components/app_overlays.dart';
import '../../../core/design/tokens.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../core/time/device_date_format.dart';
import '../../../core/time/picker_memory.dart';
import '../../../core/ui/app_feedback.dart';
import '../../../core/ui/app_sheet.dart';
import '../../../core/ui/escape_to_close.dart';
import '../../../data/drift/app_database.dart';
import '../../../domain/habits/date_key.dart';
import '../../../domain/parsing/quick_add_parser.dart';
import '../../calendar/application/calendar_providers.dart';
import '../../calendar/presentation/event_editor_sheet.dart';
import '../../countdowns/application/countdowns_providers.dart';
import '../../habits/application/habits_providers.dart';
import '../../settings/application/settings_providers.dart';
import '../../settings/data/settings_repository.dart';
import '../application/tasks_providers.dart';
import 'quick_add_strings.dart';

part 'quick_add_sheet/controls.dart';
part 'quick_add_sheet/lifecycle.dart';
part 'quick_add_sheet/preview.dart';
part 'quick_add_sheet/save.dart';
part 'quick_add_sheet/sections.dart';
part 'quick_add_sheet/shorthand.dart';

/// Date shortcut exposed under the quick-add field. The token is plain text
/// understood by [parseQuickAdd], so editing the input stays the only source
/// of truth.
class QuickAddDateChoice {
  const QuickAddDateChoice(this.label, this.token);

  final String label;
  final String token;
}

const quickAddDateChoices = <QuickAddDateChoice>[
  QuickAddDateChoice('Today', 'today'),
  QuickAddDateChoice('Tomorrow', 'tomorrow'),
  QuickAddDateChoice('Next week', 'in 7 days'),
];

/// Bottom sheet on compact layouts, centered dialog from [DsBreakpoints.compact]
/// up. Draft autosave/restore stays inside [_QuickAddSheet] in both cases.
Future<void> showQuickAdd(
  BuildContext context, {
  String? initialText,
  Map<String, dynamic>? restoredDraft,
}) {
  if (MediaQuery.sizeOf(context).width >= DsBreakpoints.compact) {
    return showAppDialog<void>(
      context: context,
      builder: (_) => EscapeToClose(
        child: _QuickAddDialogFrame(
          child: _QuickAddSheet(
            initialText: initialText,
            restoredDraft: restoredDraft,
            isDialog: true,
          ),
        ),
      ),
    );
  }
  return showAppSheet<void>(
    context,
    builder: (_) => EscapeToClose(
      child: _QuickAddSheet(
        initialText: initialText,
        restoredDraft: restoredDraft,
      ),
    ),
  );
}

enum _QuickAddKind { task, event, habit, countdown }

class _QuickAddSheet extends ConsumerStatefulWidget {
  const _QuickAddSheet({
    this.initialText,
    this.restoredDraft,
    this.isDialog = false,
  });

  final String? initialText;
  final Map<String, dynamic>? restoredDraft;
  final bool isDialog;

  @override
  ConsumerState<_QuickAddSheet> createState() => _QuickAddSheetState();
}

abstract class _QuickAddSheetStateBase extends ConsumerState<_QuickAddSheet> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  QuickAddParsed? _parsed;
  DraftAutosaver? _saver;
  SettingsRepository? _settings;
  bool _saved = false;
  bool _busy = false;
  _QuickAddKind _kind = _QuickAddKind.task;
  DateTime? _pickedDate;
  String? _selectedListId;

  DateTime? get _effectiveDue => _pickedDate ?? _parsed?.due;

  Map<String, dynamic> _snapshot() {
    final text = _controller.text;
    return <String, dynamic>{
      'text': text,
      if (text.trim().isNotEmpty) 'kind': _kind.name,
    };
  }
}

class _QuickAddSheetState extends _QuickAddSheetStateBase
    with _QuickAddLifecycle, _QuickAddSave, _QuickAddSections {}

class _QuickAddDialogFrame extends StatelessWidget {
  const _QuickAddDialogFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final size = MediaQuery.sizeOf(context);
    final scheme = Theme.of(context).colorScheme;
    final border = BorderSide(color: scheme.outlineVariant);
    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: Dialog(
        insetPadding: const EdgeInsets.all(DsSpace.x24),
        elevation: 0,
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(DsRadius.r24)),
          side: border,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 560,
            maxHeight: size.height * 0.9,
          ),
          child: child,
        ),
      ),
    );
  }
}
