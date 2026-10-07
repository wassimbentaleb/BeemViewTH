import 'package:beemview/app.dart';
import 'package:beemview/core/app_theme.dart';
import 'package:beemview/widgets/app_motion.dart';
import 'package:beemview/widgets/app_surface.dart';
import 'package:beemview/widgets/task_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'project_tasks_screen_test.dart' show projectResponse, tasksResponse;
import 'projects_screen_test.dart' show createController;

void main() {
  testWidgets('card entrances are staggered and finish within 300 ms', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Column(
          children: [
            AppEntrance(child: Text('First card')),
            AppEntrance(order: 3, child: Text('Fourth card')),
          ],
        ),
      ),
    );
    double opacity(int index) => tester
        .widget<Opacity>(
          find.descendant(
            of: find.byType(AppEntrance).at(index),
            matching: find.byType(Opacity),
          ),
        )
        .opacity;
    await tester.pump(const Duration(milliseconds: 40));
    expect(opacity(0), greaterThan(0));
    expect(opacity(1), 0);
    await tester.pump(const Duration(milliseconds: 260));
    expect(opacity(0), 1);
    expect(opacity(1), 1);
  });

  testWidgets(
    'press feedback preserves the tap target and activates once per tap',
    (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 240,
                child: AppPressScale(
                  child: FilledButton(
                    onPressed: () => taps++,
                    child: const Text('Action'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final button = find.byType(FilledButton);
      final target = tester.getSize(find.byType(AppPressScale));
      final original = tester.getRect(button);
      final gesture = await tester.startGesture(tester.getCenter(button));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      expect(tester.getTopLeft(button).dx, greaterThan(original.left));
      final pressedWidth =
          tester.getBottomRight(button).dx - tester.getTopLeft(button).dx;
      expect(pressedWidth, lessThan(original.width * 0.98));
      expect(tester.getSize(find.byType(AppPressScale)), target);
      expect(taps, 0);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(button), original.topLeft);
      expect(taps, 1);
      // Down/up dans la meme frame doit aussi produire un feedback visible.
      await tester.tap(button);
      expect(taps, 2);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      expect(tester.getTopLeft(button).dx, greaterThan(original.left));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(button), original.topLeft);
      final cancelled = await tester.startGesture(tester.getCenter(button));
      await tester.pump(const Duration(milliseconds: 180));
      await cancelled.cancel();
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(button), original.topLeft);
      expect(taps, 2);
    },
  );

  testWidgets('card entrance stays visible after the page transition', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push<void>(
              PageRouteBuilder<void>(
                transitionDuration: const Duration(milliseconds: 300),
                pageBuilder: (context, animation, secondary) => const Scaffold(
                  body: AppEntrance(child: Text('Arriving card')),
                ),
                transitionsBuilder: (context, animation, secondary, child) =>
                    FadeTransition(opacity: animation, child: child),
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open'));
    await tester.pump();
    double opacity() => tester
        .widget<Opacity>(
          find.descendant(
            of: find.byType(AppEntrance),
            matching: find.byType(Opacity),
          ),
        )
        .opacity;
    await tester.pump(const Duration(milliseconds: 100));
    expect(opacity(), 0);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 60));
    expect(opacity(), greaterThan(0));
    expect(opacity(), lessThan(1));
    await tester.pump(const Duration(milliseconds: 40));
    expect(opacity(), lessThan(1));
    await tester.pumpAndSettle();
    expect(opacity(), 1);
  });

  testWidgets('reduced motion stops an active result fade and success check', (
    tester,
  ) async {
    var completed = 0;
    Widget content(String revision, bool reduced) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduced),
        child: Column(
          children: [
            AppResultFade(revision: revision, child: Text(revision)),
            AppSuccessCheck(onCompleted: () => completed++),
          ],
        ),
      ),
    );
    final resultFade = find.descendant(
      of: find.byType(AppResultFade),
      matching: find.byType(FadeTransition),
    );
    await tester.pumpWidget(content('First result', false));
    await tester.pumpWidget(content('Second result', false));
    await tester.pump(const Duration(milliseconds: 50));
    expect(
      tester.widget<FadeTransition>(resultFade).opacity.value,
      lessThan(1),
    );
    expect(completed, 0);
    await tester.pumpWidget(content('Latest result', true));
    expect(tester.widget<FadeTransition>(resultFade).opacity.value, 1);
    expect(find.text('Second result'), findsNothing);
    expect(find.text('Latest result').hitTestable(), findsOneWidget);
    expect(completed, 1);
    await tester.pumpAndSettle();
    expect(completed, 1);
  });

  testWidgets('reduced motion preserves button size during a press', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Center(
            child: AppPressScale(
              child: FilledButton(
                onPressed: () => taps++,
                child: const Text('Action'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final button = find.byType(FilledButton);
    final original = tester.getTopLeft(button);
    final gesture = await tester.startGesture(tester.getCenter(button));
    await tester.pump(const Duration(milliseconds: 180));
    expect(tester.getTopLeft(button), original);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(taps, 1);
  });

  testWidgets('rapid search and filters expose only the latest tasks', (
    tester,
  ) async {
    var reads = 0;
    final auth = createController(
      (_) async => http.Response(projectResponse, 200),
      tasks: (_) async {
        reads++;
        return http.Response(tasksResponse, 200);
      },
    );
    await tester.pumpWidget(BeemViewApp(authController: auth));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Interview project'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'inspection');
    await tester.pump(const Duration(milliseconds: 50));
    await tester.enterText(find.byType(TextField), 'drawings');
    await tester.pump();
    expect(find.text('Site inspection'), findsNothing);
    expect(find.byType(TaskCard), findsOneWidget);
    await tester.ensureVisible(find.byTooltip('Filter: To do'));
    await tester.tap(find.byTooltip('Filter: To do'));
    await tester.pump();
    expect(find.text('No matching tasks'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 50));
    Color? filterColor(String label) {
      final chip = find.ancestor(
        of: find.byTooltip('Filter: $label'),
        matching: find.byType(ChoiceChip),
      );
      final ink = tester.widget<Ink>(
        find.descendant(of: chip, matching: find.byType(Ink)),
      );
      return (ink.decoration! as ShapeDecoration).color;
    }

    expect(filterColor('To do'), isNot(AppColors.light.primary));
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pump();
    expect(filterColor('To do'), AppColors.light.primary);
    await tester.ensureVisible(find.byTooltip('Filter: Review'));
    await tester.tap(find.byTooltip('Filter: Review'));
    await tester.pump();
    expect(filterColor('Review'), AppColors.light.primary);
    expect(find.text('No matching tasks'), findsNothing);
    expect(find.text('Review drawings'), findsOneWidget);
    expect(find.byType(TaskCard), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'drawings',
    );
    expect(reads, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
