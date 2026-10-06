// Donnees de la liste Tasks, independantes de Flutter et des appels HTTP.
class Task {
  const Task({
    required this.id,
    required this.name,
    required this.status,
    this.priority,
    this.dueDate,
    this.startedDate,
  });

  final int id;
  final String name;
  final String status;
  final String? priority;
  final DateTime? dueDate;
  final DateTime? startedDate;

  // Les cles restent les valeurs API; seuls les labels sont destines a l'ecran.
  static const statusLabels = {
    'to_do': 'To do',
    'in_progress': 'In progress',
    'done': 'Done',
    'on_hold': 'On hold',
    'review': 'Review',
    'changes_requested': 'Changes requested',
    'blocked': 'Blocked',
    'canceled': 'Canceled',
  };

  String get statusLabel => statusLabels[status] ?? _label(status);
  String get priorityLabel =>
      priority == null ? 'No priority' : _label(priority!);

  factory Task.fromJson(Map<String, dynamic> json) {
    // Un ID valide est necessaire pour ouvrir ensuite les details de la bonne task.
    final id = json['id'];
    if (id is! int || id <= 0) {
      throw const FormatException('Invalid task ID.');
    }
    final name = _text(json['name']);
    return Task(
      id: id,
      name: name ?? 'Untitled task',
      status: _text(json['status'])?.toLowerCase() ?? 'unknown',
      // La liste utilise High; les details utilisent high. Le model normalise les deux.
      priority: _text(json['priority'])?.toLowerCase(),
      dueDate: _date(json['dueDate'] ?? json['due_date']),
      startedDate: _date(json['startedDate'] ?? json['start_date']),
    );
  }

  // Les champs facultatifs absents, vides ou invalides restent null.
  static String? _text(dynamic value) {
    if (value is! String || value.trim().isEmpty) return null;
    return value.trim();
  }

  static DateTime? _date(dynamic value) {
    final text = _text(value);
    return text == null ? null : DateTime.tryParse(text);
  }

  // Une valeur inconnue reste lisible plutot que d'etre presentee comme To do.
  static String _label(String value) {
    final text = value.replaceAll('_', ' ');
    return text.isEmpty ? 'Unknown' : text[0].toUpperCase() + text.substring(1);
  }
}
