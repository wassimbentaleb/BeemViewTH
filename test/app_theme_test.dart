import 'package:beemview/app.dart';
import 'package:beemview/controllers/theme_controller.dart';
import 'package:beemview/core/app_theme.dart';
import 'package:beemview/screens/project_tasks_screen.dart';
import 'package:beemview/screens/task_details_screen.dart';
import 'package:beemview/screens/update_status_screen.dart';
import 'package:beemview/services/theme_store.dart';
import 'package:beemview/widgets/task_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'projects_screen_test.dart' show createController;

Brightness brightness(WidgetTester tester) =>
    Theme.of(tester.element(find.byType(Scaffold).last)).brightness;

// Simule un plugin indisponible sans acceder au stockage natif.
class UnavailableStorage extends Fake implements FlutterSecureStorage {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Storage unavailable');
}

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test(
    'missing, invalid and unreadable preferences fall back to the system',
    () async {
      expect(await const ThemeStore().readMode(), ThemeMode.system);
      FlutterSecureStorage.setMockInitialValues({
        ThemeStore.themeKey: 'unknown',
      });
      expect(await const ThemeStore().readMode(), ThemeMode.system);
      expect(
        await ThemeStore(storage: UnavailableStorage()).readMode(),
        ThemeMode.system,
      );
    },
  );

  testWidgets(
    'a failed preference write keeps the theme usable and reports it',
    (tester) async {
      final theme = ThemeController(
        store: ThemeStore(storage: UnavailableStorage()),
      );
      addTearDown(theme.dispose);
      await theme.restore();
      await tester.pumpWidget(BeemViewApp(themeController: theme));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Switch to dark mode'));
      await tester.pumpAndSettle();
      expect(brightness(tester), Brightness.dark);
      expect(
        find.text(
          'Theme changed. Could not save your preference for next time.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Switch to light mode'));
      await tester.pumpAndSettle();
      expect(brightness(tester), Brightness.light);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('system brightness is followed until the user chooses a mode', (
    tester,
  ) async {
    // Le telephone pilote le theme tant qu'aucun choix n'est sauvegarde.
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await tester.pumpWidget(const BeemViewApp());
    await tester.pumpAndSettle();
    expect(brightness(tester), Brightness.dark);
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    await tester.pumpAndSettle();
    expect(brightness(tester), Brightness.light);

    await tester.tap(find.byTooltip('Switch to dark mode'));
    await tester.pumpAndSettle();
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    await tester.pumpAndSettle();
    expect(brightness(tester), Brightness.dark);
    expect(await const ThemeStore().readMode(), ThemeMode.dark);
    expect(tester.takeException(), isNull);
  });

  testWidgets('login input survives toggles and the choice survives restart', (
    tester,
  ) async {
    // Le theme ne remonte pas le formulaire et ne vide pas ses controllers.
    await tester.pumpWidget(const BeemViewApp());
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'candidate@');
    await tester.enterText(find.byType(TextFormField).last, '12345');
    await tester.tap(find.byTooltip('Switch to dark mode'));
    await tester.pumpAndSettle();
    expect(find.text('candidate@'), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).last)
          .controller!
          .text,
      '12345',
    );
    expect(brightness(tester), Brightness.dark);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(const BeemViewApp());
    await tester.pumpAndSettle();
    expect(brightness(tester), Brightness.dark);
    await tester.tap(find.byTooltip('Switch to light mode'));
    await tester.pumpAndSettle();
    expect(brightness(tester), Brightness.light);
    expect(await const ThemeStore().readMode(), ThemeMode.light);
    expect(tester.takeException(), isNull);
  });

  testWidgets('all task routes keep their state while changing themes', (
    tester,
  ) async {
    // Une vraie navigation verifie recherche, filtres, note et absence de relectures.
    var taskReads = 0;
    var detailReads = 0;
    final auth = createController(
      (_) async => http.Response(
        '{"data":[{"id":102,"name":"Interview project"}],"total":1}',
        200,
      ),
      tasks: (_) async {
        taskReads++;
        return http.Response(
          '{"tasks":[{"id":501,"name":"Site inspection","status":"to_do","priority":"high"}]}',
          200,
        );
      },
      details: (_) async {
        detailReads++;
        return http.Response(
          '{"task":{"id":501,"name":"Site inspection","status":"to_do","priority":"high","description":"Check the site."}}',
          200,
        );
      },
    );
    await tester.pumpWidget(BeemViewApp(authController: auth));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Switch to dark mode'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Interview project'));
    await tester.pumpAndSettle();
    expect(find.byType(ProjectTasksScreen), findsOneWidget);
    expect(brightness(tester), Brightness.dark);
    await tester.enterText(find.byType(TextField), 'inspection');
    await tester.tap(find.byTooltip('Filter: To do'));
    await tester.pumpAndSettle();
    final taskMaterial = tester.widget<Material>(
      find
          .descendant(
            of: find.byType(TaskCard),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(taskMaterial.color, AppColors.dark.surface);
    await tester.tap(find.text('Site inspection'));
    await tester.pumpAndSettle();
    expect(find.byType(TaskDetailsScreen), findsOneWidget);
    expect(brightness(tester), Brightness.dark);
    await tester.tap(find.text('Update status'));
    await tester.pumpAndSettle();
    expect(find.byType(UpdateStatusScreen), findsOneWidget);
    expect(brightness(tester), Brightness.dark);
    await tester.ensureVisible(
      find.byKey(const ValueKey('status-in_progress')),
    );
    await tester.tap(find.byKey(const ValueKey('status-in_progress')));
    await tester.ensureVisible(find.byKey(const ValueKey('status-note')));
    await tester.enterText(
      find.byKey(const ValueKey('status-note')),
      'Keep this draft',
    );
    await tester.tap(find.byTooltip('Switch to light mode'));
    await tester.pumpAndSettle();
    expect(brightness(tester), Brightness.light);
    expect(find.text('Keep this draft'), findsOneWidget);
    await tester.tap(find.byTooltip('Switch to dark mode'));
    await tester.pumpAndSettle();
    expect(find.text('Keep this draft'), findsOneWidget);
    final choices = tester.widgetList<Material>(
      find.ancestor(
        of: find.byKey(const ValueKey('status-in_progress')),
        matching: find.byType(Material),
      ),
    );
    expect(choices.first.color, AppColors.dark.selected);
    final otherChoices = tester.widgetList<Material>(
      find.ancestor(
        of: find.byKey(const ValueKey('status-to_do')),
        matching: find.byType(Material),
      ),
    );
    expect(otherChoices.first.color, AppColors.dark.surface);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.byType(ProjectTasksScreen), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'inspection',
    );
    expect(
      tester
          .widget<ChoiceChip>(
            find.ancestor(
              of: find.text('To do'),
              matching: find.byType(ChoiceChip),
            ),
          )
          .selected,
      isTrue,
    );
    expect(taskReads, 1);
    expect(detailReads, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('sign out clears the token and preserves the theme preference', (
    tester,
  ) async {
    final auth = createController(
      (_) async => http.Response('{"data":[],"total":0}', 200),
    );
    await tester.pumpWidget(BeemViewApp(authController: auth));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Switch to dark mode'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);
    expect(brightness(tester), Brightness.dark);
    expect(await auth.store.readToken(), isNull);
    expect(await const ThemeStore().readMode(), ThemeMode.dark);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
