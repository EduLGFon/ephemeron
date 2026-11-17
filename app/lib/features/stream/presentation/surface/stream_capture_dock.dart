// Bottom dock: unscheduled-task tray above the capture bar. Presentation only;
// the host wires capture execution and tray navigation.
import 'package:material_ui/material_ui.dart';

import '../../capture/capture_parser.dart' show CaptureDraft, CaptureLocale;
import '../capture/capture_bar.dart';
import '../capture/capture_preview_chips.dart';
import '../tray/tray_item.dart';
import '../tray/tray_strip.dart';

// The host lives in its own file to keep this widget small; re-exported so the
// documented surface entry point exposes both symbols.
export 'stream_dock_host.dart';

/// Localized strings for [StreamCaptureDock].
class StreamCaptureDockLabels {
  const StreamCaptureDockLabels({
    required this.captureHint,
    required this.captureLabel,
    required this.submitLabel,
    required this.clearLabel,
    required this.closeLabel,
    required this.trayEmpty,
    required this.trayCount,
    required this.trayHandle,
  });

  final String captureHint;
  final String captureLabel;
  final String submitLabel;
  final String clearLabel;
  final String closeLabel;
  final String trayEmpty;
  final String trayCount;
  final String trayHandle;
}

/// Tray strip above the capture bar, offset by the keyboard inset.
///
/// The screen owns SafeArea; this widget adds only the keyboard padding so the
/// dock is not pushed under the keyboard or double-inset at the bottom.
class StreamCaptureDock extends StatelessWidget {
  const StreamCaptureDock({
    super.key,
    required this.now,
    required this.locale,
    required this.items,
    required this.labels,
    required this.chipsBuilder,
    this.onSubmitted,
    this.onDismiss,
    this.onExpandRequested,
    this.onItemTap,
  });

  final DateTime now;
  final CaptureLocale locale;
  final List<TrayItem> items;
  final StreamCaptureDockLabels labels;
  final List<CapturePreviewChip> Function(CaptureDraft draft) chipsBuilder;
  final ValueChanged<CaptureDraft>? onSubmitted;
  final VoidCallback? onDismiss;
  final VoidCallback? onExpandRequested;
  final ValueChanged<String>? onItemTap;

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return AnimatedPadding(
      key: const Key('streamDockKeyboardPadding'),
      duration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: inset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TrayStrip(
            items: items,
            countSemanticsLabel: labels.trayCount,
            handleSemanticsLabel: labels.trayHandle,
            emptyLabel: labels.trayEmpty,
            onExpandRequested: onExpandRequested ?? _noop,
            onTap: onItemTap,
          ),
          CaptureBar(
            now: now,
            locale: locale,
            hintText: labels.captureHint,
            label: labels.captureLabel,
            semanticsLabel: labels.captureLabel,
            submitLabel: labels.submitLabel,
            clearLabel: labels.clearLabel,
            closeLabel: labels.closeLabel,
            chipsBuilder: chipsBuilder,
            onSubmitted: onSubmitted,
            onDismiss: onDismiss,
          ),
        ],
      ),
    );
  }
}

void _noop() {}
