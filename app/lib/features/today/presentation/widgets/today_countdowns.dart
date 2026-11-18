// Compact countdown cards on Today, capped at three with a "See all" action.
import 'package:material_ui/material_ui.dart';

import '../../../../core/design/components/app_buttons.dart';
import '../../../../core/design/components/app_headers.dart';
import '../../../../core/design/components/rows.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/time/device_date_format.dart';
import '../../../countdowns/presentation/countdown_formatters.dart'
    show countdownRelativeLabel;
import '../../application/today_providers.dart';
import '../today_strings.dart';

class TodayCountdowns extends StatelessWidget {
  const TodayCountdowns({
    super.key,
    required this.items,
    required this.onSeeAll,
  });

  final List<TodayCountdown> items;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    final strings = TodayStrings.of(context);
    final visible = items.where((item) => item.days >= 0).take(3).toList();
    if (visible.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SectionTitle(
          title: strings.countdownsTitle,
          count: visible.length,
          action: AppButton(
            label: strings.seeAll,
            variant: AppButtonVariant.ghost,
            onPressed: onSeeAll,
          ),
        ),
        for (final item in visible)
          Padding(
            padding: const EdgeInsets.only(bottom: DsSpace.x8),
            child: AppCountdownCard(
              key: ValueKey<String>('today-countdown-${item.countdown.id}'),
              title: item.countdown.title,
              days: item.days,
              dateLabel:
                  '${DeviceDateFormat.date(context, item.next)} - '
                  '${countdownRelativeLabel(item.days)}',
              yearly: item.countdown.yearlyRepeat,
              compact: true,
              onTap: onSeeAll,
            ),
          ),
      ],
    );
  }
}
