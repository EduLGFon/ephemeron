// Settings hub. Every control maps to a persisted SettingsRepository value;
// sections are grouped in flat AppSurfaces; search is reached from the
// title-row search button and opens the global search screen.
import 'package:ephemeron/core/design/components/app_buttons.dart';
import 'package:ephemeron/core/design/components/app_chips.dart';
import 'package:ephemeron/core/design/components/app_headers.dart';
import 'package:ephemeron/core/design/components/app_overlays.dart';
import 'package:ephemeron/core/design/components/app_page.dart';
import 'package:ephemeron/core/design/components/app_states.dart';
import 'package:ephemeron/core/design/components/app_surface.dart';
import 'package:ephemeron/core/design/components/sync_indicator.dart';
import 'package:ephemeron/core/design/platform.dart';
import 'package:ephemeron/core/design/tokens.dart';
import 'package:ephemeron/core/platform/app_permissions.dart';
import 'package:ephemeron/core/platform/system_launcher.dart';
import 'package:ephemeron/core/security/app_lock.dart';
import 'package:ephemeron/core/theme/theme_tokens.dart';
import 'package:ephemeron/core/time/device_date_format.dart';
import 'package:ephemeron/core/ui/app_feedback.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/shell/destinations.dart';
import '../../alarms/application/alarm_providers.dart';
import '../../alarms/data/alarm_scheduler.dart';
import '../../auth/presentation/auth_screen.dart';
import '../../calendar/presentation/calendar_settings_screen.dart';
import '../../sync/application/sync_providers.dart';
import '../../sync/data/sync_engine.dart';
import '../../sync/presentation/sync_issues_screen.dart';
import '../../tasks/presentation/task_lists_screen.dart';
import '../application/settings_providers.dart';
import '../data/settings_repository.dart';
import 'backup_section.dart';
import 'home_widgets_screen.dart';
import 'nav_order_sheet.dart';
import 'settings_strings.dart';

part 'settings_screen/settings_screen_state.dart';
part 'settings_screen/settings_screen_view.dart';
part 'settings_sections/settings_rows.dart';
part 'settings_sections/settings_choices.dart';
part 'settings_sections/settings_pickers.dart';
part 'settings_sections/account_sync_section.dart';
part 'settings_sections/notifications_section.dart';
part 'settings_sections/appearance_section.dart';
part 'settings_sections/time_shortcuts_section.dart';
part 'settings_sections/data_security_section.dart';
part 'settings_sections/navigation_about_section.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}
