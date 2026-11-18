// Shell layout breakpoints. The navigation shell resolves the layout once and
// publishes it through [AppLayoutScope]; screens read the inherited value and
// never re-measure the shell width themselves.
import 'package:material_ui/material_ui.dart';

import 'tokens.dart';

enum AppLayout { compact, medium, expanded }

/// Maps a logical width to the shell layout. Boundaries are inclusive on the
/// larger side: 600 becomes medium and 840 becomes expanded.
AppLayout layoutForWidth(double width) {
  if (width < DsBreakpoints.compact) return AppLayout.compact;
  if (width < DsBreakpoints.expanded) return AppLayout.medium;
  return AppLayout.expanded;
}

class AppLayoutScope extends InheritedWidget {
  const AppLayoutScope({super.key, required this.layout, required super.child});

  final AppLayout layout;

  static AppLayout? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AppLayoutScope>()?.layout;
  }

  static AppLayout of(BuildContext context) {
    final layout = maybeOf(context);
    assert(
      layout != null,
      'AppLayoutScope.of() called without an AppLayoutScope ancestor',
    );
    return layout!;
  }

  @override
  bool updateShouldNotify(AppLayoutScope oldWidget) =>
      layout != oldWidget.layout;
}
