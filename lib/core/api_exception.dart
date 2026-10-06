// Une erreur lisible pour l'interface, avec son code HTTP quand il existe.
class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  factory ApiException.fromResponse(int statusCode, Map<String, dynamic> data) {
    // On utilise le message du serveur, sans dependre d'un texte exact.
    final error = data['error'];
    final message = data['message'];
    String text;
    if (error is String && error.trim().isNotEmpty) {
      text = error;
    } else if (message is String && message.trim().isNotEmpty) {
      text = message;
    } else {
      // Le serveur peut ne pas renvoyer de message, par exemple en cas de panne.
      text = switch (statusCode) {
        400 => 'Check the information you entered.',
        401 => 'Your session has expired. Please sign in again.',
        403 => 'You do not have access to this resource.',
        404 => 'The requested item could not be found.',
        429 => 'Too many requests. Please try again later.',
        _ => 'The server could not complete the request. Please try again.',
      };
    }

    final details = data['details'];
    // Les erreurs de validation peuvent contenir plusieurs messages de champs.
    if (details is List) {
      final messages = details
          .whereType<Map>()
          .map((detail) => detail['message'])
          .whereType<String>()
          .where((message) => message.trim().isNotEmpty)
          .toSet();
      if (messages.isNotEmpty) {
        text = '$text ${messages.join(' ')}';
      }
    }
    return ApiException(text, statusCode: statusCode);
  }

  @override
  // Afficher l'exception donne le message, sans afficher de donnees de session.
  String toString() => message;
}
