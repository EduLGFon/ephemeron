// Today header: greeting, large date, sync state and the two global entries
// (Settings, More). Works at 320dp and 200% text because AppPageHeader stacks
// its actions on narrow widths.
import 'package:material_ui/material_ui.dart';

import '../../../../app/shell/destinations.dart';
import '../../../../core/design/components/app_buttons.dart';
import '../../../../core/design/components/app_headers.dart';
import '../../../../core/design/components/sync_indicator.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/typography.dart';
import '../../../../core/time/device_date_format.dart';
import '../today_strings.dart';

class TodayHeader extends StatelessWidget {
  const TodayHeader({
    super.key,
    required this.now,
    required this.syncState,
    required this.onSettings,
    required this.onSearch,
    required this.onOpenDestination,
  });

  final DateTime now;
  final AppSyncState syncState;
  final VoidCallback onSettings;
  final VoidCallback onSearch;
  final ValueChanged<int> onOpenDestination;

  String _greeting(TodayStrings strings) {
    if (now.hour < 12) return strings.goodMorning;
    if (now.hour < 18) return strings.goodAfternoon;
    return strings.goodEvening;
  }

  @override
  Widget build(BuildContext context) {
    final strings = TodayStrings.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return AppPageHeader(
      padding: EdgeInsets.fromLTRB(
        DsSpace.x16,
        MediaQuery.paddingOf(context).top + DsSpace.x12,
        DsSpace.x16,
        DsSpace.x8,
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            _greeting(strings),
            style: theme.textTheme.labelMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: DsSpace.x4),
          Text(
            '${DeviceDateFormat.weekdayFull(context, now)}, '
            '${DeviceDateFormat.monthDay(context, now)}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: DsType.numeric(
              theme.textTheme.headlineMedium!.copyWith(
                color: scheme.onSurface,
                fontFamily: DsType.fraunces,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
      actions: <Widget>[
        AppSyncIndicator(state: syncState, tooltip: strings.syncTooltip),
        AppIconButton(
          key: const ValueKey<String>('today-settings'),
          icon: Icons.settings_outlined,
          tooltip: strings.settingsTooltip,
          semanticLabel: strings.settingsTooltip,
          onPressed: onSettings,
        ),
        PopupMenuButton<int>(
          key: const ValueKey<String>('today-more'),
          tooltip: strings.moreTooltip,
          icon: const Icon(Icons.more_horiz),
          onSelected: (value) {
            if (value == -1) {
              onSearch();
            } else {
              onOpenDestination(value);
            }
          },
          itemBuilder: (context) => <PopupMenuEntry<int>>[
            PopupMenuItem<int>(
              value: -1,
              child: ListTile(
                leading: const Icon(Icons.search),
                title: Text(strings.search),
              ),
            ),
            for (final id in AppDestination.secondaryIds)
              PopupMenuItem<int>(
                value: id,
                child: ListTile(
                  leading: Icon(AppDestination.byId(id).icon),
                  title: Text(AppDestination.byId(id).title),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
