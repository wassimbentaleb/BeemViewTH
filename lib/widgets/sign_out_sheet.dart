import 'package:flutter/material.dart';

import '../controllers/auth_controller.dart';
import '../core/app_theme.dart';
import '../models/user.dart';
import 'app_motion.dart';

// La confirmation reste dans le Navigator de la session, efface au logout.
Future<void> showSignOutSheet(
  BuildContext context,
  AuthController controller,
) async {
  final user = controller.user;
  if (user == null || controller.isLoading || controller.isRestoring) return;
  final colors = AppColors.of(context);
  final duration = AppMotion.duration(context);
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    // La barriere et Back passent par PopScope; le glissement force un pop.
    enableDrag: false,
    showDragHandle: false,
    backgroundColor: colors.surface,
    barrierColor: colors.shadow.withValues(alpha: 0.42),
    constraints: const BoxConstraints(maxWidth: 440),
    shape: RoundedRectangleBorder(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      side: BorderSide(color: colors.border),
    ),
    clipBehavior: Clip.antiAlias,
    sheetAnimationStyle: AnimationStyle(
      duration: duration,
      reverseDuration: duration,
    ),
    builder: (context) => SignOutSheet(controller: controller, user: user),
  );
}

class SignOutSheet extends StatefulWidget {
  const SignOutSheet({super.key, required this.controller, required this.user});

  final AuthController controller;
  final User user;

  @override
  State<SignOutSheet> createState() => _SignOutSheetState();
}

class _SignOutSheetState extends State<SignOutSheet> {
  bool _attempted = false;

  Future<void> _signOut() async {
    if (widget.controller.isLoading || widget.controller.isRestoring) return;
    setState(() => _attempted = true);
    // Le controller conserve le compte et son token si l'effacement echoue.
    await widget.controller.signOut();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, child) {
      final colors = AppColors.of(context);
      final scheme = Theme.of(context).colorScheme;
      final busy = widget.controller.isLoading || widget.controller.isRestoring;
      final name = widget.user.fullName.trim();
      final email = widget.user.email?.trim();
      final error = _attempted ? widget.controller.error : null;
      return PopScope(
        canPop: !busy,
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: scheme.error.withValues(alpha: 0.09),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(
                      Icons.logout_rounded,
                      color: scheme.error,
                      size: 26,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Semantics(
                  header: true,
                  child: Text(
                    'Sign out?',
                    style: TextStyle(
                      color: colors.text,
                      fontSize: 26,
                      height: 1.2,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'You can sign in again at any time.',
                  style: TextStyle(color: colors.muted, height: 1.5),
                ),
                const SizedBox(height: 24),
                // Le nom et l'email identifient le compte sans afficher de token.
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colors.subtle,
                    border: Border.all(color: colors.border),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      ExcludeSemantics(
                        child: CircleAvatar(
                          radius: 22,
                          backgroundColor: colors.avatar,
                          foregroundColor: colors.avatarText,
                          child: Text(
                            name.isEmpty
                                ? 'U'
                                : name.characters.first.toUpperCase(),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name.isEmpty ? 'User' : name,
                              style: TextStyle(
                                color: colors.text,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (email != null && email.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                email,
                                style: TextStyle(
                                  color: colors.muted,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 16),
                  Semantics(
                    liveRegion: true,
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: scheme.error.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(error, style: TextStyle(color: scheme.error)),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Semantics(
                  liveRegion: true,
                  child: AppPressScale(
                    enabled: !busy,
                    child: FilledButton(
                      key: const ValueKey('confirm-sign-out'),
                      onPressed: busy ? null : _signOut,
                      style: FilledButton.styleFrom(
                        backgroundColor: scheme.error,
                        foregroundColor: scheme.onError,
                        disabledBackgroundColor: scheme.error.withValues(
                          alpha: 0.75,
                        ),
                        disabledForegroundColor: scheme.onError,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (busy) ...[
                            SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: scheme.onError,
                              ),
                            ),
                            const SizedBox(width: 10),
                          ],
                          Flexible(
                            child: Text(
                              busy ? 'Signing out…' : 'Sign out',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                AppPressScale(
                  enabled: !busy,
                  child: TextButton(
                    onPressed: busy
                        ? null
                        : () => Navigator.of(context).maybePop(),
                    style: TextButton.styleFrom(
                      foregroundColor: colors.muted,
                      minimumSize: const Size(double.infinity, 48),
                      textStyle: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
