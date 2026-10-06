import 'dart:async';

import 'package:beemview/app.dart';
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
      await tester.tap(find.text('Interview project'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), ' INSPECTION ');
      await tester.pump();
      expect(find.byType(TaskCard), findsOneWidget);
      expect(find.text('1 tasks'), findsOneWidget);
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
      await tester.tap(find.text('Interview project'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
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
