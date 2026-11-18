import 'package:ephemeron/features/stream/application/stream_school_preferences.dart';
import 'package:ephemeron/features/stream/presentation/school/gesture_school_overlay.dart';
import 'package:ephemeron/features/stream/presentation/school/school_progress_dots.dart';
import 'package:ephemeron/features/stream/presentation/surface/stream_school_host.dart';
import 'package:ephemeron/l10n/src/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

class _FakeSchoolNotifier extends StreamSchoolCompletedNotifier {
  _FakeSchoolNotifier(this.initial);

  final bool initial;
  int markCalls = 0;
  int resetCalls = 0;

  @override
  Future<bool> build() async => initial;

  @override
  Future<void> markCompleted() async {
    markCalls++;
    state = const AsyncData(true);
  }

  @override
  Future<void> reset() async {
    resetCalls++;
    state = const AsyncData(false);
  }
}

Widget _app({
  required _FakeSchoolNotifier notifier,
  VoidCallback? onFinished,
  Locale locale = const Locale('en'),
  double width = 400,
  double height = 600,
  double textScale = 1.0,
}) {
  return ProviderScope(
    overrides: [streamSchoolCompletedProvider.overrideWith(() => notifier)],
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: true,
            textScaler: TextScaler.linear(textScale),
          ),
          child: Scaffold(
            body: SizedBox(
              width: width,
              height: height,
              child: StreamSchoolHost(
                onFinished: onFinished,
                child: const ColoredBox(
                  color: Colors.white,
                  child: Center(child: Text('child')),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> _pump(WidgetTester tester, Widget app) async {
  await tester.pumpWidget(app);
  await tester.pumpAndSettle();
}

AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(StreamSchoolHost)));

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(StreamSchoolHost)));

void main() {
  testWidgets('first run shows the first step from the ARB', (tester) async {
    final notifier = _FakeSchoolNotifier(false);
    await _pump(tester, _app(notifier: notifier));
    final l = _l10n(tester);

    expect(find.byType(GestureSchoolOverlay), findsOneWidget);
    expect(find.text(l.streamSchoolScrollTitle), findsOneWidget);
    expect(find.text(l.streamSchoolScrollBody), findsOneWidget);
    expect(find.text(l.streamSchoolCaptureTitle), findsNothing);
    expect(notifier.markCalls, 0);
  });

  testWidgets('Next advances to the second step', (tester) async {
    final notifier = _FakeSchoolNotifier(false);
    await _pump(tester, _app(notifier: notifier));
    final l = _l10n(tester);

    await tester.tap(find.text(l.onboardingNext));
    await tester.pumpAndSettle();

    expect(find.text(l.streamSchoolCaptureTitle), findsOneWidget);
    expect(find.text(l.streamSchoolCaptureBody), findsOneWidget);
    expect(find.text(l.streamSchoolScrollTitle), findsNothing);
    expect(notifier.markCalls, 0);
  });

  testWidgets('Skip marks completed and hides the overlay', (tester) async {
    final notifier = _FakeSchoolNotifier(false);
    var finished = 0;
    await _pump(tester, _app(notifier: notifier, onFinished: () => finished++));
    final l = _l10n(tester);

    await tester.tap(find.text(l.onboardingSkip));
    await tester.pumpAndSettle();

    expect(find.byType(GestureSchoolOverlay), findsNothing);
    expect(find.text('child'), findsOneWidget);
    expect(notifier.markCalls, 1);
    expect(finished, 1);
    expect(
      _container(tester).read(streamSchoolCompletedProvider).value,
      isTrue,
    );
  });

  testWidgets('Finish on the last step marks completed', (tester) async {
    final notifier = _FakeSchoolNotifier(false);
    await _pump(tester, _app(notifier: notifier));
    final l = _l10n(tester);

    for (var i = 0; i < 5; i++) {
      await tester.tap(find.text(l.onboardingNext));
      await tester.pumpAndSettle();
    }
    expect(find.text(l.streamSchoolPinchTitle), findsOneWidget);
    expect(find.text(l.streamSchoolDone), findsOneWidget);

    await tester.tap(find.text(l.streamSchoolDone));
    await tester.pumpAndSettle();

    expect(find.byType(GestureSchoolOverlay), findsNothing);
    expect(notifier.markCalls, 1);
    expect(
      _container(tester).read(streamSchoolCompletedProvider).value,
      isTrue,
    );
  });

  testWidgets('onFinished fires once on a repeated last-step tap', (
    tester,
  ) async {
    final notifier = _FakeSchoolNotifier(false);
    var finished = 0;
    await _pump(tester, _app(notifier: notifier, onFinished: () => finished++));
    final l = _l10n(tester);

    for (var i = 0; i < 5; i++) {
      await tester.tap(find.text(l.onboardingNext));
      await tester.pumpAndSettle();
    }
    final done = find.text(l.streamSchoolDone);
    await tester.tap(done);
    await tester.tap(done);
    await tester.pumpAndSettle();

    expect(finished, 1);
    expect(notifier.markCalls, 1);
  });

  testWidgets('completed provider shows the child and no overlay', (
    tester,
  ) async {
    final notifier = _FakeSchoolNotifier(true);
    await _pump(tester, _app(notifier: notifier));

    expect(find.text('child'), findsOneWidget);
    expect(find.byType(GestureSchoolOverlay), findsNothing);
    expect(find.text(_l10n(tester).streamSchoolScrollTitle), findsNothing);
    expect(notifier.markCalls, 0);
  });

  testWidgets('reset after skip reopens the school from the first step', (
    tester,
  ) async {
    final notifier = _FakeSchoolNotifier(false);
    var finished = 0;
    await _pump(tester, _app(notifier: notifier, onFinished: () => finished++));
    final l = _l10n(tester);

    await tester.tap(find.text(l.onboardingSkip));
    await tester.pumpAndSettle();
    expect(find.byType(GestureSchoolOverlay), findsNothing);
    expect(notifier.markCalls, 1);
    expect(finished, 1);

    await notifier.reset();
    await tester.pumpAndSettle();

    expect(notifier.resetCalls, 1);
    expect(find.byType(GestureSchoolOverlay), findsOneWidget);
    expect(find.text(l.streamSchoolScrollTitle), findsOneWidget);
    expect(find.byType(ModalBarrier), findsWidgets);
    expect(find.text('child'), findsOneWidget);

    await tester.tap(find.text(l.onboardingSkip));
    await tester.pumpAndSettle();

    expect(find.byType(GestureSchoolOverlay), findsNothing);
    expect(notifier.markCalls, 2);
    expect(finished, 1);
  });

  testWidgets('320 dp at 2.0 text scale does not overflow', (tester) async {
    tester.view.physicalSize = const Size(640, 1280);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final notifier = _FakeSchoolNotifier(false);
    await _pump(
      tester,
      _app(notifier: notifier, width: 320, height: 640, textScale: 2.0),
    );

    expect(find.byType(GestureSchoolOverlay), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('labels and progress come from the active ARB locale', (
    tester,
  ) async {
    final notifier = _FakeSchoolNotifier(false);
    await _pump(tester, _app(notifier: notifier, locale: const Locale('pt')));
    final l = _l10n(tester);

    expect(l.localeName, 'pt');
    expect(find.text(l.streamSchoolScrollTitle), findsOneWidget);
    expect(find.text(l.onboardingNext), findsOneWidget);
    final dots = tester.widget<SchoolProgressDots>(
      find.byType(SchoolProgressDots),
    );
    expect(dots.progressLabel('scroll', 1, 6), l.onboardingStep(1, 6));
    expect(l.streamSchoolScrollTitle, isNot('Scroll the timeline'));
  });
}
