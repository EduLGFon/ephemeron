// Requests the Stream day occurrence cache without rebuilding its child.
// See ARCHITECTURE.md.
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'stream_day_cache.dart';
import 'stream_day_providers.dart' show StreamDayKey, streamDayRange;

/// Ensures the cache covers [day] after the frame, on mount and day change.
///
/// Reads providers only from the post-frame callback so the scope's build
/// never touches provider state and [child] is not rebuilt by cache changes.
class StreamDayCacheScope extends ConsumerStatefulWidget {
  const StreamDayCacheScope({
    super.key,
    required this.day,
    required this.child,
  });

  final StreamDayKey day;
  final Widget child;

  @override
  ConsumerState<StreamDayCacheScope> createState() =>
      _StreamDayCacheScopeState();
}

class _StreamDayCacheScopeState extends ConsumerState<StreamDayCacheScope> {
  @override
  void initState() {
    super.initState();
    _scheduleEnsure();
  }

  @override
  void didUpdateWidget(covariant StreamDayCacheScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.day != widget.day) _scheduleEnsure();
  }

  void _scheduleEnsure() {
    final range = streamDayRange(widget.day);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        ref.read(streamDayCacheControllerProvider.notifier).ensure(range),
      );
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
