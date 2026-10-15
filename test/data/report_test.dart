import 'package:flutter_test/flutter_test.dart';
import 'package:roomeez/core/utils/dates.dart';
import 'package:roomeez/data/models/group_snapshot.dart';
import 'package:roomeez/data/services/pdf_report_service.dart';
import 'package:roomeez/data/services/report_builder.dart';

import '../test_helpers.dart';

GroupSnapshot _apartment(String viewer) {
  final store = seededStore();
  const id = 'g_apartment';
  return GroupSnapshot(
    group: store.groups[id]!,
    members: store.membersOf(id),
    expenses: store.expenses.values.where((e) => e.groupId == id).toList(),
    contributions: store.contributions.values.where((c) => c.groupId == id).toList(),
    viewerUserId: viewer,
  );
}

void main() {
  test('report lists only non-voided expenses in the period, day by day', () {
    final snapshot = _apartment('u_ali');
    final range = DateRange(DateTime(2026, 10, 1), DateTime(2026, 10, 15));
    final report = ReportBuilder.build(snapshot, range, now: testNow);

    final listed = report.days.expand((d) => d.expenses).toList();
    expect(listed.every((e) => !e.isVoided && range.contains(e.date)), isTrue);
    expect(report.days.map((d) => d.totalPaisa).fold(0, (a, b) => a + b), report.summary.totalExpensesPaisa);
    // The daily list is sorted oldest first.
    for (var i = 1; i < report.days.length; i++) {
      expect(report.days[i].date.isAfter(report.days[i - 1].date), isTrue);
    }
  });

  test('members who joined after the period are not part of it', () {
    final snapshot = _apartment('u_ali');
    // Bilal joined on Oct 9 (6 days before testNow).
    final report = ReportBuilder.build(snapshot, DateRange(DateTime(2026, 9, 10), DateTime(2026, 10, 5)), now: testNow);
    expect(report.members.map((m) => m.userId), isNot(contains('u_bilal')));
    expect(report.members.map((m) => m.userId), contains('u_fahad'));
  });

  test('a PDF is generated on the device', () async {
    final snapshot = _apartment('u_ali');
    final report = ReportBuilder.build(snapshot, DateRange(DateTime(2026, 9, 1), DateTime(2026, 10, 15)), now: testNow);
    const service = PdfReportService();
    final bytes = await service.build(report);
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    expect(bytes.length, greaterThan(2000));
    expect(service.fileName(report), 'roomeez-gulberg-apartment-4b-2026-09-01-to-2026-10-15.pdf');
  });
}
