import 'dart:async';
import 'dart:convert';

import 'package:beemview/app.dart';
import 'package:beemview/screens/task_details_screen.dart';
import 'package:beemview/widgets/app_surface.dart';
import 'package:beemview/widgets/task_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'projects_screen_test.dart' show createController;

const projectResponse =
    '{"data":[{"id":102,"name":"Interview project"}],"total":1}';
const tasksResponse =
    '{"tasks":[{"id":501,"name":"Site inspection","status":"to_do","priority":"High","dueDate":"2026-10-09"},{"id":502,"name":"Review drawings","status":"review","priority":"Low","dueDate":null}]}';

void main() {
  testWidgets(
    'task selection passes the correct ID and Back retains name and status filters',
    (tester) async {
      // Le double toucher ouvre une seule route; le retour ne recharge pas la collection.
      var calls = 0;
      final auth = createController(
        (request) async => http.Response(projectResponse, 200),
        tasks: (request) async {
          calls++;
          return http.Response(tasksResponse, 200);
        },
      );
      await tester.pumpWidget(BeemViewApp(authController: auth));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Interview project'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'drawings');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byTooltip('Filter: Review'));
      await tester.tap(find.byTooltip('Filter: Review'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Review drawings'));
      final card = tester.widget<TaskCard>(find.byType(TaskCard));
      await tester.tap(find.text('Review drawings'));
      // La seconde action appelle le meme callback avant la premiere frame de route.
      card.onTap();
      await tester.pumpAndSettle();
      final screen = tester.widget<TaskDetailsScreen>(
        find.byType(TaskDetailsScreen),
      );
      expect(screen.task.id, 502);
      expect(screen.project.id, 102);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.byType(TaskDetailsScreen), findsNothing);
      expect(find.byType(TaskCard), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'drawings',
      );
      final chip = find.ancestor(
        of: find.byTooltip('Filter: Review'),
        matching: find.byType(ChoiceChip),
      );
      expect(tester.widget<ChoiceChip>(chip).selected, isTrue);
      expect(calls, 1);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Projects'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'empty project reloads and empty search results clear both filters',
    (tester) async {
      // Zero task et zero resultat de recherche ne sont pas le meme etat.
      var calls = 0;
      final auth = createController(
        (request) async => http.Response(projectResponse, 200),
        tasks: (request) async {
          calls++;
          return http.Response(
            calls == 1 ? '{"tasks":[]}' : tasksResponse,
            200,
          );
        },
      );
      await tester.pumpWidget(BeemViewApp(authController: auth));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Interview project'));
      await tester.tap(find.text('Interview project'));
      await tester.pumpAndSettle();
      expect(find.text('No tasks yet'), findsOneWidget);
      await tester.ensureVisible(find.text('Reload'));
      await tester.tap(find.text('Reload'));
      await tester.pumpAndSettle();
      expect(find.byType(TaskCard), findsNWidgets(2));
      await tester.ensureVisible(find.byTooltip('Filter: To do'));
      await tester.tap(find.byTooltip('Filter: To do'));
      await tester.enterText(find.byType(TextField), 'drawings');
      await tester.pumpAndSettle();
      expect(find.text('No matching tasks'), findsOneWidget);
      await tester.ensureVisible(find.text('Clear filters'));
      await tester.tap(find.text('Clear filters'));
      await tester.pumpAndSettle();
      expect(find.byType(TaskCard), findsNWidgets(2));
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '',
      );
      expect(calls, 2);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final status in [401, 403]) {
    testWidgets('task API $status handles session and navigation correctly', (
      tester,
    ) async {
      // Expiration quitte les routes protegees; acces refuse permet Retry.
      var calls = 0;
      final auth = createController(
        (request) async => http.Response(projectResponse, 200),
        tasks: (request) async {
          calls++;
          return calls == 1
              ? http.Response('{"message":"Access unavailable"}', status)
              : http.Response(tasksResponse, 200);
        },
      );
      await tester.pumpWidget(BeemViewApp(authController: auth));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Interview project'));
      await tester.tap(find.text('Interview project'));
      await tester.pumpAndSettle();
      if (status == 401) {
        expect(find.text('Welcome back'), findsOneWidget);
        expect(await auth.store.readToken(), isNull);
        expect(
          Navigator.of(tester.element(find.text('Welcome back'))).canPop(),
          isFalse,
        );
      } else {
        expect(find.text('Could not load tasks'), findsOneWidget);
        expect(find.text('Access unavailable'), findsOneWidget);
        expect(await auth.store.readToken(), 'test-token');
        await tester.ensureVisible(find.text('Retry'));
        await tester.tap(find.text('Retry'));
        await tester.pumpAndSettle();
        expect(find.byType(TaskCard), findsNWidgets(2));
        expect(calls, 2);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('connectivity failure offers Retry and preserves search', (
    tester,
  ) async {
    // Le client transforme une panne reseau en message utile sans effacer le token.
    final response = Completer<http.Response>();
    var calls = 0;
    final auth = createController(
      (request) async => http.Response(projectResponse, 200),
      tasks: (request) {
        calls++;
        return calls == 1
            ? response.future
            : Future.value(http.Response(tasksResponse, 200));
      },
    );
    await tester.pumpWidget(BeemViewApp(authController: auth));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Interview project'));
    await tester.tap(find.text('Interview project'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.enterText(find.byType(TextField), 'inspection');
    response.completeError(http.ClientException('Offline'));
    await tester.pumpAndSettle();
    expect(
      find.text('Could not connect. Check your internet connection.'),
      findsOneWidget,
    );
    await tester.ensureVisible(find.text('Retry'));
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.byType(TaskCard), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'inspection',
    );
    expect(await auth.store.readToken(), 'test-token');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('long tasks and badges fit enlarged text with the keyboard open', (
    tester,
  ) async {
    // Les noms, compteurs, badges et chips doivent rester accessibles par scroll.
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.8;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    const name =
        'A very long site inspection task for the assigned construction project';
    final auth = createController(
      (request) async => http.Response(projectResponse, 200),
      tasks: (request) async => http.Response(
        jsonEncode({
          'tasks': [
            {
              'id': 501,
              'name': name,
              'status': 'changes_requested',
              'priority': 'urgent',
              'dueDate': null,
            },
          ],
        }),
        200,
      ),
    );
    await tester.pumpWidget(BeemViewApp(authController: auth));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Interview project'));
    await tester.tap(find.text('Interview project'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text(name));
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.byType(TextField));
    await tester.tap(find.byType(TextField));
    tester.view.viewInsets = const FakeViewPadding(bottom: 250);
    addTearDown(tester.view.resetViewInsets);
    await tester.enterText(find.byType(TextField), 'site');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text(name));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('status and name filters combine without fetching tasks again', (
    tester,
  ) async {
    // Choisir un chip conserve le texte saisi et filtre les valeurs API.
    var calls = 0;
    final auth = createController(
      (request) async => http.Response(projectResponse, 200),
      tasks: (request) async {
        calls++;
        return http.Response(tasksResponse, 200);
      },
    );
    await tester.pumpWidget(BeemViewApp(authController: auth));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Interview project'));
    await tester.tap(find.text('Interview project'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('Filter: To do'));
    await tester.tap(find.byTooltip('Filter: To do'));
    await tester.pumpAndSettle();
    expect(find.byType(TaskCard), findsOneWidget);
    expect(find.text('Site inspection'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'drawings');
    await tester.pump();
    expect(find.byType(TaskCard), findsNothing);
    await tester.ensureVisible(find.byTooltip('Filter: All'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Filter: All'));
    await tester.pump();
    expect(find.text('Review drawings'), findsOneWidget);
    expect(calls, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'name search ignores case and Clear search restores loaded cards',
    (tester) async {
      // Saisir et effacer le texte ne doit pas demander a nouveau les tasks.
      var calls = 0;
      final auth = createController(
        (request) async => http.Response(projectResponse, 200),
        tasks: (request) async {
          calls++;
          return http.Response(tasksResponse, 200);
        },
      );
      await tester.pumpWidget(BeemViewApp(authController: auth));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Interview project'));
      await tester.tap(find.text('Interview project'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), ' INSPECTION ');
      await tester.pump();
      expect(find.byType(TaskCard), findsOneWidget);
      expect(find.text('1 task'), findsOneWidget);
      expect(find.text('Review drawings'), findsNothing);
      await tester.tap(find.byTooltip('Clear search'));
      await tester.pump();
      expect(find.byType(TaskCard), findsNWidgets(2));
      expect(calls, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'selected project loads its tasks once and displays real task fields',
    (tester) async {
      // La reponse differee permet de verifier loading avant les cartes.
      final response = Completer<http.Response>();
      var calls = 0;
      final auth = createController(
        (request) async => http.Response(projectResponse, 200),
        tasks: (request) {
          calls++;
          expect(request.url.path, '/api/tasks/project/102');
          return response.future;
        },
      );
      await tester.pumpWidget(BeemViewApp(authController: auth));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Interview project'));
      await tester.tap(find.text('Interview project'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(LoadingCards), findsOneWidget);
      response.complete(http.Response(tasksResponse, 200));
      await tester.pumpAndSettle();
      expect(find.byType(TaskCard), findsNWidgets(2));
      expect(find.text('Site inspection'), findsOneWidget);
      expect(find.text('Due Oct 9, 2026'), findsOneWidget);
      expect(find.text('No due date'), findsOneWidget);
      expect(find.text('2 tasks'), findsOneWidget);
      expect(calls, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
