// Quick-add bottom sheet: one field with shorthand and NLP parsing,
// live icon-led preview, save and save-and-add-another.
// Unsaved text autosaves (debounced) and restores after restart.
//
// The sheet is a single Dart library split into `part` files under
// presentation/quick_add_sheet/ so shorthand helpers, lifecycle, save, and
// view stay focused while private members remain shared within the library.
// The entry point and import path are unchanged for existing importers.
import 'package:flutter/material.dart';
import 'package:ephemeron/core/theme/theme_tokens.dart';
import 'package:ephemeron/core/time/device_date_format.dart';
import 'package:ephemeron/core/ui/app_feedback.dart';
import 'package:ephemeron/core/ui/app_sheet.dart';
import 'package:ephemeron/core/ui/sheet_padding.dart';
import 'package:ephemeron/core/ui/escape_to_close.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/session/session_restore.dart';
import '../../../data/drift/app_database.dart';
import '../../../domain/parsing/quick_add_parser.dart';
import '../../settings/application/settings_providers.dart';
import '../application/tasks_providers.dart';

part 'quick_add_sheet/lifecycle.dart';
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

Future<void> showQuickAdd(
  BuildContext context, {
  String? initialText,
  Map<String, dynamic>? restoredDraft,
}) {
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

class _QuickAddSheet extends ConsumerStatefulWidget {
  const _QuickAddSheet({this.initialText, this.restoredDraft});

  final String? initialText;
  final Map<String, dynamic>? restoredDraft;

  @override
  ConsumerState<_QuickAddSheet> createState() => _QuickAddSheetState();
}

abstract class _QuickAddSheetStateBase extends ConsumerState<_QuickAddSheet> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  QuickAddParsed? _parsed;
  DraftAutosaver? _saver;
  bool _saved = false;
  bool _justAdded = false;
  dynamic _settings;
}

class _QuickAddSheetState extends _QuickAddSheetStateBase
    with _QuickAddLifecycle, _QuickAddSave, _QuickAddSections {}
