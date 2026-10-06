import 'dart:convert';

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
