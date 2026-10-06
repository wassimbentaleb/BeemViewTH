import 'dart:async';

import 'package:beemview/core/app_config.dart';
import 'package:beemview/core/app_theme.dart';
import 'package:beemview/models/task.dart';
import 'package:beemview/screens/update_status_screen.dart';
import 'package:beemview/services/api_client.dart';
import 'package:beemview/services/task_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Future<void> showUpdateForm(
  WidgetTester tester, {
  String status = 'review',
  String name = 'Site inspection',
  TextScaler textScaler = TextScaler.noScaling,
  Future<http.Response> Function(http.Request)? handler,
}) async {
  // Ce helper utilise le vrai formulaire avec le client HTTP simule.
  final client = ApiClient(
    config: const AppConfig(subdomain: 'test-tenant'),
    client: MockClient(
      handler ??
          (request) async {
            fail('Choosing a status must not write to the server.');
          },
    ),
  );
  addTearDown(client.close);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: textScaler),
        child: child!,
      ),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () async {
                final changed = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (context) => UpdateStatusScreen(
                      task: Task(id: 501, name: name, status: status),
                      service: TaskService(client: client),
                    ),
                  ),
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Changed: $changed')));
                }
              },
              child: const Text('Open update'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open update'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('saving locks choices note and Back until both writes finish', (
    tester,
  ) async {
    // Le retour Android et un second clic ne doivent interrompre ou doubler la sauvegarde.
    final put = Completer<http.Response>();
    final post = Completer<http.Response>();
    final methods = <String>[];
    await showUpdateForm(
      tester,
      handler: (request) {
        methods.add(request.method);
        return request.method == 'PUT' ? put.future : post.future;
      },
    );
    final note = find.byKey(const ValueKey('status-note'));
    await tester.ensureVisible(note);
    await tester.enterText(note, 'Inspection started');
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Save status'),
    );
    await tester.tap(find.text('Save status'));
    button.onPressed!();
    await tester.pump();
    expect(find.text('Saving status...'), findsOneWidget);
    expect(tester.widget<TextField>(note).readOnly, isTrue);
    expect(
      tester.widget<InkWell>(find.byKey(const ValueKey('status-done'))).onTap,
      isNull,
    );
    await tester.pageBack();
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.byType(UpdateStatusScreen), findsOneWidget);
    expect(methods, ['PUT']);
    put.complete(http.Response('{}', 200));
    await tester.pump();
    expect(find.text('Saving comment...'), findsOneWidget);
    expect(methods, ['PUT', 'POST']);
    post.complete(http.Response('{}', 201));
    await tester.pumpAndSettle();
    expect(find.byType(UpdateStatusScreen), findsNothing);
    expect(find.text('Changed: true'), findsOneWidget);
    expect(methods, ['PUT', 'POST']);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('partial success keeps the note and retries only the comment', (
    tester,
  ) async {
    // Le status courant change apres PUT, tandis que la note reste editable apres 400.
    final methods = <String>[];
    await showUpdateForm(
      tester,
      handler: (request) async {
        methods.add(request.method);
        return methods.length == 2
            ? http.Response('{"message":"Correct the note"}', 400)
            : http.Response('{}', 200);
      },
    );
    await tester.tap(find.byKey(const ValueKey('status-in_progress')));
    final note = find.byKey(const ValueKey('status-note'));
    await tester.ensureVisible(note);
    await tester.enterText(note, 'Keep the note');
    await tester.tap(find.text('Save status'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Status saved. Your note was not added. Edit it or retry the comment.',
      ),
      findsOneWidget,
    );
    expect(tester.widget<TextField>(note).controller!.text, 'Keep the note');
    expect(tester.widget<TextField>(note).readOnly, isFalse);
    expect(find.text('Current status: In progress'), findsOneWidget);
    await tester.tap(find.text('Retry comment'));
    await tester.pumpAndSettle();
    expect(methods, ['PUT', 'POST', 'POST']);
    expect(find.text('Changed: true'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'lost comment response offers verification instead of resubmission',
    (tester) async {
      // Le resultat peut deja exister; la note reste copiable et aucun POST ne repart.
      final methods = <String>[];
      await showUpdateForm(
        tester,
        handler: (request) async {
          methods.add(request.method);
          if (request.method == 'POST') {
            throw http.ClientException('Response lost');
          }
          return http.Response('{}', 200);
        },
      );
      final note = find.byKey(const ValueKey('status-note'));
      await tester.ensureVisible(note);
      await tester.enterText(note, 'Preserved note');
      await tester.tap(find.text('Save status'));
      await tester.pumpAndSettle();
      expect(find.text('Check task details'), findsOneWidget);
      expect(tester.widget<TextField>(note).controller!.text, 'Preserved note');
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Retry comment'),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.text('Check task details'));
      await tester.pumpAndSettle();
      expect(find.text('Changed: true'), findsOneWidget);
      expect(methods, ['PUT', 'POST']);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'unknown status disables Save until a documented choice is made',
    (tester) async {
      // Ne jamais envoyer une valeur inventee lorsque le serveur ajoute un status inconnu.
      await showUpdateForm(tester, status: 'future_status');
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Save status'),
            )
            .onPressed,
        isNull,
      );
      await tester.ensureVisible(find.byKey(const ValueKey('status-on_hold')));
      await tester.tap(find.byKey(const ValueKey('status-on_hold')));
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Save status'),
            )
            .onPressed,
        isNotNull,
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Changed: false'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('fresh status is selected and choices preserve the note', (
    tester,
  ) async {
    // Choisir et ecrire restent locaux tant que Save n'est pas touche.
    await showUpdateForm(tester);
    expect(find.text('Current status: Review'), findsOneWidget);
    for (final status in Task.statusLabels.keys) {
      expect(find.byKey(ValueKey('status-$status')), findsOneWidget);
    }
    final note = find.byKey(const ValueKey('status-note'));
    await tester.ensureVisible(note);
    await tester.enterText(note, 'Inspection started');
    await tester.ensureVisible(
      find.byKey(const ValueKey('status-in_progress')),
    );
    await tester.tap(find.byKey(const ValueKey('status-in_progress')));
    await tester.pump();
    expect(
      tester.widget<TextField>(note).controller!.text,
      'Inspection started',
    );
    final choice = tester.widget<InkWell>(
      find.byKey(const ValueKey('status-in_progress')),
    );
    expect(choice.onTap, isNotNull);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('320px enlarged text and keyboard keep all choices reachable', (
    tester,
  ) async {
    // Les cartes passent a une colonne et grandissent sans masquer le champ note.
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await showUpdateForm(
      tester,
      name: 'Inspect a very long assigned construction site name',
      textScaler: const TextScaler.linear(1.8),
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('status-changes_requested')),
    );
    await tester.tap(find.byKey(const ValueKey('status-changes_requested')));
    await tester.ensureVisible(find.byKey(const ValueKey('status-note')));
    await tester.enterText(
      find.byKey(const ValueKey('status-note')),
      'Long note\nSecond line',
    );
    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('status-note')));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
