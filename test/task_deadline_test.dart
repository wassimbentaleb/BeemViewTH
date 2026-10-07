import 'dart:io';
import 'dart:ui' as ui;

import 'package:beemview/core/app_theme.dart';
import 'package:beemview/models/task.dart';
import 'package:beemview/widgets/task_card.dart';
import 'package:beemview/widgets/task_deadline.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

final today = DateTime(2026, 10, 7);

Task deadlineTask(
  int? days, {
  String status = 'in_progress',
  String? priority = 'high',
}) => Task(
  id: 501,
  name: 'Design login screen',
  status: status,
  priority: priority,
  dueDate: days == null ? null : DateTime(2026, 10, 7 + days),
);

Widget deadlineApp(
  Task task, {
  bool reduced = false,
  bool ticker = true,
  Brightness brightness = Brightness.light,
  DateTime? now,
}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: brightness == Brightness.light ? AppTheme.light : AppTheme.dark,
  home: TickerMode(
    enabled: ticker,
    child: MediaQuery(
      data: MediaQueryData(disableAnimations: reduced),
      child: Scaffold(
        body: Center(
          child: TaskDeadline(task: task, now: now ?? today),
        ),
      ),
    ),
  ),
);

double deadlineScale(WidgetTester tester) => tester
    .widget<Transform>(
      find.descendant(
        of: find.byType(TaskDeadline),
        matching: find.byType(Transform),
      ),
    )
    .transform
    .entry(0, 0);

void main() {
  testWidgets('covered routes and inactive apps stop and resume attention', (
    tester,
  ) async {
    final task = deadlineTask(4);
    await tester.pumpWidget(deadlineApp(task));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 150));
    expect(deadlineScale(tester), greaterThan(1));
    await tester.pumpWidget(deadlineApp(task, ticker: false));
    expect(deadlineScale(tester), 1);
    await tester.pump(const Duration(seconds: 15));
    expect(deadlineScale(tester), 1);
    await tester.pumpWidget(deadlineApp(task));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 150));
    expect(deadlineScale(tester), greaterThan(1));
    try {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(deadlineScale(tester), 1);
      await tester.pump(const Duration(seconds: 15));
      expect(deadlineScale(tester), 1);
    } finally {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    }
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 150));
    expect(deadlineScale(tester), greaterThan(1));
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'near deadline pulses briefly then rests; reduced motion stops it',
    (tester) async {
      await tester.pumpWidget(deadlineApp(deadlineTask(4)));
      expect(find.text('Expires: 4 days'), findsOneWidget);
      expect(deadlineScale(tester), 1);
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 150));
      expect(deadlineScale(tester), greaterThan(1));
      await tester.pumpAndSettle();
      expect(deadlineScale(tester), 1);
      await tester.pump(const Duration(seconds: 12));
      await tester.pump(const Duration(milliseconds: 150));
      expect(deadlineScale(tester), greaterThan(1));
      await tester.pumpWidget(deadlineApp(deadlineTask(4), reduced: true));
      expect(deadlineScale(tester), 1);
      await tester.pump(const Duration(seconds: 15));
      expect(deadlineScale(tester), 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('far, finished, canceled and missing deadlines stay still', (
    tester,
  ) async {
    for (final task in [
      deadlineTask(5),
      deadlineTask(4, status: 'done'),
      deadlineTask(0, status: 'canceled'),
      deadlineTask(null),
    ]) {
      await tester.pumpWidget(deadlineApp(task));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 150));
      expect(deadlineScale(tester), 1);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
    'changed day activates urgency and the exact date remains accessible',
    (tester) async {
      final task = deadlineTask(5);
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(deadlineApp(task));
        expect(find.text('Expires: 5 days'), findsOneWidget);
        await tester.pumpWidget(deadlineApp(task, now: DateTime(2026, 10, 8)));
        expect(find.text('Expires: 4 days'), findsOneWidget);
        expect(find.byTooltip('Oct 12, 2026'), findsOneWidget);
        expect(
          find.bySemanticsLabel('Expires: 4 days. Due date Oct 12, 2026'),
          findsOneWidget,
        );
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pump(const Duration(milliseconds: 150));
        expect(deadlineScale(tester), greaterThan(1));
        await tester.pumpWidget(deadlineApp(deadlineTask(30)));
        expect(deadlineScale(tester), 1);
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets('deadlines stay simple and neutral in both themes', (
    tester,
  ) async {
    for (final brightness in Brightness.values) {
      final colors = <Color?>[];
      for (final days in [40, 10, 4, -1]) {
        await tester.pumpWidget(
          deadlineApp(
            deadlineTask(days),
            reduced: true,
            brightness: brightness,
          ),
        );
        final texts = find.descendant(
          of: find.byType(TaskDeadline),
          matching: find.byType(Text),
        );
        final text = tester.widget<Text>(texts);
        colors.add(text.style!.color);
        expect(text.style!.color, AppColors.of(tester.element(texts)).muted);
        expect(
          find.descendant(
            of: find.byType(TaskDeadline),
            matching: find.byType(DecoratedBox),
          ),
          findsNothing,
        );
        if (days < 0) expect(find.text('Expired: 1 day'), findsOneWidget);
      }
      expect(colors.toSet(), hasLength(1));
    }
  });

  for (final brightness in Brightness.values) {
    testWidgets(
      'deadline stays right aligned on narrow and enlarged layouts in ${brightness.name}',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        for (final (width, scale, days) in [
          (360.0, 1.0, 150),
          (280.0, 1.8, 150),
          (280.0, 1.8, -40),
        ]) {
          tester.view.physicalSize = Size(width, 802);
          await tester.pumpWidget(
            MaterialApp(
              theme: brightness == Brightness.light
                  ? AppTheme.light
                  : AppTheme.dark,
              home: MediaQuery(
                data: MediaQueryData(
                  textScaler: TextScaler.linear(scale),
                  disableAnimations: true,
                ),
                child: Scaffold(
                  body: Padding(
                    padding: const EdgeInsets.all(20),
                    child: TaskCard(
                      task: deadlineTask(days, priority: null),
                      now: today,
                      onTap: () {},
                    ),
                  ),
                ),
              ),
            ),
          );
          final due = tester.getRect(find.byType(TaskDeadline));
          final card = tester.getRect(find.byType(TaskCard));
          expect(due.right, closeTo(card.right - 16, 1));
          expect(
            tester.getRect(find.text('No priority')).right,
            lessThan(due.left),
          );
          expect(tester.takeException(), isNull);
        }
      },
    );
  }

  testWidgets(
    'deadline design previews use the product font and real phone width',
    (tester) async {
      const output = String.fromEnvironment('DEADLINE_PREVIEW_DIR');
      if (output.isEmpty) return;
      tester.view.physicalSize = const Size(360, 540);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final font = FontLoader('PlusJakartaSans')
        ..addFont(rootBundle.load('assets/fonts/PlusJakartaSans.ttf'));
      await font.load();
      final icons = FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await icons.load();
      for (final brightness in Brightness.values) {
        final key = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: brightness == Brightness.light
                  ? AppTheme.light
                  : AppTheme.dark,
              home: Scaffold(
                body: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final (id, name, date) in [
                          (501, 'Define project scope', DateTime(2027, 3, 7)),
                          (
                            502,
                            'Review mobile layouts',
                            DateTime(2026, 10, 28),
                          ),
                          (503, 'Design login screen', DateTime(2026, 10, 11)),
                          (504, 'Prepare review notes', DateTime(2026, 10, 6)),
                        ]) ...[
                          TaskCard(
                            task: Task(
                              id: id,
                              name: name,
                              status: 'in_progress',
                              priority: 'high',
                              dueDate: date,
                            ),
                            now: today,
                            onTap: () {},
                          ),
                          const SizedBox(height: 12),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 350));
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await Directory(output).create(recursive: true);
          await File('$output/deadlines-${brightness.name}.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
        expect(tester.takeException(), isNull);
      }
    },
  );
}
