import '../../core/utils/dates.dart';
import '../models/group_snapshot.dart';
import '../models/models.dart';
import 'balance_calculator.dart';

class ReportDay {
  const ReportDay({required this.date, required this.expenses});

  final DateTime date;
  final List<Expense> expenses;

  int get totalPaisa => expenses.fold(0, (sum, e) => sum + e.totalPaisa);
}

/// Everything a period report shows, computed once and used by both the
/// on-screen preview and the PDF so they never disagree.
class ReportData {
  const ReportData({
    required this.snapshot,
    required this.range,
    required this.generatedAt,
    required this.days,
    required this.summary,
    required this.memberBalances,
    required this.fundAsOfEnd,
    required this.contributions,
    required this.members,
  });

  final GroupSnapshot snapshot;
  final DateRange range;
  final DateTime generatedAt;

  /// Days with at least one non-voided expense, oldest first.
  final List<ReportDay> days;
  final FinancialSummary summary;

  /// Balances for people who were members during the period.
  final List<MemberBalance> memberBalances;
  final FundStatus fundAsOfEnd;

  /// Contributions recorded within the period.
  final List<Contribution> contributions;

  /// Memberships that overlap the period.
  final List<GroupMember> members;

  Group get group => snapshot.group;

  String nameOf(String? userId) => snapshot.nameOf(userId);

  bool get isEmpty => days.isEmpty && contributions.isEmpty;
}

abstract final class ReportBuilder {
  static ReportData build(GroupSnapshot snapshot, DateRange range, {DateTime? now}) {
    final expenses = snapshot.expenses.where((e) => !e.isVoided && range.contains(e.date)).toList()
      ..sort((a, b) {
        final byDate = a.date.compareTo(b.date);
        return byDate != 0 ? byDate : a.createdAt.compareTo(b.createdAt);
      });

    final days = <ReportDay>[];
    for (final e in expenses) {
      final day = dateOnly(e.date);
      if (days.isEmpty || days.last.date != day) {
        days.add(ReportDay(date: day, expenses: [e]));
      } else {
        days.last.expenses.add(e);
      }
    }

    final summary = BalanceCalculator.summarize(
      members: snapshot.members,
      expenses: snapshot.expenses,
      contributions: snapshot.contributions,
      range: range,
    );
    final members = snapshot.membersOverlapping(range);
    final memberIds = members.map((m) => m.userId).toSet();

    return ReportData(
      snapshot: snapshot,
      range: range,
      generatedAt: now ?? DateTime.now(),
      days: days,
      summary: summary,
      memberBalances: summary.balances
          .where((b) => memberIds.contains(b.userId) || b.paidInPaisa != 0 || b.sharePaisa != 0)
          .toList(),
      fundAsOfEnd: BalanceCalculator.fundStatus(
        expenses: snapshot.expenses,
        contributions: snapshot.contributions,
        asOf: range.end,
      ),
      contributions: snapshot.contributions.where((c) => range.contains(c.date)).toList()
        ..sort((a, b) => a.date.compareTo(b.date)),
      members: members,
    );
  }
}
