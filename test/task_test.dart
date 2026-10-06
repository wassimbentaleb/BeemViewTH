import 'package:beemview/models/task.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('list and detail fields normalize to the same task data', () {
    // Les deux enveloppes exposent des noms de champs et une casse differents.
    final list = Task.fromJson({
      'id': 501,
      'name': ' Site inspection ',
      'status': 'to_do',
      'priority': 'High',
      'dueDate': '2026-10-09T00:00:00Z',
      'startedDate': '2026-10-06T09:00:00Z',
      'progress': 75,
    });
    final detail = Task.fromJson({
      'id': 501,
      'name': 'Site inspection',
      'status': 'to_do',
      'priority': 'high',
      'due_date': '2026-10-09T00:00:00Z',
      'start_date': '2026-10-06T09:00:00Z',
    });
    expect(list.name, detail.name);
    expect(list.priority, detail.priority);
    expect(list.dueDate, detail.dueDate);
    expect(list.startedDate, detail.startedDate);
    expect(list.statusLabel, 'To do');
    expect(list.priorityLabel, 'High');
  });

  test('optional data stays nullable and unfamiliar values stay visible', () {
    // Une task incomplete ne doit pas faire crasher toute la liste.
    final task = Task.fromJson({
      'id': 502,
      'name': ' ',
      'status': 'awaiting_inspection',
      'priority': null,
      'dueDate': 'not a date',
      'startedDate': null,
    });
    expect(task.name, 'Untitled task');
    expect(task.dueDate, isNull);
    expect(task.startedDate, isNull);
    expect(task.priorityLabel, 'No priority');
    expect(task.statusLabel, 'Awaiting inspection');
    expect(Task.fromJson({'id': 503}).statusLabel, 'Unknown');
    for (final id in [null, 0, -1, '501']) {
      expect(() => Task.fromJson({'id': id}), throwsFormatException);
    }
  });
}
