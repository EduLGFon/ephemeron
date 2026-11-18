// First-run onboarding: three skippable pages, local-first by default.
// Notifications are explained here but never requested now; accounts are
// optional and can be added later. Skipping never blocks local use.
import 'package:ephemeron/core/design/components/app_buttons.dart';
import 'package:ephemeron/core/design/components/app_headers.dart';
import 'package:ephemeron/core/design/components/app_page.dart';
import 'package:ephemeron/core/design/tokens.dart';
import 'package:ephemeron/core/ui/app_feedback.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_screen.dart';
import '../application/settings_providers.dart';
import 'settings_strings.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const _pageCount = 3;

  final PageController _pages = PageController();
  int _index = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    final strings = SettingsStrings.of(context);
    try {
      final repo = await ref.read(settingsRepositoryProvider.future);
      await repo.setOnboarded();
      if (!mounted) return;
      ref.invalidate(settingsRepositoryProvider);
    } catch (_) {
      if (!mounted) return;
      showErrorSnackBar(context, strings.onboardingSaveFailed);
    }
  }

  void _advance() {
    AppFeedback.tap();
    if (_index < _pageCount - 1) {
      _pages.nextPage(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : DsMotion.normal,
        curve: DsMotion.standard,
      );
    } else {
      _finish();
    }
  }

  void _openAccounts() {
    AppFeedback.tap();
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const AuthScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final strings = SettingsStrings.of(context);
    final isLast = _index == _pageCount - 1;
    return AppPage(
      header: SafeArea(
        bottom: false,
        child: AppPageHeader(
          title: Text(strings.onboardingBrand),
          subtitle: Text(strings.onboardingTagline),
          actions: <Widget>[
            AppButton(
              key: const ValueKey('onboarding-skip'),
              label: strings.onboardingSkip,
              variant: AppButtonVariant.ghost,
              onPressed: _finish,
            ),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            strings.onboardingStep(_index + 1, _pageCount),
            key: const ValueKey('onboarding-step'),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: DsSpace.x8),
          Expanded(
            child: PageView(
              controller: _pages,
              onPageChanged: (index) {
                AppFeedback.selection();
                setState(() => _index = index);
              },
              children: <Widget>[
                _OnboardingPage(
                  key: const ValueKey('onboarding-page-1'),
                  icon: Icons.event_available_outlined,
                  title: strings.onboardingP1Title,
                  body: strings.onboardingP1Body,
                ),
                _OnboardingPage(
                  key: const ValueKey('onboarding-page-2'),
                  icon: Icons.alarm_outlined,
                  title: strings.onboardingP2Title,
                  body: strings.onboardingP2Body,
                  note: strings.onboardingNotificationsNote,
                ),
                _OnboardingPage(
                  key: const ValueKey('onboarding-page-3'),
                  icon: Icons.sync_outlined,
                  title: strings.onboardingP3Title,
                  body: strings.onboardingP3Body,
                  note: strings.onboardingLocalNote,
                  action: AppButton(
                    key: const ValueKey('onboarding-google'),
                    label: strings.onboardingGoogle,
                    icon: Icons.account_circle_outlined,
                    variant: AppButtonVariant.secondary,
                    onPressed: _openAccounts,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: DsSpace.x16),
          _PageProgress(
            index: _index,
            count: _pageCount,
            semanticsLabel: strings.onboardingProgress(_index + 1, _pageCount),
          ),
          const SizedBox(height: DsSpace.x16),
          AppButton(
            key: const ValueKey('onboarding-primary'),
            label: isLast ? strings.onboardingDone : strings.onboardingNext,
            expand: true,
            onPressed: _advance,
          ),
        ],
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.note,
    this.action,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? note;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: DsSpace.x8,
            vertical: DsSpace.x16,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: (constraints.maxHeight - DsSpace.x32).clamp(
                0,
                double.infinity,
              ),
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        width: 72,
                        height: 72,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: scheme.primaryContainer.withValues(
                            alpha: 0.55,
                          ),
                          borderRadius: BorderRadius.circular(DsRadius.r16),
                        ),
                        child: Icon(
                          icon,
                          size: DsIcon.lg,
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                    const SizedBox(height: DsSpace.x24),
                    Text(
                      title,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: DsSpace.x12),
                    Text(
                      body,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    if (note != null) ...<Widget>[
                      const SizedBox(height: DsSpace.x16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Icon(
                            Icons.check_circle_outline,
                            size: DsIcon.sm,
                            color: scheme.primary,
                          ),
                          const SizedBox(width: DsSpace.x8),
                          Expanded(
                            child: Text(
                              note!,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (action != null) ...<Widget>[
                      const SizedBox(height: DsSpace.x24),
                      action!,
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PageProgress extends StatelessWidget {
  const _PageProgress({
    required this.index,
    required this.count,
    required this.semanticsLabel,
  });

  final int index;
  final int count;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : DsMotion.normal;
    return Semantics(
      key: const ValueKey('onboarding-progress'),
      label: semanticsLabel,
      child: Row(
        children: <Widget>[
          for (var i = 0; i < count; i++) ...<Widget>[
            if (i > 0) const SizedBox(width: DsSpace.x8),
            Expanded(
              child: AnimatedContainer(
                duration: duration,
                curve: DsMotion.standard,
                height: 4,
                decoration: BoxDecoration(
                  color: i <= index ? scheme.primary : scheme.outlineVariant,
                  borderRadius: BorderRadius.circular(DsRadius.pill),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
