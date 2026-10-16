// Writes sample PDF reports for design review.
//
//   flutter test test/screenshots --dart-define=SCREENSHOTS=true
//
// Files are written to test/screenshots/goldens/ (git-ignored). Skipped in
// normal test runs.
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:roomeez/core/utils/dates.dart';
import 'package:roomeez/data/models/group_snapshot.dart';
import 'package:roomeez/data/models/models.dart';
import 'package:roomeez/data/services/pdf_report_service.dart';
import 'package:roomeez/data/services/report_builder.dart';

import '../test_helpers.dart';

const bool _enabled = bool.fromEnvironment('SCREENSHOTS');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final store = seededStore();
  final snapshot = GroupSnapshot(
    group: store.groups['g_apartment']!,
    members: store.membersOf('g_apartment'),
    expenses: store.expenses.values.where((e) => e.groupId == 'g_apartment').toList(),
    contributions: store.contributions.values.where((c) => c.groupId == 'g_apartment').toList(),
    viewerUserId: 'u_ali',
  );

  final ranges = {
    'report_short': DateRange(DateTime(2026, 10, 13), DateTime(2026, 10, 15)),
    'report_month': DateRange(DateTime(2026, 10, 1), DateTime(2026, 10, 15)),
    'report_long': DateRange(DateTime(2026, 8, 1), DateTime(2026, 10, 15)),
  };

  // A crowded group, to check that long periods still fit on one page.
  final busy = _busyGroup(snapshot);
  final cases = {
    for (final MapEntry(key: name, value: range) in ranges.entries) name: (snapshot, range),
    'report_busy_2weeks': (busy, DateRange(DateTime(2026, 10, 1), DateTime(2026, 10, 15))),
    'report_busy_month': (busy, DateRange(DateTime(2026, 9, 16), DateTime(2026, 10, 15))),
    'report_busy_year': (busy, DateRange(DateTime(2026, 1, 1), DateTime(2026, 10, 15))),
  };

  for (final MapEntry(key: name, value: (snapshot, range)) in cases.entries) {
    test(name, () async {
      final report = ReportBuilder.build(snapshot, range, now: testNow);
      final bytes = await const PdfReportService().build(report);
      File('test/screenshots/goldens/$name.pdf')
        ..createSync(recursive: true)
        ..writeAsBytesSync(bytes);
    }, skip: !_enabled);
  }
}

GroupSnapshot _busyGroup(GroupSnapshot base) {
  const names = [
    'Ali Raza',
    'Muhammad Usman Tariq Khan',
    'Hamza',
    'Bilal Ahmed',
    'Fahad Malik',
    'Zain Abbas',
    'Danish Iqbal',
    'Saad',
    'Shehriyar Khan Niazi',
  ];
  final members = [
    for (final (i, name) in names.indexed)
      GroupMember(
        id: 'm$i',
        groupId: 'g_busy',
        userId: 'u$i',
        displayName: name,
        role: i == 0 ? MemberRole.manager : MemberRole.member,
        status: MemberStatus.active,
        startDate: DateTime(2026, 1, 1),
      ),
  ];
  final random = Random(7);
  const titles = [
    'Chai and rusk',
    'Weekly groceries from Imtiaz Super Market',
    'Electricity bill',
    'Pizza night',
    'Rickshaw',
    'Sabzi',
    'Doodh',
  ];
  final expenses = <Expense>[
    for (var i = 0; i < 260; i++)
      Expense(
        id: 'e$i',
        groupId: 'g_busy',
        title: titles[random.nextInt(titles.length)],
        date: DateTime(2026, 10, 15).subtract(Duration(days: (i * 287) ~/ 260)),
        category: ExpenseCategory.values[random.nextInt(ExpenseCategory.values.length)],
        items: const [],
        quickAmountPaisa: (random.nextInt(4000) + 100) * 100,
        createdByUserId: 'u${random.nextInt(names.length)}',
        paidByUserId: 'u${random.nextInt(names.length)}',
        paymentSource: PaymentSource.personal,
        splitAmongUserIds: [for (var m = 0; m < names.length; m++) 'u$m'],
        status: ExpenseStatus.active,
        createdAt: DateTime(2026, 10, 15),
      ),
  ];
  return GroupSnapshot(
    group: base.group,
    members: members,
    expenses: expenses,
    contributions: const [],
    viewerUserId: 'u0',
  );
}
