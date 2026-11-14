// First-run onboarding: 3 pages max, skip always available.
// Permissions are explained at the moment of need, not all upfront.
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:ephemeron/core/theme/theme_tokens.dart';
import 'package:ephemeron/core/ui/app_feedback.dart';
import 'package:ephemeron/core/ui/app_motion.dart';
import 'package:ephemeron/l10n/src/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/settings_providers.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const _pageCount = 3;

  final _pages = PageController();
  int _index = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    final repo = await ref.read(settingsRepositoryProvider.future);
    await repo.setOnboarded();
    if (!mounted) return;
    ref.invalidate(settingsRepositoryProvider);
  }

  void _advance() {
    AppFeedback.tap();
    if (_index < _pageCount - 1) {
      _pages.nextPage(
        duration: AppMotion.duration(context, AppDurations.normal),
        curve: Curves.easeOut,
      );
    } else {
      _finish();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isLast = _index == _pageCount - 1;
    return Scaffold(
      appBar: AppBar(
        actions: [
          TextButton(onPressed: _finish, child: Text(l10n.onboardingSkip)),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.xl),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  l10n.onboardingStep(_index + 1, _pageCount),
                  key: const ValueKey('onboarding-step'),
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpace.sm),
            Expanded(
              child: PageView(
                controller: _pages,
                onPageChanged: (i) {
                  AppFeedback.selection();
                  setState(() => _index = i);
                },
                children: [
                  _Page(
                    icon: Icons.calendar_month_outlined,
                    title: l10n.onboardingP1Title,
                    body: l10n.onboardingP1Body,
                  ),
                  _Page(
                    icon: Icons.alarm_outlined,
                    title: l10n.onboardingP2Title,
                    body: l10n.onboardingP2Body,
                  ),
                  _Page(
                    icon: Icons.sync_outlined,
                    title: l10n.onboardingP3Title,
                    body: l10n.onboardingP3Body,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.xl),
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: (_index + 1) / _pageCount),
                duration: AppMotion.duration(context, AppDurations.normal),
                curve: Curves.easeOut,
                builder: (context, value, _) => ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: LinearProgressIndicator(
                    key: const ValueKey('onboarding-progress'),
                    value: value,
                    minHeight: 6,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpace.xl),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const ValueKey('onboarding-primary'),
                  onPressed: _advance,
                  child: Text(
                    isLast ? l10n.onboardingDone : l10n.onboardingNext,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Page extends StatelessWidget {
  const _Page({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final minHeight = math.max(
          0.0,
          constraints.maxHeight - AppSpace.xl * 2,
        );
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.xxl,
            vertical: AppSpace.xl,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minHeight),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 104,
                    height: 104,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withValues(
                        alpha: 0.55,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      size: 48,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: AppSpace.xl),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: AppSpace.md),
                  Text(
                    body,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
