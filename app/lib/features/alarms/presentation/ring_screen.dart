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
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../core/db/db_provider.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../core/ui/app_feedback.dart';
import '../../../data/drift/app_database.dart';
import '../../../domain/alarms/alarm_preset.dart';
import '../application/alarm_providers.dart';
import '../data/alarm_repository.dart';
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

abstract class _RingScreenStateBase extends ConsumerState<RingScreen> {
  Timer? _auto;
  bool _busy = false;
}

class _RingScreenState extends _RingScreenStateBase
    with _RingScreenLifecycle, _RingScreenActions, _RingScreenView {}
