import 'package:beemview/models/task_details.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every returned comment is sorted by timestamp rather than array order or ID', () {
    // L'ID le plus grand et le premier element ne sont pas forcement les plus recents.
    final details = TaskDetails.fromJson({
      'id': 501,
      'Comments': [
        {
          'id': 90,
          'content': 'Older',
          'created_at': '2026-10-05T09:00:00Z',
          'user': {'name': 'First'},
        },
        {
          'id': 77,
          'content': 'Latest',
          'created_at': '2026-10-06T09:00:00Z',
          'user': {'full_name': ' Candidate '},
        },
        {'id': 91, 'content': 'Middle', 'created_at': '2026-10-06T08:00:00Z'},
        {'id': 99, 'content': 'Undated', 'created_at': null},
      ],
    });
    expect(details.commentsNewestFirst.map((comment) => comment.id), [
      77,
      91,
      90,
      99,
    ]);
    expect(details.commentsNewestFirst.first.authorName, 'Candidate');
    expect(details.commentsNewestFirst.first.content, 'Latest');
    expect(details.comments.map((comment) => comment.id), [90, 77, 91, 99]);
    expect(() => details.commentsNewestFirst.clear(), throwsUnsupportedError);
    expect(() => details.comments.clear(), throwsUnsupportedError);
  });

  test('missing comment metadata stays readable and undated comments keep returned order', () {
    // Sans timestamp on ne peut pas inventer un ordre chronologique.
    final details = TaskDetails.fromJson({
      'id': 501,
      'Comments': [
        {'id': 77, 'content': ' ', 'created_at': 'invalid', 'user': null},
        {'id': 78, 'content': 'Another undated comment'},
      ],
    });
    expect(details.commentsNewestFirst.map((comment) => comment.id), [77, 78]);
    expect(details.commentsNewestFirst.first.authorName, 'Unknown user');
    expect(
      details.commentsNewestFirst.first.content,
      'No comment text available.',
    );
    expect(details.commentsNewestFirst.first.createdAt, isNull);
    expect(
      TaskDetails.fromJson({'id': 501, 'Comments': null}).commentsNewestFirst,
      isEmpty,
    );
    for (final comments in [
      {},
      [null],
      [
        {'id': 0},
      ],
    ]) {
      expect(
        () => TaskDetails.fromJson({'id': 501, 'Comments': comments}),
        throwsFormatException,
      );
    }
  });

  test('equal instants and undated comments retain their returned order', () {
    // Deux fuseaux peuvent representer le meme instant; les IDs ne donnent pas la date.
    final details = TaskDetails.fromJson({
      'id': 501,
      'Comments': [
        {'id': 100, 'content': 'Undated first'},
        {
          'id': 2,
          'content': 'Same instant first',
          'created_at': '2026-10-07T09:00:00Z',
        },
        {
          'id': 3,
          'content': 'Same instant second',
          'created_at': '2026-10-07T11:00:00+02:00',
        },
        {'id': 101, 'content': 'Undated second', 'created_at': 'invalid'},
        {'id': 1, 'content': 'Newest', 'created_at': '2026-10-07T10:00:00Z'},
      ],
    });
    expect(details.commentsNewestFirst.map((comment) => comment.id), [
      1,
      2,
      3,
      100,
      101,
    ]);
  });

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
