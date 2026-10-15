import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Product rule: there is no delete action anywhere in the app, and no delete
/// method for expenses in the data layer. This test scans the source so a
/// regression is caught automatically.
void main() {
  test('no delete actions, icons or swipe-to-dismiss in lib/', () {
    final forbidden = <String, RegExp>{
      'delete method or call': RegExp(r'\bdelete\w*\s*\(', caseSensitive: false),
      'remove-expense method': RegExp(r'\bremoveExpense\w*\s*\(', caseSensitive: false),
      'delete icon': RegExp(r'Icons\.delete|CupertinoIcons\.delete|Icons\.remove_circle'),
      'swipe to dismiss': RegExp(r'\bDismissible\b|onDismissed|DismissDirection'),
      'Delete label': RegExp(r'''['"][^'"]*\bDelete\b[^'"]*['"]'''),
    };

    final violations = <String>[];
    final files = Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));
    for (final file in files) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (line.trimLeft().startsWith('//')) continue;
        forbidden.forEach((what, pattern) {
          if (pattern.hasMatch(line)) violations.add('${file.path}:${i + 1} ($what): ${line.trim()}');
        });
      }
    }
    expect(violations, isEmpty, reason: violations.join('\n'));
  });
}
