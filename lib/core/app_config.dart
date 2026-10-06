// Configuration de l'API, separee des champs email et mot de passe.
class AppConfig {
  const AppConfig({
    this.apiOrigin = 'https://beemview.com',
    required this.subdomain,
  });

  factory AppConfig.fromEnvironment() {
    // Ces valeurs viennent des --dart-define ou du fichier de configuration local.
    return const AppConfig(
      apiOrigin: String.fromEnvironment(
        'API_ORIGIN',
        defaultValue: 'https://beemview.com',
      ),
      subdomain: String.fromEnvironment('TENANT_SUBDOMAIN'),
    );
  }

  final String apiOrigin;
  final String subdomain;

  // Transforme l'origine configuree en adresse utilisable pour les requetes.
  Uri get origin => Uri.parse(apiOrigin.trim());
}
