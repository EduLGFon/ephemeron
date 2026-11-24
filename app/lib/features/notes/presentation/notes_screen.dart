// Notes screen: nested folders with breadcrumbs, note list with counts,
// trash, new note / new folder. Search opens the global search screen.
//
// Split across `notes_screen/` parts; this file stays the stable import
// path for callers.
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:ephemeron/core/design/components/app_buttons.dart';
import 'package:ephemeron/core/design/components/app_chips.dart';
import 'package:ephemeron/core/design/components/app_headers.dart';
import 'package:ephemeron/core/design/components/app_overlays.dart';
import 'package:ephemeron/core/design/components/app_page.dart';
import 'package:ephemeron/core/design/components/app_states.dart';
import 'package:ephemeron/core/design/components/app_surface.dart';
import 'package:ephemeron/core/design/tokens.dart';
import 'package:ephemeron/core/ui/app_feedback.dart';
import 'package:ephemeron/core/ui/app_sheet.dart';
import 'package:ephemeron/core/ui/dialogs.dart';
import 'package:ephemeron/core/ui/escape_to_close.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/time/device_date_format.dart';
import '../../../data/drift/app_database.dart';
import '../../settings/application/settings_providers.dart';
import '../../sync/application/pending_operations.dart';
import '../application/notes_providers.dart';
import 'markdown_preview.dart';
import 'note_editor_screen.dart';
import 'notes_strings.dart';

part 'notes_screen/notes_screen_view.dart';
part 'notes_screen/dialogs.dart';
part 'notes_screen/notes_list.dart';
part 'notes_screen/note_tiles.dart';
part 'notes_screen/breadcrumbs.dart';
part 'notes_screen/trash_screen.dart';
part 'notes_screen/error_state.dart';
part 'notes_screen/search_results.dart';
