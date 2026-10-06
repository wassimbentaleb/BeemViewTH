import 'dart:async';
import 'dart:convert';

import 'package:beemview/app.dart';
import 'package:beemview/controllers/auth_controller.dart';
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
