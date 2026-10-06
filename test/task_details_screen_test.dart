import 'dart:async';
import 'dart:convert';

import 'package:beemview/app.dart';
import 'package:beemview/controllers/auth_controller.dart';
import 'package:beemview/core/date_formatter.dart';
import 'package:beemview/screens/update_status_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'projects_screen_test.dart' show createController;

// Une fiche du meme ID peut avoir un nom/status plus recent que la carte de liste.
const detailResponse =
    '{"task":{"id":501,"name":"Updated inspection","status":"in_progress","priority":"low","description":"Inspect the assigned site.","Project":{"id":102,"name":"Interview project"},"Assignees":[{"id":12,"full_name":"Candidate"}],"start_date":"2026-10-06","due_date":"2026-10-09","Comments":[]}}';

AuthController createDetailSession(
  Future<http.Response> Function(http.Request) details,
) {
  // Le vrai arbre de navigation utilise des reponses HTTP simulees.
  return createController(
    (request) async => http.Response(
      '{"data":[{"id":102,"name":"Interview project"}],"total":1}',
      200,
    ),
    tasks: (request) async => http.Response(
      '{"tasks":[{"id":501,"name":"Site inspection","status":"to_do","priority":"High"}]}',
      200,
    ),
    details: details,
  );
}

Future<void> openDetails(WidgetTester tester, AuthController auth) async {
  // Ouvre la task par les cartes, comme un utilisateur de l'app.
  await tester.pumpWidget(BeemViewApp(authController: auth));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('Interview project'));
  await tester.tap(find.text('Interview project'));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('Site inspection'));
  await tester.tap(find.text('Site inspection'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets(
    'Update status receives fresh detail values and Back preserves the loaded fiche',
    (tester) async {
      // La carte etait To do; Details a renvoye In progress. Aucune ecriture ne doit etre envoyee.
      var calls = 0;
      final auth = createDetailSession((request) async {
        expect(request.method, 'GET');
        calls++;
        return http.Response(detailResponse, 200);
      });
      await openDetails(tester, auth);
      await tester.pumpAndSettle();
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Update status'),
      );
      await tester.tap(find.text('Update status'));
      button.onPressed!();
      await tester.pumpAndSettle();
      final screen = tester.widget<UpdateStatusScreen>(
        find.byType(UpdateStatusScreen),
      );
      expect(screen.task.id, 501);
      expect(screen.task.name, 'Updated inspection');
      expect(screen.task.status, 'in_progress');
      expect(find.text('Current status: In progress'), findsOneWidget);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.byType(UpdateStatusScreen), findsNothing);
      expect(find.text('Inspect the assigned site.'), findsOneWidget);
      expect(calls, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final status in [401, 403, 404]) {
    testWidgets(
      'detail HTTP $status handles recovery session and open routes',
      (tester) async {
        // Une session expiree, un acces refuse et une task absente demandent des actions differentes.
        var calls = 0;
        final auth = createDetailSession((request) async {
          calls++;
          return calls == 1
              ? http.Response('{"message":"Detail unavailable"}', status)
              : http.Response(detailResponse, 200);
        });
        await openDetails(tester, auth);
        await tester.pumpAndSettle();
        if (status == 401) {
          expect(find.text('Welcome back'), findsOneWidget);
          expect(await auth.store.readToken(), isNull);
          expect(
            Navigator.of(tester.element(find.text('Welcome back'))).canPop(),
            isFalse,
          );
        } else if (status == 403) {
          expect(find.text('Could not load task details'), findsOneWidget);
          expect(await auth.store.readToken(), 'test-token');
          await tester.ensureVisible(find.text('Retry'));
          await tester.tap(find.text('Retry'));
          await tester.pumpAndSettle();
          expect(find.text('Updated inspection'), findsOneWidget);
          expect(find.text('Detail unavailable'), findsNothing);
          expect(calls, 2);
        } else {
          expect(find.text('Task not found'), findsOneWidget);
          expect(find.text('Retry'), findsNothing);
          await tester.ensureVisible(find.text('Back to tasks'));
          await tester.tap(find.text('Back to tasks'));
          await tester.pumpAndSettle();
          expect(find.text('Project tasks'), findsOneWidget);
          expect(find.text('Site inspection'), findsOneWidget);
          expect(await auth.store.readToken(), 'test-token');
          expect(calls, 1);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets(
    'detail connectivity error retries the same task without clearing the session',
    (tester) async {
      // Une panne reseau ne signifie pas que le token est expire.
      var calls = 0;
      final auth = createDetailSession((request) async {
        expect(request.url.path, '/api/tasks/501');
        if (++calls == 1) throw http.ClientException('Offline');
        return http.Response(detailResponse, 200);
      });
      await openDetails(tester, auth);
      await tester.pumpAndSettle();
      expect(
        find.text('Could not connect. Check your internet connection.'),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('Retry'));
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('Updated inspection'), findsOneWidget);
      expect(await auth.store.readToken(), 'test-token');
      expect(calls, 2);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'long detail fields and comment fit a narrow screen with enlarged text',
    (tester) async {
      // Les lignes d'information passent en vertical et les textes restent scrollables.
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.8;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final data = jsonDecode(detailResponse) as Map<String, dynamic>;
      data['task']['name'] =
          'A very long inspection name for the assigned construction site';
      data['task']['description'] =
          'A detailed description of the inspection. ' * 12;
      data['task']['Project']['name'] = 'A project with a very long name';
      data['task']['Assignees'] = [
        {'id': 12, 'full_name': 'A candidate with a long display name'},
        {'id': 13, 'full_name': 'Second candidate'},
      ];
      data['task']['Comments'] = [
        {
          'id': 77,
          'content':
              'Ready for a detailed inspection of the construction site.',
          'user': {'name': 'A comment author with a long display name'},
        },
      ];
      final auth = createDetailSession(
        (request) async => http.Response(jsonEncode(data), 200),
      );
      await openDetails(tester, auth);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Second candidate'));
      await tester.ensureVisible(
        find.text('Ready for a detailed inspection of the construction site.'),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'latest returned comment shows its content author and timestamp only',
    (tester) async {
      // L'ecran ne montre pas un ancien commentaire juste parce qu'il arrive en premier.
      final data = jsonDecode(detailResponse) as Map<String, dynamic>;
      data['task']['Comments'] = [
        {
          'id': 90,
          'content': 'Older comment',
          'created_at': '2026-10-05T09:00:00Z',
          'user': {'name': 'Older user'},
        },
        {
          'id': 77,
          'content': 'Ready for inspection',
          'created_at': '2026-10-06T09:00:00Z',
          'user': {'name': 'Comment author'},
        },
      ];
      final auth = createDetailSession(
        (request) async => http.Response(jsonEncode(data), 200),
      );
      await openDetails(tester, auth);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Ready for inspection'));
      expect(find.text('Comment author'), findsOneWidget);
      expect(
        find.text(DateFormatter.timestamp(DateTime.utc(2026, 10, 6, 9))),
        findsOneWidget,
      );
      expect(find.text('Older comment'), findsNothing);
      expect(find.text('Older user'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'details display project every assignee and all available dates',
    (tester) async {
      // Les informations viennent de Details, y compris un projet renomme depuis la liste.
      final data = jsonDecode(detailResponse) as Map<String, dynamic>;
      final task = data['task'] as Map<String, dynamic>;
      task['Project'] = {'id': 102, 'name': 'Updated project name'};
      task['Assignees'] = [
        {'id': 12, 'full_name': 'Candidate'},
        {'id': 13, 'full_name': 'Colleague'},
      ];
      task['created_at'] = '2026-10-05T09:00:00Z';
      task['updated_at'] = '2026-10-06T10:00:00Z';
      final auth = createDetailSession(
        (request) async => http.Response(jsonEncode(data), 200),
      );
      await openDetails(tester, auth);
      await tester.pumpAndSettle();
      expect(find.text('Updated project name'), findsOneWidget);
      expect(find.text('Candidate'), findsOneWidget);
      expect(find.text('Colleague'), findsOneWidget);
      expect(find.text('Oct 6, 2026'), findsOneWidget);
      expect(find.text('Oct 9, 2026'), findsOneWidget);
      expect(find.text('Created'), findsOneWidget);
      expect(find.text('Updated'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'details show loading then fresh API name badges and description',
    (tester) async {
      // Une seule lecture utilise l'ID choisi et actualise les anciennes donnees de la carte.
      final response = Completer<http.Response>();
      var calls = 0;
      final auth = createDetailSession((request) {
        calls++;
        expect(request.url.path, '/api/tasks/501');
        return response.future;
      });
      await openDetails(tester, auth);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Update status'), findsNothing);
      response.complete(http.Response(detailResponse, 200));
      await tester.pumpAndSettle();
      expect(find.text('Updated inspection'), findsOneWidget);
      expect(find.text('Inspect the assigned site.'), findsOneWidget);
      expect(find.text('In progress'), findsOneWidget);
      expect(find.text('Description'), findsOneWidget);
      expect(calls, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('missing description displays a useful empty value', (
    tester,
  ) async {
    // Une description null reste un succes de lecture et ne bloque pas la fiche.
    final auth = createDetailSession(
      (request) async => http.Response(
        '{"task":{"id":501,"name":"Inspection","description":null}}',
        200,
      ),
    );
    await openDetails(tester, auth);
    await tester.pumpAndSettle();
    expect(find.text('No description provided.'), findsOneWidget);
    expect(find.text('No comments available.'), findsOneWidget);
    expect(find.text('Interview project'), findsOneWidget);
    expect(find.text('Unassigned'), findsOneWidget);
    expect(find.text('No start date'), findsOneWidget);
    expect(find.text('No due date'), findsOneWidget);
    expect(find.text('Created'), findsNothing);
    expect(find.text('Updated'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
