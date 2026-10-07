import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:beemview/app.dart';
import 'package:beemview/core/app_theme.dart';
import 'package:beemview/models/project.dart';
import 'package:beemview/models/task_details.dart';
import 'package:beemview/widgets/app_surface.dart';
import 'package:beemview/widgets/project_card.dart';
import 'package:beemview/widgets/task_card.dart';
import 'package:beemview/widgets/task_info_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'projects_screen_test.dart' show createController;

// Ces donnees servent a verifier la densite demandee sans acceder a l'API reelle.
const projectNames = [
  'Website Redesign',
  'Mobile App',
  'Customer Portal',
  'Marketing Campaign',
  'Team Workspace',
];
final projectData = jsonEncode({
  'data': [
    for (var i = 0; i < projectNames.length; i++)
      {'id': i + 1, 'name': projectNames[i]},
  ],
  'total': 6,
});
final taskData = jsonEncode({
  'tasks': [
    {
      'id': 501,
      'name': 'Design login screen',
      'status': 'in_progress',
      'priority': 'high',
      'due_date': '2026-10-12',
    },
    {
      'id': 502,
      'name': 'Review mobile layouts',
      'status': 'to_do',
      'priority': 'medium',
      'due_date': '2026-10-14',
    },
    {
      'id': 503,
      'name': 'Define color palette',
      'status': 'done',
      'priority': 'low',
      'due_date': '2026-10-10',
    },
    {
      'id': 504,
      'name': 'Prepare review notes',
      'status': 'to_do',
      'priority': 'low',
      'due_date': '2026-10-16',
    },
  ],
});
final detailData = {
  'id': 501,
  'name': 'Design login screen',
  'status': 'in_progress',
  'priority': 'high',
  'start_date': '2026-10-07',
  'due_date': '2026-10-12',
  'description': 'Create a clear, welcoming login experience for BeemView.',
  'Project': {'id': 1, 'name': 'Website Redesign'},
  'Assignees': [
    {'id': 12, 'full_name': 'Nour Ben Ali'},
  ],
  'Comments': [
    {
      'id': 77,
      'content': 'Ready for the next review.',
      'created_at': '2026-10-07T13:14:00Z',
      'user': {'name': 'Nour'},
    },
  ],
};

// Le rendu PNG est optionnel et reste dans le dossier build ignore par Git.
Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
  const output = String.fromEnvironment('DESIGN_PREVIEW_DIR');
  if (output.isEmpty) return;
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final dir = Directory(output);
    await dir.create(recursive: true);
    await File('${dir.path}/$name.png')
        .writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  for (final mode in [Brightness.light, Brightness.dark]) {
    testWidgets(
      'five projects and Load more fit the connected phone in ${mode.name}',
      (tester) async {
        tester.view.physicalSize = const Size(360, 802);
        tester.view.devicePixelRatio = 1;
        tester.view.padding = const FakeViewPadding(top: 32, bottom: 16);
        tester.platformDispatcher.platformBrightnessTestValue = mode;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPadding);
        addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
        // Charge la police du produit pour verifier des dimensions realistes.
        final font = FontLoader('PlusJakartaSans')
          ..addFont(rootBundle.load('assets/fonts/PlusJakartaSans.ttf'));
        await font.load();
        final icons = FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
        await icons.load();
        final auth = createController(
          (_) async => http.Response(projectData, 200),
          tasks: (_) async => http.Response(taskData, 200),
          details: (_) async =>
              http.Response(jsonEncode({'task': detailData}), 200),
        );
        final key = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: BeemViewApp(authController: auth),
          ),
        );
        await tester.pumpAndSettle();
        await tester.runAsync(
          () => precacheImage(
            const AssetImage('assets/images/beemview-logo.png'),
            tester.element(find.byType(Scaffold).last),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(ProjectCard), findsNWidgets(5));
        expect(
          tester.getBottomLeft(find.byType(ProjectCard).last).dy,
          lessThan(786),
        );
        expect(find.text('Load more').hitTestable(), findsOneWidget);
        expect(
          tester.getBottomLeft(find.byType(OutlinedButton)).dy,
          lessThanOrEqualTo(786),
        );
        await capture(tester, key, 'projects-${mode.name}');
        await tester.tap(find.text('Website Redesign'));
        await tester.pumpAndSettle();
        expect(find.byType(TaskCard), findsNWidgets(4));
        expect(
          tester.getBottomLeft(find.byType(TaskCard).last).dy,
          lessThan(786),
        );
        expect(find.text('4 tasks'), findsOneWidget);
        await capture(tester, key, 'tasks-${mode.name}');
        await tester.tap(find.text('Design login screen'));
        await tester.pumpAndSettle();
        expect(find.byType(TaskInfoCard), findsOneWidget);
        final start = tester.getTopLeft(find.text('Oct 7, 2026'));
        final due = tester.getTopLeft(find.text('Oct 12, 2026'));
        expect(start.dy, closeTo(due.dy, 1));
        expect(start.dx, lessThan(due.dx));
        await capture(tester, key, 'details-${mode.name}');
        await tester.tap(find.text('Update status'));
        await tester.pumpAndSettle();
        await capture(tester, key, 'update-${mode.name}');
        await tester.ensureVisible(find.byKey(const ValueKey('status-note')));
        await tester.enterText(
          find.byKey(const ValueKey('status-note')),
          'Keep this draft',
        );
        expect(find.text('Save status').hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        FlutterSecureStorage.setMockInitialValues({});
        await tester.pumpWidget(
          RepaintBoundary(key: key, child: const BeemViewApp()),
        );
        await tester.pumpAndSettle();
        expect(find.text('Sign in').hitTestable(), findsOneWidget);
        await capture(tester, key, 'login-${mode.name}');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets(
    'metadata stacks dates and keeps every assignee with enlarged text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.8;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final data = Map<String, dynamic>.from(detailData);
      data['Assignees'] = [
        {'id': 12, 'full_name': 'Nour Ben Ali with a longer display name'},
        {'id': 13, 'full_name': 'Second assignee'},
      ];
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: TaskInfoCard(
                details: TaskDetails.fromJson(data),
                project: const Project(id: 1, name: 'Website Redesign'),
              ),
            ),
          ),
        ),
      );
      expect(find.text('Second assignee'), findsOneWidget);
      await tester.ensureVisible(find.text('Oct 12, 2026'));
      expect(
        tester.getTopLeft(find.text('Oct 7, 2026')).dy,
        lessThan(tester.getTopLeft(find.text('Oct 12, 2026')).dy),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('reduced motion displays entrance content immediately', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: AppEntrance(child: Text('Immediately visible')),
        ),
      ),
    );
    expect(find.text('Immediately visible'), findsOneWidget);
    expect(find.byType(TweenAnimationBuilder<double>), findsNothing);
  });
}
