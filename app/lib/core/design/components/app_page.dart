// Standard page scaffold for every screen. The page owns the scaffold, safe
// areas, the optional header and FAB, and the centered content cap on expanded
// layouts. The child owns its scrollable so pages never nest scroll views just
// to get consistent chrome.
import 'package:material_ui/material_ui.dart';

import '../layout.dart';
import '../tokens.dart';

class AppPage extends StatelessWidget {
  const AppPage({
    super.key,
    required this.child,
    this.header,
    this.fab,
    this.bottomBar,
    this.padding = const EdgeInsets.symmetric(horizontal: DsSpace.x16),
    this.maxWidth = DsBreakpoints.contentMax,
    this.backgroundColor,
  });

  final Widget child;
  final Widget? header;
  final Widget? fab;
  final Widget? bottomBar;
  final EdgeInsetsGeometry padding;
  final double maxWidth;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    // The shell normally publishes the layout. Until it does, compact is the
    // safe fallback: never assert on a missing scope inside shared components.
    final layout = AppLayoutScope.maybeOf(context) ?? AppLayout.compact;
    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        ?header,
        Expanded(
          child: Padding(padding: padding, child: child),
        ),
      ],
    );

    return Scaffold(
      backgroundColor: backgroundColor,
      floatingActionButton: fab,
      bottomNavigationBar: bottomBar,
      body: SafeArea(
        top: false,
        child: layout == AppLayout.expanded
            ? Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: column,
                ),
              )
            : column,
      ),
    );
  }
}
