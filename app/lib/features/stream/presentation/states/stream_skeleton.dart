// Local loading skeleton for GENUINELY REMOTE content only. Never use this for
// local Drift data: offline-first means local data renders instantly without
// a spinner. Tonal blocks pulse via a single AnimationController. Respects
// reduce motion (static under reduce motion).
import 'package:material_ui/material_ui.dart';

class StreamSkeleton extends StatefulWidget {
  const StreamSkeleton({super.key, this.itemCount = 3});

  final int itemCount;

  @override
  State<StreamSkeleton> createState() => _StreamSkeletonState();
}

class _StreamSkeletonState extends State<StreamSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  bool? _reduced;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (_reduced == reduced) return;
    _reduced = reduced;
    if (reduced) {
      _controller.stop();
      _controller.value = 0.7;
    } else {
      _controller.repeat(reverse: true, min: 0.35, max: 0.9);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return RepaintBoundary(
      child: FadeTransition(
        opacity: _controller,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < widget.itemCount; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 12,
                            color: scheme.surfaceContainerHighest,
                          ),
                          const SizedBox(height: 6),
                          FractionallySizedBox(
                            widthFactor: 0.6,
                            alignment: Alignment.centerLeft,
                            child: Container(
                              height: 10,
                              color: scheme.surfaceContainerHighest,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
