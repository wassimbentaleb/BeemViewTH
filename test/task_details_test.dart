import 'package:beemview/models/task_details.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'detail fields reuse task normalization and map project and every assignee',
    () {
      // Verifie les noms exacts de la route Details et plusieurs utilisateurs assignes.
      final details = TaskDetails.fromJson({
        'id': 501,
        'name': 'Inspection',
        'status': 'in_progress',
        'priority': 'high',
        'description': ' Inspect the site. ',
        'start_date': '2026-10-06',
        'due_date': '2026-10-09',
        'created_at': '2026-10-05T09:00:00Z',
        'updated_at': '2026-10-06T10:00:00Z',
        'Project': {'id': 102, 'name': 'Interview project'},
        'Assignees': [
          {'id': 12, 'full_name': 'Candidate'},
          {'id': 13, 'full_name': 'Colleague'},
        ],
        'attachments': [],
        'progress': 80,
      });
      expect(details.task.id, 501);
      expect(details.task.priority, 'high');
      expect(details.task.startedDate, DateTime(2026, 10, 6));
      expect(details.task.dueDate, DateTime(2026, 10, 9));
      expect(details.description, 'Inspect the site.');
      expect(details.project!.id, 102);
      expect(details.assignees.map((a) => a.fullName), [
        'Candidate',
        'Colleague',
      ]);
      expect(details.createdAt!.isUtc, isTrue);
      expect(details.updatedAt, DateTime.utc(2026, 10, 6, 10));
      expect(() => details.assignees.clear(), throwsUnsupportedError);
    },
  );

  test(
    'null optional fields stay empty while malformed associations are rejected',
    () {
      // Absence de description/projet/assignees ne veut pas dire echec de lecture.
      final details = TaskDetails.fromJson({
        'id': 501,
        'description': ' ',
        'Project': null,
        'Assignees': null,
        'due_date': null,
        'created_at': 'invalid',
      });
      expect(details.description, isNull);
      expect(details.project, isNull);
      expect(details.assignees, isEmpty);
      expect(details.createdAt, isNull);
      expect(details.task.dueDate, isNull);
      for (final extra in [
        {'Project': []},
        {
          'Project': {'id': 0},
        },
        {'Assignees': {}},
        {
          'Assignees': [null],
        },
      ]) {
        expect(
          () => TaskDetails.fromJson({'id': 501, ...extra}),
          throwsFormatException,
        );
      }
    },
  );
}
