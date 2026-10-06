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
      home: UpdateStatusScreen(
        task: Task(id: 501, name: name, status: status),
        service: TaskService(client: client),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
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
