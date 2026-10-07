import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/auth_controller.dart';
import '../core/app_theme.dart';
import '../core/validators.dart';
import '../widgets/app_motion.dart';
import '../widgets/app_surface.dart';
import '../widgets/brand_logo.dart';
import '../widgets/theme_toggle_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.controller});
  final AuthController controller;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Le formulaire garde ses valeurs pendant les animations et le changement de theme.
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _hidePassword = true;
  bool _hasPassword = false;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_passwordChanged);
  }

  void _passwordChanged() {
    final hasPassword = _passwordController.text.isNotEmpty;
    if (hasPassword == _hasPassword) return;
    setState(() {
      _hasPassword = hasPassword;
      // Une nouvelle saisie revient au masquage apres avoir vide le champ.
      if (!hasPassword) _hidePassword = true;
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.removeListener(_passwordChanged);
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // La validation et le verrou existants evitent les requetes invalides ou doubles.
    if (widget.controller.isLoading || !_formKey.currentState!.validate()) {
      return;
    }
    FocusScope.of(context).unfocus();
    final success = await widget.controller.signIn(
      email: _emailController.text,
      password: _passwordController.text,
    );
    if (success) TextInput.finishAutofillContext(shouldSave: true);
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
        statusBarBrightness: dark ? Brightness.dark : Brightness.light,
      ),
      child: Scaffold(
        // Le fond couvre aussi la zone superieure; SafeArea protege les controles.
        body: AppBackdrop(
          login: true,
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                        maxWidth: 440,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const SizedBox(height: 16),
                                const Align(
                                  alignment: Alignment.centerRight,
                                  child: ThemeToggleButton(circular: true),
                                ),
                                SizedBox(
                                  height: constraints.maxHeight > 700 ? 24 : 16,
                                ),
                                AppEntrance(child: _buildHeader()),
                                const SizedBox(height: 24),
                                AppEntrance(order: 2, child: _buildForm()),
                              ],
                            ),
                            _buildFooter(),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      // Le vrai logo est conserve, avec les dimensions de la reference Login.
      const Center(child: BrandLogo(large: true, login: true)),
      const SizedBox(height: 34),
      const Text(
        'Welcome back',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 34,
          height: 1.15,
          fontWeight: FontWeight.w800,
          letterSpacing: -1,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        'Sign in to manage your projects',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 16, height: 1.4, color: _mutedColor),
      ),
    ],
  );

  Color get _mutedColor => Theme.of(context).brightness == Brightness.light
      ? const Color(0xFF637DA3)
      : AppColors.of(context).muted;

  Widget _buildForm() {
    final colors = AppColors.of(context);
    final light = Theme.of(context).brightness == Brightness.light;
    final border = light ? const Color(0xFFDCE7F3) : colors.border;
    const labelStyle = TextStyle(
      fontSize: 14,
      height: 1.3,
      fontWeight: FontWeight.w500,
    );
    const fieldStyle = TextStyle(fontSize: 14, height: 1.35);
    final decoration = InputDecorationTheme(
      isDense: true,
      filled: true,
      fillColor: light ? const Color(0xFFF8FBFE) : colors.surface,
      hintStyle: fieldStyle.copyWith(color: _mutedColor),
      prefixIconColor: light ? const Color(0xFF203D61) : colors.muted,
      suffixIconColor: light ? const Color(0xFF203D61) : colors.muted,
      prefixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      suffixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(11)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide: BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide: BorderSide(color: colors.primary, width: 1.5),
      ),
      errorMaxLines: 2,
    );
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: light ? const Color(0xFFE8F1F8) : colors.border,
        ),
        boxShadow: [
          if (light)
            BoxShadow(
              color: colors.primary.withValues(alpha: 0.065),
              blurRadius: 22,
              offset: const Offset(0, 6),
            ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(inputDecorationTheme: decoration),
        child: AutofillGroup(
          onDisposeAction: AutofillContextAction.cancel,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Email', style: labelStyle),
                const SizedBox(height: 8),
                TextFormField(
                  enabled: !widget.controller.isLoading,
                  controller: _emailController,
                  style: fieldStyle,
                  autovalidateMode: AutovalidateMode.onUnfocus,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.username],
                  autocorrect: false,
                  textCapitalization: TextCapitalization.none,
                  validator: Validators.email,
                  decoration: const InputDecoration(
                    hintText: 'you@example.com',
                    prefixIcon: Icon(Icons.mail_outline_rounded, size: 20),
                  ),
                ),
                const SizedBox(height: 22),
                const Text('Password', style: labelStyle),
                const SizedBox(height: 8),
                TextFormField(
                  enabled: !widget.controller.isLoading,
                  controller: _passwordController,
                  style: fieldStyle,
                  autovalidateMode: AutovalidateMode.onUnfocus,
                  obscureText: _hidePassword,
                  autocorrect: false,
                  enableSuggestions: false,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  validator: Validators.password,
                  onFieldSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(
                      Icons.lock_outline_rounded,
                      size: 20,
                    ),
                    suffixIcon: !_hasPassword
                        ? null
                        : IconButton(
                            tooltip: _hidePassword
                                ? 'Show password'
                                : 'Hide password',
                            constraints: const BoxConstraints.tightFor(
                              width: 44,
                              height: 44,
                            ),
                            padding: EdgeInsets.zero,
                            onPressed: widget.controller.isLoading
                                ? null
                                : () => setState(
                                    () => _hidePassword = !_hidePassword,
                                  ),
                            icon: Icon(
                              _hidePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              size: 20,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 24),
                if (widget.controller.error != null) ...[
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      widget.controller.error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                // Le degrade fait partie du bouton tout en gardant le retour Material.
                AppPressScale(
                  enabled: !widget.controller.isLoading,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: LinearGradient(
                        colors: light
                            ? const [Color(0xFF00A7D3), Color(0xFF00ADD5)]
                            : [colors.primary, colors.primary],
                      ),
                    ),
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        foregroundColor: colors.onPrimary,
                        minimumSize: const Size(double.infinity, 48),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        textStyle: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 16,
                          height: 1.4,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onPressed: widget.controller.isLoading ? null : _submit,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (widget.controller.isLoading)
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: colors.onPrimary,
                              ),
                            )
                          else ...[
                            const Text('Sign in'),
                            const SizedBox(width: 10),
                            const Icon(Icons.arrow_forward_rounded, size: 20),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() => Padding(
    padding: const EdgeInsets.only(top: 40, bottom: 32),
    child: Text(
      'Beem View 360',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 12,
        height: 1.4,
        fontWeight: FontWeight.w500,
        color: _mutedColor,
      ),
    ),
  );
}
