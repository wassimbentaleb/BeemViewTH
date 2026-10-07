import 'dart:async';

import 'package:flutter/material.dart';

import 'controllers/auth_controller.dart';
import 'controllers/theme_controller.dart';
import 'core/app_config.dart';
import 'core/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/projects_screen.dart';
import 'screens/session_screen.dart';
import 'services/api_client.dart';
import 'services/auth_service.dart';
import 'services/project_service.dart';
import 'services/session_store.dart';
import 'services/task_service.dart';
import 'widgets/theme_toggle_button.dart';

// Assemble les services et choisit l'ecran suivant l'etat de la session.
class BeemViewApp extends StatefulWidget {
  const BeemViewApp({super.key, this.authController, this.themeController});

  // Les tests peuvent fournir un controller avec une API simulee.
  final AuthController? authController;
  final ThemeController? themeController;

  @override
  State<BeemViewApp> createState() => _BeemViewAppState();
}

class _BeemViewAppState extends State<BeemViewApp> {
  late final AuthController _auth;
  late final ThemeController _theme;
  late final ProjectService _projects;
  late final TaskService _tasks;
  ApiClient? _client;

  @override
  void initState() {
    super.initState();
    _theme = widget.themeController ?? ThemeController();
    if (widget.themeController == null) unawaited(_theme.restore());
    // En execution normale, l'app possede une seule session et un seul client.
    if (widget.authController != null) {
      _auth = widget.authController!;
    } else {
      final config = AppConfig.fromEnvironment();
      _client = ApiClient(config: config);
      _auth = AuthController(
        service: AuthService(client: _client!, config: config),
        store: const SessionStore(),
      );
    }
    // Projects partage le client et le token, y compris avec l'API simulee des tests.
    _projects = ProjectService(client: _auth.service.client);
    // Tasks reutilise aussi le token et le traitement commun de l'expiration.
    _tasks = TaskService(client: _auth.service.client);
    // Le controller gere les erreurs; l'ecran attend son resultat.
    unawaited(_auth.restoreSession());
  }

  @override
  void dispose() {
    if (widget.themeController == null) _theme.dispose();
    // L'app libere seulement les dependances qu'elle a creees.
    if (widget.authController == null) {
      _auth.dispose();
      _client?.close();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Chaque changement du controller actualise loading, erreurs et ecran actif.
    return ThemeScope(
      controller: _theme,
      child: ListenableBuilder(
        listenable: Listenable.merge([_auth, _theme]),
        builder: (context, child) {
          final Widget home;
          if (_auth.isRestoring || _auth.restoreFailed) {
            home = SessionScreen(controller: _auth);
          } else if (_auth.user != null) {
            home = ProjectsScreen(
              controller: _auth,
              service: _projects,
              taskService: _tasks,
            );
          } else {
            home = LoginScreen(controller: _auth);
          }
          return MaterialApp(
            // Un changement de compte efface aussi l'historique de navigation.
            key: ValueKey(_auth.user?.id),
            title: 'Beem View 360',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: _theme.mode,
            themeAnimationDuration: const Duration(milliseconds: 240),
            themeAnimationStyle:
                WidgetsBinding
                    .instance
                    .platformDispatcher
                    .accessibilityFeatures
                    .disableAnimations
                ? AnimationStyle.noAnimation
                : null,
            home: home,
          );
        },
      ),
    );
  }
}
