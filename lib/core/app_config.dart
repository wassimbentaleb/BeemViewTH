import 'api_exception.dart';

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

  Uri get origin {
    // On verifie l'adresse avant d'envoyer une requete.
    final uri = Uri.tryParse(apiOrigin.trim());
    if (uri == null ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty) {
      throw const ApiException('App configuration is incomplete.');
    }
    return uri;
  }
}
