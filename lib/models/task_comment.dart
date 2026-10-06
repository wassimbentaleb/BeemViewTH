// Un commentaire retourne par Details, sans dependance a l'interface.
class TaskComment {
  const TaskComment({
    required this.id,
    required this.content,
    required this.authorName,
    this.createdAt,
  });

  final int id;
  final String content;
  final String authorName;
  final DateTime? createdAt;

  factory TaskComment.fromJson(Map<String, dynamic> json) {
    // L'identifiant du commentaire doit rester valide; auteur et date sont facultatifs.
    final id = json['id'];
    if (id is! int || id <= 0) {
      throw const FormatException('Invalid comment ID.');
    }
    final user = json['user'];
    final author = user is Map<String, dynamic>
        ? _text(user['name']) ?? _text(user['full_name'])
        : null;
    final date = _text(json['created_at']);
    return TaskComment(
      id: id,
      content: _text(json['content']) ?? 'No comment text available.',
      authorName: author ?? 'Unknown user',
      createdAt: date == null ? null : DateTime.tryParse(date),
    );
  }

  static String? _text(dynamic value) {
    // Une information vide ne doit pas devenir un label vide sur la carte.
    if (value is! String || value.trim().isEmpty) return null;
    return value.trim();
  }
}
