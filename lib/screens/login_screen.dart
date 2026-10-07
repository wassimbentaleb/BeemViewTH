import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/auth_controller.dart';
import '../core/app_theme.dart';
import '../core/validators.dart';
import '../widgets/brand_logo.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.controller});

  final AuthController controller;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Les champs et la visibilite du password sont des etats locaux du formulaire.
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _hidePassword = true;

  @override
  void dispose() {
    // Libere les champs quand on quitte le Login.
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // La validation locale evite un appel API inutile ou un double envoi.
    if (widget.controller.isLoading || !_formKey.currentState!.validate()) {
      return;
    }
    FocusScope.of(context).unfocus();
    // Le controller traite la requete, les erreurs et le token.
    final success = await widget.controller.signIn(
      email: _emailController.text,
      password: _passwordController.text,
    );
    // Le gestionnaire de mots de passe recoit uniquement une connexion reussie.
    if (success) TextInput.finishAutofillContext(shouldSave: true);
  }

  @override
  Widget build(BuildContext context) {
    // Le scroll et SafeArea gardent les champs accessibles avec le clavier.
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFF0FAFE),
              AppColors.background,
              AppColors.background,
            ],
            stops: [0, 0.4, 1],
          ),
        ),
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
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SizedBox(
                                height: constraints.maxHeight > 650 ? 80 : 32,
                              ),
                              _buildHeader(),
                              const SizedBox(height: 28),
                              _buildForm(),
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
    );
  }

  Widget _buildHeader() {
    // Logo et texte d'accueil reprennent la maquette fournie.
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(child: BrandLogo(large: true)),
        SizedBox(height: 36),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome back',
                style: TextStyle(
                  fontSize: 42,
                  height: 1.2,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.8,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Sign in to manage your projects',
                style: TextStyle(
                  fontSize: 18,
                  height: 1.5,
                  color: AppColors.muted,
                  letterSpacing: -0.6,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildForm() {
    // La carte regroupe les champs, l'erreur serveur et le bouton de connexion.
    const labelStyle = TextStyle(fontSize: 17, fontWeight: FontWeight.w700);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0807182F),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
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
                // L'email se valide en quittant le champ ou via Sign in, pas a chaque lettre.
                enabled: !widget.controller.isLoading,
                controller: _emailController,
                autovalidateMode: AutovalidateMode.onUnfocus,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.username],
                autocorrect: false,
                textCapitalization: TextCapitalization.none,
                validator: Validators.email,
                decoration: const InputDecoration(
                  hintText: 'candidate@example.com',
                  prefixIcon: Icon(Icons.mail_outline_rounded, size: 24),
                ),
              ),
              const SizedBox(height: 24),
              const Text('Password', style: labelStyle),
              const SizedBox(height: 8),
              TextFormField(
                // Meme validation apres sortie; la saisie exacte du password est conservee.
                enabled: !widget.controller.isLoading,
                controller: _passwordController,
                autovalidateMode: AutovalidateMode.onUnfocus,
                obscureText: _hidePassword,
                autocorrect: false,
                enableSuggestions: false,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                validator: Validators.password,
                onFieldSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  hintText: 'Enter your password',
                  prefixIcon: const Icon(Icons.lock_outline_rounded, size: 24),
                  suffixIcon: IconButton(
                    tooltip: _hidePassword ? 'Show password' : 'Hide password',
                    onPressed: widget.controller.isLoading
                        ? null
                        : () => setState(() => _hidePassword = !_hidePassword),
                    icon: Icon(
                      _hidePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 24,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Une erreur API reste dans le formulaire sans vider les champs.
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
              FilledButton(
                // Le spinner et le bouton desactive empechent les doubles clics.
                onPressed: widget.controller.isLoading ? null : _submit,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (widget.controller.isLoading)
                      const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else ...[
                      const Text('Sign in'),
                      const SizedBox(width: 12),
                      const Icon(Icons.arrow_forward_rounded, size: 24),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    // Signature de marque en bas de l'ecran.
    return const Padding(
      padding: EdgeInsets.only(top: 40, bottom: 32),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: 'Beem View '),
            TextSpan(
              text: '360',
              style: TextStyle(color: AppColors.amber),
            ),
          ],
        ),
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.muted,
        ),
      ),
    );
  }
}
