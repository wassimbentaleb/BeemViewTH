import 'dart:async';
import 'dart:convert';

import 'package:beemview/controllers/update_status_controller.dart';
import 'package:beemview/core/app_config.dart';
import 'package:beemview/models/task.dart';
import 'package:beemview/services/api_client.dart';
import 'package:beemview/services/task_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

UpdateStatusController createUpdateController(
  Future<http.Response> Function(http.Request) handler, {
  String status = 'to_do',
}) {
  // Le controller est teste avec le vrai service et des reponses HTTP controlees.
  final client = ApiClient(
    config: const AppConfig(subdomain: 'test-tenant'),
    client: MockClient(handler),
  );
  final controller = UpdateStatusController(
    service: TaskService(client: client),
    task: Task(id: 501, name: 'Inspection', status: status),
  );
  addTearDown(client.close);
  addTearDown(controller.dispose);
  return controller;
}

void main() {
  test(
    'status precedes note and duplicate calls cannot repeat either write',
    () async {
      // Les deux delais permettent de toucher Save pendant chacune des operations.
      final put = Completer<http.Response>();
      final post = Completer<http.Response>();
      final methods = <String>[];
      final controller =
          createUpdateController((request) {
              methods.add(request.method);
              return request.method == 'PUT' ? put.future : post.future;
            })
            ..selectStatus('in_progress')
            ..setNote(' Inspection started ');
      final saving = controller.save();
      await controller.save();
      controller.selectStatus('done');
      controller.setNote('Changed while saving');
      // MockClient lit d'abord le body avant de livrer la requete au handler.
      await Future<void>.delayed(Duration.zero);
      expect(controller.isSaving, isTrue);
      expect(controller.selectedStatus, 'in_progress');
      expect(controller.note, ' Inspection started ');
      expect(methods, ['PUT']);
      put.complete(http.Response('{}', 200));
      await Future<void>.delayed(Duration.zero);
      expect(controller.statusSaved, isTrue);
      expect(controller.currentStatusLabel, 'In progress');
      expect(methods, ['PUT', 'POST']);
      await controller.save();
      post.complete(http.Response('{}', 201));
      await saving;
      await controller.save();
      expect(controller.isComplete, isTrue);
      expect(controller.taskChanged, isTrue);
      expect(methods, ['PUT', 'POST']);
    },
  );

  test(
    'whitespace note skips POST and unknown status requires a choice',
    () async {
      // Un status inconnu n'est pas remplace silencieusement par To do.
      final methods = <String>[];
      final controller = createUpdateController((request) async {
        methods.add(request.method);
        return http.Response('{}', 200);
      }, status: 'future_status');
      expect(controller.selectedStatus, isNull);
      await controller.save();
      expect(methods, isEmpty);
      controller.selectStatus('review');
      controller.setNote(' \n ');
      await controller.save();
      expect(methods, ['PUT']);
      expect(controller.isComplete, isTrue);
    },
  );

  test('rejected status preserves input and never sends the note', () async {
    // Le second clic relance PUT apres refus explicite, puis POST une seule fois.
    final methods = <String>[];
    final controller =
        createUpdateController((request) async {
            methods.add(request.method);
            return methods.length == 1
                ? http.Response('{"message":"No access"}', 403)
                : http.Response('{}', 200);
          })
          ..selectStatus('done')
          ..setNote('Keep this note');
    await controller.save();
    expect(controller.statusSaved, isFalse);
    expect(controller.error, 'No access');
    expect(controller.note, 'Keep this note');
    expect(controller.selectedStatus, 'done');
    expect(controller.taskChanged, isFalse);
    await controller.save();
    expect(controller.isComplete, isTrue);
    expect(methods, ['PUT', 'PUT', 'POST']);
  });

  test(
    'comment Retry preserves saved status and sends only the edited note',
    () async {
      // Le status confirme reste verrouille meme si l'utilisateur corrige sa note.
      final methods = <String>[];
      final controller =
          createUpdateController((request) async {
              methods.add(request.method);
              if (methods.length == 2) {
                return http.Response('{"message":"Invalid note"}', 400);
              }
              if (methods.length == 3) {
                expect(jsonDecode(request.body)['content'], 'Corrected note');
              }
              return http.Response('{}', 200);
            })
            ..selectStatus('blocked')
            ..setNote('Original note');
      await controller.save();
      expect(controller.statusSaved, isTrue);
      expect(controller.error, 'Invalid note');
      expect(controller.isComplete, isFalse);
      expect(controller.note, 'Original note');
      controller.selectStatus('done');
      expect(controller.selectedStatus, 'blocked');
      controller.setNote('Corrected note');
      await controller.save();
      expect(methods, ['PUT', 'POST', 'POST']);
      expect(controller.isComplete, isTrue);
    },
  );

  for (final failingMethod in ['PUT', 'POST']) {
    test(
      'unknown $failingMethod outcome keeps input and disables all resubmission',
      () async {
        // La note peut etre deja enregistree: aucun retry automatique ou double clic.
        final methods = <String>[];
        final controller =
            createUpdateController((request) async {
                methods.add(request.method);
                if (request.method == failingMethod) {
                  throw http.ClientException('Response lost');
                }
                return http.Response('{}', 200);
              })
              ..selectStatus('review')
              ..setNote('Preserved note');
        await controller.save();
        expect(controller.outcomeUnknown, isTrue);
        expect(controller.taskChanged, isTrue);
        expect(controller.statusSaved, failingMethod == 'POST');
        expect(controller.note, 'Preserved note');
        expect(controller.canSave, isFalse);
        await controller.save();
        expect(methods, failingMethod == 'PUT' ? ['PUT'] : ['PUT', 'POST']);
      },
    );
  }

  test('404 prevents writes to a task that no longer exists', () async {
    // Une nouvelle tentative sur le meme ID n'a pas de sens apres Not found.
    var calls = 0;
    final controller = createUpdateController((request) async {
      calls++;
      return http.Response('{}', 404);
    });
    await controller.save();
    expect(controller.isNotFound, isTrue);
    expect(controller.canSave, isFalse);
    await controller.save();
    expect(calls, 1);
  });

  test(
    'late responses never notify or send a comment after disposal',
    () async {
      // Simule fermeture de la route par expiration de session pendant PUT.
      final pending = Completer<http.Response>();
      var calls = 0;
      final client = ApiClient(
        config: const AppConfig(subdomain: 'test-tenant'),
        client: MockClient((request) {
          calls++;
          return pending.future;
        }),
      );
      addTearDown(client.close);
      final controller = UpdateStatusController(
        service: TaskService(client: client),
        task: const Task(id: 501, name: 'Inspection', status: 'to_do'),
      )..setNote('Must not be sent');
      var notifications = 0;
      controller.addListener(() {
        notifications++;
      });
      final saving = controller.save();
      controller.dispose();
      pending.complete(http.Response('{}', 200));
      await saving;
      expect(notifications, 1);
      expect(calls, 1);
    },
  );
}
