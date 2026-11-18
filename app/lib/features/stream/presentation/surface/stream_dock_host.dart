// Wires the Stream dock to capture actions and tray navigation. Watching the
// tray here keeps tray emissions from rebuilding the whole Stream screen.
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'package:ephemeron/l10n/src/app_localizations.dart';

import '../../../../core/ui/app_feedback.dart';
import '../../../../core/ui/app_sheet.dart';
import '../../../tasks/application/tasks_providers.dart' show openTasksProvider;
import '../../../tasks/presentation/task_editor_sheet.dart' show showTaskEditor;
import '../../application/stream_capture_actions.dart';
import '../../application/stream_tray.dart';
import '../../capture/capture_parser.dart' show CaptureDraft, CaptureLocale;
import '../tray/tray_item.dart';
import '../tray/tray_panel.dart';
import 'stream_capture_chips.dart';
import 'stream_capture_dock.dart';
import 'stream_permission_banner_host.dart';

class StreamDockHost extends ConsumerWidget {
  const StreamDockHost({super.key, required this.now, required this.locale});

  final DateTime now;
  final CaptureLocale locale;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items =
        ref.watch(streamTrayItemsProvider).value ?? const <TrayItem>[];
    final l = AppLocalizations.of(context);
    final localeName = Localizations.localeOf(context).toLanguageTag();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const StreamPermissionBannerHost(),
        StreamCaptureDock(
          now: now,
          locale: locale,
          items: items,
          labels: StreamCaptureDockLabels(
            captureHint: l.streamCaptureHint,
            captureLabel: l.streamCaptureLabel,
            submitLabel: l.streamCaptureSubmit,
            clearLabel: l.streamCaptureClear,
            closeLabel: l.streamCaptureClose,
            trayEmpty: l.streamTrayEmpty,
            trayCount: l.streamTrayCount(items.length),
            trayHandle: l.streamTrayHandle,
          ),
          chipsBuilder: (draft) =>
              buildStreamCaptureChips(draft, l: l, localeName: localeName),
          onSubmitted: (draft) => unawaited(_submit(context, ref, draft)),
          onDismiss: () => FocusScope.of(context).unfocus(),
          onExpandRequested: () => _expand(context, ref, l, items),
          onItemTap: (id) => _openTask(context, ref, id),
        ),
      ],
    );
  }

  Future<void> _submit(
    BuildContext context,
    WidgetRef ref,
    CaptureDraft draft,
  ) async {
    final l = AppLocalizations.of(context);
    try {
      await ref.read(streamCaptureActionsProvider).submit(draft, now: now);
      if (!context.mounted) return;
      AppFeedback.success();
      showAppSnackBar(
        context,
        l.streamCaptureCaptured,
        icon: Icons.check_circle_outline,
      );
    } catch (_) {
      if (!context.mounted) return;
      AppFeedback.error();
      showErrorSnackBar(context, l.streamCaptureFailed);
    }
  }

  void _expand(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l,
    List<TrayItem> items,
  ) {
    unawaited(
      showAppSheet<void>(
        context,
        builder: (sheetContext) => Semantics(
          container: true,
          label: l.streamTrayPanelTitle,
          child: TrayPanel(
            items: items,
            emptyLabel: l.streamTrayEmpty,
            unnamedGroupLabel: l.streamTrayUnnamed,
            collapseLabel: l.streamTrayCollapse,
            onCollapseRequested: () => Navigator.of(sheetContext).pop(),
            onItemTap: (id) {
              Navigator.of(sheetContext).pop();
              _openTask(context, ref, id);
            },
          ),
        ),
      ),
    );
  }

  /// Opens the existing task editor for a tray item. When open tasks are not
  /// loaded yet (or the id is gone), falls back to the Tasks tab; without a
  /// router, reports the failure instead of silently doing nothing.
  void _openTask(BuildContext context, WidgetRef ref, String id) {
    final task = ref
        .read(openTasksProvider(null))
        .value
        ?.where((task) => task.id == id)
        .firstOrNull;
    if (task != null) {
      unawaited(showTaskEditor(context, task: task));
      return;
    }
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      router.go('/tab1');
      return;
    }
    showErrorSnackBar(
      context,
      AppLocalizations.of(context).streamTrayTaskUnavailable,
    );
  }
}
