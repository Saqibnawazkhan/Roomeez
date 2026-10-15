import '../../core/utils/dates.dart';
import '../models/models.dart';

/// One member's position.
///
/// `net = contributed + paidPersonally - share`. Positive means the member has
/// put in more than their share; negative means they owe the group.
/// Across all members, the nets add up to the cash left in the group fund.
class MemberBalance {
  const MemberBalance({
    required this.userId,
    required this.name,
    required this.contributedPaisa,
    required this.paidPersonallyPaisa,
    required this.sharePaisa,
  });

  final String userId;
  final String name;
  final int contributedPaisa;
  final int paidPersonallyPaisa;
  final int sharePaisa;

  int get paidInPaisa => contributedPaisa + paidPersonallyPaisa;
  int get netPaisa => paidInPaisa - sharePaisa;
}

class FundStatus {
  const FundStatus({required this.contributedPaisa, required this.spentPaisa});

  final int contributedPaisa;
  final int spentPaisa;

  int get remainingPaisa => contributedPaisa - spentPaisa;
  bool get hasFund => contributedPaisa > 0 || spentPaisa > 0;
}

class FinancialSummary {
  const FinancialSummary({
    required this.expenseCount,
    required this.voidedCount,
    required this.totalExpensesPaisa,
    required this.paidPersonallyPaisa,
    required this.paidFromFundPaisa,
    required this.contributionsPaisa,
    required this.byCategory,
    required this.balances,
  });

  final int expenseCount;
  final int voidedCount;
  final int totalExpensesPaisa;
  final int paidPersonallyPaisa;
  final int paidFromFundPaisa;
  final int contributionsPaisa;

  /// Categories with spending, largest first.
  final List<MapEntry<ExpenseCategory, int>> byCategory;
  final List<MemberBalance> balances;

  MemberBalance? balanceOf(String userId) {
    for (final b in balances) {
      if (b.userId == userId) return b;
    }
    return null;
  }
}

/// Simple equal-split balances. Voided expenses are always excluded.
abstract final class BalanceCalculator {
  /// Splits [expense] equally between its participants. Any leftover paisa
  /// go one each to the first participants (ordered by id), so the shares
  /// always add up exactly to the total.
  static Map<String, int> shares(Expense expense) => splitEqually(expense.totalPaisa, expense.splitAmongUserIds);

  static Map<String, int> splitEqually(int total, Iterable<String> userIds) {
    final participants = userIds.toSet().toList()..sort();
    if (participants.isEmpty) return const {};
    final base = total ~/ participants.length;
    final remainder = total % participants.length;
    return {for (final (i, userId) in participants.indexed) userId: base + (i < remainder ? 1 : 0)};
  }

  /// Totals and per-member balances for expenses and contributions in [range]
  /// (`null` = all time).
  static FinancialSummary summarize({
    required List<GroupMember> members,
    required List<Expense> expenses,
    required List<Contribution> contributions,
    DateRange? range,
  }) {
    bool inRange(DateTime d) => range == null || range.contains(d);

    final contributed = <String, int>{};
    final paid = <String, int>{};
    final share = <String, int>{};
    final byCategory = <ExpenseCategory, int>{};
    var count = 0;
    var voided = 0;
    var total = 0;
    var personal = 0;
    var fund = 0;
    var contributionsTotal = 0;

    for (final e in expenses) {
      if (!inRange(e.date)) continue;
      if (e.isVoided) {
        voided++;
        continue;
      }
      count++;
      final amount = e.totalPaisa;
      total += amount;
      byCategory[e.category] = (byCategory[e.category] ?? 0) + amount;
      if (e.paymentSource == PaymentSource.groupFund) {
        fund += amount;
      } else {
        personal += amount;
        final payer = e.paidByUserId ?? e.createdByUserId;
        paid[payer] = (paid[payer] ?? 0) + amount;
      }
      shares(e).forEach((userId, value) => share[userId] = (share[userId] ?? 0) + value);
    }

    for (final c in contributions) {
      if (!inRange(c.date)) continue;
      contributionsTotal += c.amountPaisa;
      contributed[c.memberUserId] = (contributed[c.memberUserId] ?? 0) + c.amountPaisa;
    }

    // Order: active members first (as listed), then anyone else with activity.
    final names = <String, String>{};
    final order = <String>[];
    for (final m in [...members.where((m) => m.isActive), ...members.where((m) => !m.isActive)]) {
      if (names.containsKey(m.userId)) continue;
      names[m.userId] = m.displayName;
      if (m.isActive) order.add(m.userId);
    }
    final involved = {...contributed.keys, ...paid.keys, ...share.keys};
    for (final userId in involved) {
      if (!order.contains(userId)) order.add(userId);
    }

    final balances = [
      for (final userId in order)
        MemberBalance(
          userId: userId,
          name: names[userId] ?? 'Former member',
          contributedPaisa: contributed[userId] ?? 0,
          paidPersonallyPaisa: paid[userId] ?? 0,
          sharePaisa: share[userId] ?? 0,
        ),
    ];

    final categories = byCategory.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return FinancialSummary(
      expenseCount: count,
      voidedCount: voided,
      totalExpensesPaisa: total,
      paidPersonallyPaisa: personal,
      paidFromFundPaisa: fund,
      contributionsPaisa: contributionsTotal,
      byCategory: categories,
      balances: balances,
    );
  }

  /// Group fund position up to and including [asOf] (`null` = everything).
  static FundStatus fundStatus({
    required List<Expense> expenses,
    required List<Contribution> contributions,
    DateTime? asOf,
  }) {
    bool counts(DateTime d) => asOf == null || !dateOnly(d).isAfter(dateOnly(asOf));
    final contributed = contributions.where((c) => counts(c.date)).fold(0, (sum, c) => sum + c.amountPaisa);
    final spent = expenses
        .where((e) => !e.isVoided && e.paymentSource == PaymentSource.groupFund && counts(e.date))
        .fold(0, (sum, e) => sum + e.totalPaisa);
    return FundStatus(contributedPaisa: contributed, spentPaisa: spent);
  }
}
