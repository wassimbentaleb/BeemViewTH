import 'dart:convert';
import 'dart:async';

import 'package:beemview/controllers/tasks_controller.dart';
import 'package:beemview/core/app_config.dart';
import 'package:beemview/models/task.dart';
import 'package:beemview/services/api_client.dart';
import 'package:beemview/services/task_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'duplicate loads are blocked and Retry keeps the selected filters',
    () async {
      // Un premier echec puis un succes doivent garder le projet et les controles.
      var calls = 0;
      final first = Completer<http.Response>();
      final client = ApiClient(
        config: const AppConfig(subdomain: 'test-tenant'),
        client: MockClient((request) {
          calls++;
          expect(request.url.path, '/api/tasks/project/102');
          return calls == 1
              ? first.future
              : Future.value(
                  http.Response(
                    '{"tasks":[{"id":501,"name":"Inspection","status":"review"}]}',
                    200,
                  ),
                );
        }),
      );
      final controller = TasksController(
        service: TaskService(client: client),
        projectId: 102,
      );
      addTearDown(client.close);
      addTearDown(controller.dispose);
      controller.setQuery('inspect');
      controller.setStatus('review');
      final loading = controller.loadTasks();
      await controller.loadTasks();
      // MockClient termine la lecture asynchrone du body avant son callback.
      await Future<void>.delayed(Duration.zero);
      expect(calls, 1);
      expect(controller.isLoading, isTrue);
      first.complete(http.Response('{"message":"Try later"}', 429));
      await loading;
      expect(controller.error, 'Try later');
      expect(controller.isLoading, isFalse);
      await controller.loadTasks();
      expect(controller.visibleTasks.single.id, 501);
      expect(controller.error, isNull);
      expect(controller.query, 'inspect');
      expect(controller.status, 'review');
      expect(calls, 2);
      controller.clearFilters();
      expect(controller.query, '');
      expect(controller.status, isNull);
    },
  );

  test('closing Tasks while a request is pending ignores its late response', () async {
    // La fermeture du controller ne ferme pas le client HTTP partage de l'app.
    final response = Completer<http.Response>();
    final client = ApiClient(
      config: const AppConfig(subdomain: 'test-tenant'),
      client: MockClient((request) => response.future),
    );
    final controller = TasksController(
      service: TaskService(client: client),
      projectId: 102,
    );
    addTearDown(client.close);
    var notifications = 0;
    controller.addListener(() {
      notifications++;
    });
    final loading = controller.loadTasks();
    expect(notifications, 1);
    controller.dispose();
    response.complete(
      http.Response('{"tasks":[{"id":501,"name":"Inspection"}]}', 200),
    );
    await loading;
    expect(notifications, 1);
    expect(controller.tasks, isEmpty);
  });

  test(
    'all documented statuses and search intersect over the loaded collection',
    () async {
      // Inclut Review et Blocked, absents des premiers chips visibles dans la maquette.
      var calls = 0;
      final statuses = Task.statusLabels.keys.toList();
      final client = ApiClient(
        config: const AppConfig(subdomain: 'test-tenant'),
        client: MockClient((request) async {
          calls++;
          return http.Response(
            jsonEncode({
              'tasks': [
                for (var index = 0; index < statuses.length; index++)
                  {
                    'id': index + 1,
                    'name': 'Inspection $index',
                    'status': statuses[index],
                  },
                {'id': 99, 'name': 'Other name', 'status': 'review'},
                {'id': 100, 'name': 'Unknown task', 'status': 'custom_status'},
              ],
            }),
            200,
          );
        }),
      );
      final controller = TasksController(
        service: TaskService(client: client),
        projectId: 102,
      );
      addTearDown(client.close);
      addTearDown(controller.dispose);
      await controller.loadTasks();
      expect(controller.tasks.length, 10);
      controller.setQuery(' INSPECTION ');
      for (final status in statuses) {
        controller.setStatus(status);
        expect(controller.visibleTasks.single.status, status);
      }
      controller.setQuery('Other');
      controller.setStatus('to_do');
      expect(controller.visibleTasks, isEmpty);
      controller.setStatus('review');
      expect(controller.visibleTasks.single.id, 99);
      controller.setQuery('');
      controller.setStatus(null);
      expect(controller.visibleTasks.length, 10);
      expect(calls, 1);
      expect(() => controller.tasks.clear(), throwsUnsupportedError);
    },
  );
}
