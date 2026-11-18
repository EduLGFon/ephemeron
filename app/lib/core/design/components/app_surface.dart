// Flat tonal surface used for cards, panels and grouped settings. One hairline
// border carries the shape: no elevation, blur or shadow.
import 'package:material_ui/material_ui.dart';

import '../tokens.dart';

class AppSurface extends StatelessWidget {
  const AppSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(DsSpace.x16),
    this.radius = DsRadius.r16,
    this.tonal = false,
    this.border = true,
    this.onTap,
    this.semanticLabel,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final bool tonal;
  final bool border;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: border ? BorderSide(color: scheme.outlineVariant) : BorderSide.none,
    );
    final color = tonal
        ? scheme.surfaceContainerHigh
        : scheme.surfaceContainerLow;
    final content = Padding(padding: padding, child: child);
    final onTap = this.onTap;

    final surface = onTap == null
        ? Material(
            color: color,
            shape: shape,
            clipBehavior: Clip.none,
            child: content,
          )
        : Material(
            color: color,
            shape: shape,
            clipBehavior: Clip.none,
            child: InkWell(
              onTap: onTap,
              customBorder: shape,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: content,
              ),
            ),
          );

    final label = semanticLabel;
    if (label == null) return surface;
    return Semantics(
      container: true,
      label: label,
      button: onTap != null,
      onTap: onTap,
      child: ExcludeSemantics(child: surface),
    );
  }
}
