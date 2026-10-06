import 'dart:convert';

import 'package:beemview/app.dart';
import 'package:beemview/controllers/auth_controller.dart';
import 'package:beemview/screens/task_details_screen.dart';
import 'package:beemview/screens/update_status_screen.dart';
import 'package:beemview/widgets/task_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'projects_screen_test.dart' show createController;

Future<void> openTask(
  WidgetTester tester,
  AuthController auth, {
  bool filter = false,
}) async {
  // Le test suit Projects -> Tasks -> Details avec les vraies routes.
  await tester.pumpWidget(BeemViewApp(authController: auth));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Interview project'));
  await tester.pumpAndSettle();
  if (filter) {
    await tester.enterText(find.byType(TextField), 'inspection');
    await tester.tap(find.byTooltip('Filter: To do'));
    await tester.pumpAndSettle();
  }
  await tester.ensureVisible(find.text('Site inspection'));
  await tester.tap(find.text('Site inspection'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'a lost comment response refreshes the actual comment without resending it',
    (tester) async {
      // Simule POST applique au serveur dont la reponse se perd ensuite.
      var added = false;
      var detailReads = 0;
      final methods = <String>[];
      final auth = createController(
        (request) async => http.Response(
          '{"data":[{"id":102,"name":"Interview project"}],"total":1}',
          200,
        ),
        tasks: (request) async => http.Response(
          '{"tasks":[{"id":501,"name":"Site inspection","status":"to_do"}]}',
          200,
        ),
        details: (request) async {
          detailReads++;
          return http.Response(
            jsonEncode({
              'task': {
                'id': 501,
                'name': 'Site inspection',
                'status': 'to_do',
                'Comments': added
                    ? [
                        {
                          'id': 99,
                          'content': 'Saved despite lost response',
                          'user': {'name': 'Candidate'},
                        },
                      ]
                    : [],
              },
            }),
            200,
          );
        },
        writes: (request) async {
          methods.add(request.method);
          if (request.method == 'POST') {
            added = true;
            throw http.ClientException('Response lost');
          }
          return http.Response('{}', 200);
        },
      );
      await openTask(tester, auth);
      await tester.tap(find.text('Update status'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('status-note')));
      await tester.enterText(
        find.byKey(const ValueKey('status-note')),
        'Saved despite lost response',
      );
      await tester.tap(find.text('Save status'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Check task details'));
      await tester.pumpAndSettle();
      expect(find.text('Saved despite lost response'), findsOneWidget);
      expect(detailReads, 2);
      expect(methods, ['PUT', 'POST']);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'session expiry during the comment clears all routes after saved status',
    (tester) async {
      // Le succes partiel ne doit pas garder une route protegee apres un POST401.
      final methods = <String>[];
      final auth = createController(
        (request) async => http.Response(
          '{"data":[{"id":102,"name":"Interview project"}],"total":1}',
          200,
        ),
        tasks: (request) async => http.Response(
          '{"tasks":[{"id":501,"name":"Site inspection","status":"to_do"}]}',
          200,
        ),
        details: (request) async => http.Response(
          '{"task":{"id":501,"name":"Site inspection","status":"to_do"}}',
          200,
        ),
        writes: (request) async {
          methods.add(request.method);
          return request.method == 'PUT'
              ? http.Response('{}', 200)
              : http.Response('{}', 401);
        },
      );
      await openTask(tester, auth);
      await tester.tap(find.text('Update status'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('status-note')));
      await tester.enterText(find.byKey(const ValueKey('status-note')), 'Note');
      await tester.tap(find.text('Save status'));
      await tester.pumpAndSettle();
      expect(find.text('Welcome back'), findsOneWidget);
      expect(await auth.store.readToken(), isNull);
      expect(
        Navigator.of(tester.element(find.text('Welcome back'))).canPop(),
        isFalse,
      );
      expect(methods, ['PUT', 'POST']);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'Save refreshes Details and Tasks without losing name or status filters',
    (tester) async {
      // La task quitte To do: la liste rechargee doit respecter le filtre conserve.
      var status = 'to_do';
      var taskReads = 0;
      var detailReads = 0;
      final methods = <String>[];
      final comments = <Map<String, dynamic>>[];
      final auth = createController(
        (request) async => http.Response(
          '{"data":[{"id":102,"name":"Interview project"}],"total":1}',
          200,
        ),
        tasks: (request) async {
          taskReads++;
          return http.Response(
            jsonEncode({
              'tasks': [
                {'id': 501, 'name': 'Site inspection', 'status': status},
              ],
            }),
            200,
          );
        },
        details: (request) async {
          detailReads++;
          return http.Response(
            jsonEncode({
              'task': {
                'id': 501,
                'name': 'Site inspection',
                'status': status,
                'Comments': comments,
              },
            }),
            200,
          );
        },
        writes: (request) async {
          methods.add(request.method);
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          if (request.method == 'PUT') {
            status = body['status'] as String;
            return http.Response('{}', 200);
          }
          comments.add({
            'id': 99,
            'content': body['content'],
            'created_at': '2026-10-07T00:00:00Z',
            'user': {'name': 'Candidate'},
          });
          return http.Response('{}', 201);
        },
      );
      await openTask(tester, auth, filter: true);
      await tester.tap(find.text('Update status'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('status-in_progress')));
      await tester.ensureVisible(find.byKey(const ValueKey('status-note')));
      await tester.enterText(
        find.byKey(const ValueKey('status-note')),
        'Inspection started',
      );
      await tester.tap(find.text('Save status'));
      await tester.pumpAndSettle();
      expect(find.byType(UpdateStatusScreen), findsNothing);
      expect(find.text('In progress'), findsOneWidget);
      expect(find.text('Inspection started'), findsOneWidget);
      expect(detailReads, 2);
      expect(taskReads, 1);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(TaskDetailsScreen), findsNothing);
      expect(taskReads, 2);
      expect(find.text('No matching tasks'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'inspection',
      );
      expect(
        tester
            .widget<ChoiceChip>(
              find.ancestor(
                of: find.byTooltip('Filter: To do'),
                matching: find.byType(ChoiceChip),
              ),
            )
            .selected,
        isTrue,
      );
      await tester.ensureVisible(find.byTooltip('Filter: In progress'));
      await tester.tap(find.byTooltip('Filter: In progress'));
      await tester.pumpAndSettle();
      expect(find.byType(TaskCard), findsOneWidget);
      expect(taskReads, 2);
      expect(methods, ['PUT', 'POST']);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'a failed refresh keeps save result and retries only GET before returning to Tasks',
    (tester) async {
      // Un echec du GET apres PUT ne doit jamais renvoyer status ou note.
      var taskReads = 0;
      var detailReads = 0;
      var writes = 0;
      final auth = createController(
        (request) async => http.Response(
          '{"data":[{"id":102,"name":"Interview project"}],"total":1}',
          200,
        ),
        tasks: (request) async {
          taskReads++;
          return http.Response(
            '{"tasks":[{"id":501,"name":"Site inspection","status":"to_do"}]}',
            200,
          );
        },
        details: (request) async {
          detailReads++;
          if (detailReads == 2) throw http.ClientException('Offline');
          return http.Response(
            '{"task":{"id":501,"name":"Site inspection","status":"${writes == 0 ? 'to_do' : 'done'}"}}',
            200,
          );
        },
        writes: (request) async {
          writes++;
          expect(request.method, 'PUT');
          return http.Response('{}', 200);
        },
      );
      await openTask(tester, auth);
      await tester.tap(find.text('Update status'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('status-done')));
      await tester.tap(find.byKey(const ValueKey('status-done')));
      await tester.tap(find.text('Save status'));
      await tester.pumpAndSettle();
      expect(find.text('Could not load task details'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('Done'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(detailReads, 3);
      expect(taskReads, 2);
      expect(writes, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final code in [401, 403, 404, 429]) {
    testWidgets(
      'write HTTP $code preserves the right recovery and session state',
      (tester) async {
        // 401 ferme toutes les routes; les autres refus conservent note et session.
        var writes = 0;
        var detailReads = 0;
        var taskReads = 0;
        final auth = createController(
          (request) async => http.Response(
            '{"data":[{"id":102,"name":"Interview project"}],"total":1}',
            200,
          ),
          tasks: (request) async {
            taskReads++;
            return http.Response(
              '{"tasks":[{"id":501,"name":"Site inspection","status":"to_do"}]}',
              200,
            );
          },
          details: (request) async {
            detailReads++;
            return code == 404 && detailReads > 1
                ? http.Response('{}', 404)
                : http.Response(
                    '{"task":{"id":501,"name":"Site inspection","status":"to_do"}}',
                    200,
                  );
          },
          writes: (request) async {
            writes++;
            return http.Response('{"message":"Write refused"}', code);
          },
        );
        await openTask(tester, auth);
        await tester.tap(find.text('Update status'));
        await tester.pumpAndSettle();
        final note = find.byKey(const ValueKey('status-note'));
        await tester.ensureVisible(note);
        await tester.enterText(note, 'Preserved note');
        await tester.tap(find.text('Save status'));
        await tester.pumpAndSettle();
        expect(writes, 1);
        if (code == 401) {
          expect(find.text('Welcome back'), findsOneWidget);
          expect(await auth.store.readToken(), isNull);
          expect(
            Navigator.of(tester.element(find.text('Welcome back'))).canPop(),
            isFalse,
          );
        } else {
          expect(await auth.store.readToken(), 'test-token');
          expect(
            tester.widget<TextField>(note).controller!.text,
            'Preserved note',
          );
          if (code == 404) {
            expect(
              tester
                  .widget<FilledButton>(
                    find.widgetWithText(FilledButton, 'Save status'),
                  )
                  .onPressed,
              isNull,
            );
            await tester.tap(find.text('Back to details'));
            await tester.pumpAndSettle();
            expect(find.text('Task not found'), findsOneWidget);
            await tester.tap(find.text('Back to tasks'));
            await tester.pumpAndSettle();
            expect(taskReads, 2);
            expect(detailReads, 2);
          } else {
            expect(
              find.text(
                'Status was not saved. Your choices and note are kept.',
              ),
              findsOneWidget,
            );
            await tester.pageBack();
            await tester.pumpAndSettle();
            expect(detailReads, 1);
          }
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
