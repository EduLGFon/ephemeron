import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';

import 'stream_route_params.dart';

class StreamPlaceholderScreen extends StatelessWidget {
  const StreamPlaceholderScreen({super.key, this.date, this.zoom});

  final DateTime? date;
  final String? zoom;

  @override
  Widget build(BuildContext context) {
    final state = GoRouterState.of(context);
    final resolvedDate =
        date ?? tryParseStreamDate(state.pathParameters['date']);
    final resolvedZoom = zoom ?? state.pathParameters['zoom'];
    final params = parseStreamRouteParams(
      date: resolvedDate == null ? null : formatStreamDate(resolvedDate),
      zoom: resolvedZoom,
    );
    return Scaffold(
      body: Center(
        child: Text('${formatStreamDate(params.date)} ${params.zoom}'),
      ),
    );
  }
}
