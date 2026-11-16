// Ring screen: cannot be dismissed with back; Snooze, Dismiss, or a
// context action is required. Auto-snoozes after 30 s of no interaction.
//
// The screen is a single Dart library split into `part` files under
// presentation/ring_screen/ so lifecycle, actions, and view stay focused while
// private members remain shared within the library. The entry point and import
// path are unchanged for existing importers.
import 'dart:async';

// drift query extensions.
// ignore: unused_import
import 'package:drift/drift.dart' hide Column;
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../core/db/db_provider.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../core/ui/app_feedback.dart';
import '../../../core/ui/app_messenger.dart';
import '../../../data/drift/app_database.dart';
import '../../../domain/alarms/alarm_preset.dart';
import '../application/alarm_providers.dart';
import '../data/alarm_repository.dart';
import '../data/alarm_scheduler.dart';
import 'alarm_preset_picker.dart';
import 'alarm_source_route.dart';

part 'ring_screen/actions.dart';
part 'ring_screen/lifecycle.dart';
part 'ring_screen/view.dart';

class RingScreen extends ConsumerStatefulWidget {
  const RingScreen({super.key});

  @override
  ConsumerState<RingScreen> createState() => _RingScreenState();
}

abstract class _RingScreenStateBase extends ConsumerState<RingScreen>
    with WidgetsBindingObserver {
  Timer? _auto;
  bool _busy = false;

  /// Set once an explicit action or an auto-snooze handles this ring, so
  /// dispose, route changes, and lifecycle pauses cannot snooze twice.
  bool _handled = false;
  GoRouter? _router;

  /// Implemented by the actions mixin. Declared here so the lifecycle and
  /// view parts share one signature.
  Future<void> _snooze({
    int minutes,
    int? code,
    // ignore: unused_element_parameter
    bool leaveRoute,
    // ignore: unused_element_parameter
    String? snackBarMessage,
  });

  Future<void> _act(
    int? code,
    Future<void> Function(int requestCode) action, {
    required bool rebuild,
    String? destination,
    bool successFeedback,
    // ignore: unused_element_parameter
    bool leaveRoute,
    // ignore: unused_element_parameter
    String? snackBarMessage,
  });
}

class _RingScreenState extends _RingScreenStateBase
    with _RingScreenLifecycle, _RingScreenActions, _RingScreenView {}
