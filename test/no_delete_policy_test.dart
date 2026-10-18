import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Product rule: there is no delete action for records anywhere in the app,
/// and no delete method for expenses in the data layer. This test scans the
/// source so a regression is caught automatically.
///
/// The one exception is deleting your own account, which app stores require.
/// It removes the sign-in and personal details; group records stay.
void main() {
  test('no delete actions, icons or swipe-to-dismiss in lib/', () {
    final forbidden = <String, RegExp>{
      'delete method or call': RegExp(r'\bdelete\w*\s*\(', caseSensitive: false),
      'remove-expense method': RegExp(r'\bremoveExpense\w*\s*\(', caseSensitive: false),
      'delete icon': RegExp(r'Icons\.delete|CupertinoIcons\.delete|Icons\.remove_circle'),
      'swipe to dismiss': RegExp(r'\bDismissible\b|onDismissed|DismissDirection'),
      'Delete label': RegExp(r'''['"][^'"]*\bDelete\b[^'"]*['"]'''),
    };

    final accountDeletion = RegExp(
      r'deleteAccount|delete_my_account|Delete (your )?account|account was deleted|Icons\.delete_forever',
    );

    final violations = <String>[];
    final files = Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));
    for (final file in files) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (line.trimLeft().startsWith('//') || accountDeletion.hasMatch(line)) continue;
        forbidden.forEach((what, pattern) {
          if (pattern.hasMatch(line)) violations.add('${file.path}:${i + 1} ($what): ${line.trim()}');
        });
      }
    }
    expect(violations, isEmpty, reason: violations.join('\n'));
  });
}
