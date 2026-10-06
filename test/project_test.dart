import 'package:beemview/models/project.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('project mapping tolerates extra fields and a missing display name', () {
    // Les champs supplementaires/null ne doivent pas rendre la liste inutilisable.
    final project = Project.fromJson({
      'id': 101,
      'name': ' Interview Project ',
      'description': null,
      'unknown_field': true,
    });
    expect(project.id, 101);
    expect(project.name, 'Interview Project');
    expect(
      Project.fromJson({'id': 102, 'name': null}).name,
      'Untitled project',
    );
  });

  test('invalid project identifiers are rejected before navigation', () {
    // On ne transforme pas une reponse incorrecte en ID utilisable dans une URL.
    for (final id in [null, 0, -1, '101', 1.5]) {
      expect(
        () => Project.fromJson({'id': id, 'name': 'Project'}),
        throwsFormatException,
      );
    }
  });
}
