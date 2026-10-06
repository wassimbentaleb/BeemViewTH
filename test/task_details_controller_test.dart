import 'dart:async';

import 'package:beemview/controllers/task_details_controller.dart';
import 'package:beemview/core/app_config.dart';
import 'package:beemview/services/api_client.dart';
import 'package:beemview/services/task_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const config = AppConfig(subdomain: 'test-tenant');
  const success = '{"task":{"id":501,"name":"Inspection"}}';

  test(
    'duplicate detail loads are blocked and Retry clears a previous 404',
    () async {
      // Le meme controller relit toujours le meme ID apres un echec.
      final response = Completer<http.Response>();
      var calls = 0;
      final client = ApiClient(
        config: config,
        client: MockClient((request) {
          calls++;
          expect(request.url.path, '/api/tasks/501');
          return calls == 1
              ? response.future
              : Future.value(http.Response(success, 200));
        }),
      );
      final controller = TaskDetailsController(
        service: TaskService(client: client),
        taskId: 501,
      );
      addTearDown(client.close);
      addTearDown(controller.dispose);
      final loading = controller.loadDetails();
      await controller.loadDetails();
      await Future<void>.delayed(Duration.zero);
      expect(calls, 1);
      expect(controller.isLoading, isTrue);
      response.complete(http.Response('{"message":"Task missing"}', 404));
      await loading;
      expect(controller.isNotFound, isTrue);
      expect(controller.error, 'Task missing');
      await controller.loadDetails();
      expect(controller.details!.task.id, 501);
      expect(controller.isNotFound, isFalse);
      expect(controller.error, isNull);
      expect(controller.isLoading, isFalse);
      expect(calls, 2);
    },
  );

  test('failed refresh retains the previous successful details and unlocks loading', () async {
    // La future etape Update Status pourra demander une nouvelle lecture explicite.
    var calls = 0;
    final client = ApiClient(
      config: config,
      client: MockClient(
        (request) async => ++calls == 1
            ? http.Response(success, 200)
            : http.Response('{"message":"Server unavailable"}', 500),
      ),
    );
    final controller = TaskDetailsController(
      service: TaskService(client: client),
      taskId: 501,
    );
    addTearDown(client.close);
    addTearDown(controller.dispose);
    await controller.loadDetails();
    final previous = controller.details;
    await controller.loadDetails();
    expect(controller.details, same(previous));
    expect(controller.error, 'Server unavailable');
    expect(controller.isLoading, isFalse);
  });

  test(
    'late success and late error do not notify a closed details screen',
    () async {
      // Le controller ignore la fin d'un appel apres retour vers Tasks.
      for (final status in [200, 500]) {
        final response = Completer<http.Response>();
        final client = ApiClient(
          config: config,
          client: MockClient((request) => response.future),
        );
        addTearDown(client.close);
        final controller = TaskDetailsController(
          service: TaskService(client: client),
          taskId: 501,
        );
        var notifications = 0;
        controller.addListener(() {
          notifications++;
        });
        final loading = controller.loadDetails();
        controller.dispose();
        response.complete(
          http.Response(
            status == 200 ? success : '{"message":"Failure"}',
            status,
          ),
        );
        await loading;
        expect(notifications, 1);
        expect(controller.details, isNull);
        expect(controller.error, isNull);
      }
    },
  );
}
