import 'package:flutter_test/flutter_test.dart';
import 'package:roomeez/core/utils/dates.dart';
import 'package:roomeez/data/models/models.dart';
import 'package:roomeez/data/services/balance_calculator.dart';

Expense _expense(
  String id, {
  required int amount,
  required List<String> split,
  required DateTime date,
  String by = 'a',
  String? paidBy,
  PaymentSource source = PaymentSource.personal,
  bool voided = false,
}) {
  return Expense(
    id: id,
    groupId: 'g',
    title: id,
    date: date,
    category: ExpenseCategory.other,
    items: const [],
    quickAmountPaisa: amount,
    createdByUserId: by,
    paidByUserId: source == PaymentSource.groupFund ? null : (paidBy ?? by),
    paymentSource: source,
    splitAmongUserIds: split,
    status: voided ? ExpenseStatus.voided : ExpenseStatus.active,
    createdAt: date,
  );
}

GroupMember _member(String userId, DateTime start) => GroupMember(
  id: 'm_$userId',
  groupId: 'g',
  userId: userId,
  displayName: userId.toUpperCase(),
  phone: '+92300000000$userId',
  role: MemberRole.member,
  status: MemberStatus.active,
  startDate: start,
);

Contribution _contribution(String userId, int amount, DateTime date) => Contribution(
  id: 'c_$userId',
  groupId: 'g',
  memberUserId: userId,
  amountPaisa: amount,
  date: date,
  type: ContributionType.initial,
  recordedByUserId: userId,
  createdAt: date,
);

void main() {
  final oct1 = DateTime(2026, 10, 1);
  final oct16 = DateTime(2026, 10, 16);

  test('equal split distributes leftover paisa so shares add up exactly', () {
    final shares = BalanceCalculator.splitEqually(1000, ['c', 'a', 'b']);
    expect(shares.values.fold(0, (a, b) => a + b), 1000);
    expect(shares, {'a': 334, 'b': 333, 'c': 333});
  });

  test('member balances net out to the remaining group fund', () {
    final members = [_member('a', oct1), _member('b', oct1), _member('c', oct1)];
    final contributions = [
      _contribution('a', 500000, oct1),
      _contribution('b', 500000, oct1),
      _contribution('c', 500000, oct1),
    ];
    final expenses = [
      _expense('e1', amount: 60000, split: ['a', 'b', 'c'], date: oct1, by: 'a'),
      _expense('e2', amount: 90000, split: ['a', 'b', 'c'], date: oct1, source: PaymentSource.groupFund),
    ];
    final summary = BalanceCalculator.summarize(members: members, expenses: expenses, contributions: contributions);
    final fund = BalanceCalculator.fundStatus(expenses: expenses, contributions: contributions);

    expect(summary.totalExpensesPaisa, 150000);
    expect(summary.paidPersonallyPaisa, 60000);
    expect(summary.paidFromFundPaisa, 90000);
    expect(fund.remainingPaisa, 1500000 - 90000);
    final netTotal = summary.balances.fold(0, (sum, b) => sum + b.netPaisa);
    expect(netTotal, fund.remainingPaisa);
    // A paid 600 personally, contributed 5,000 and owes a 500 share.
    expect(summary.balanceOf('a')!.netPaisa, 500000 + 60000 - 50000);
  });

  test('voided expenses are excluded from totals and balances', () {
    final members = [_member('a', oct1), _member('b', oct1)];
    final expenses = [
      _expense('real', amount: 40000, split: ['a', 'b'], date: oct1),
      _expense('dup', amount: 40000, split: ['a', 'b'], date: oct1, voided: true),
    ];
    final summary = BalanceCalculator.summarize(members: members, expenses: expenses, contributions: const []);
    expect(summary.totalExpensesPaisa, 40000);
    expect(summary.expenseCount, 1);
    expect(summary.voidedCount, 1);
    expect(summary.balanceOf('b')!.sharePaisa, 20000);
  });

  test('a member who joins later does not share earlier expenses', () {
    // A, B and C from Oct 1; D joins Oct 16 (the spec example).
    final members = [_member('a', oct1), _member('b', oct1), _member('c', oct1), _member('d', oct16)];
    final expenses = [
      _expense('early', amount: 90000, split: ['a', 'b', 'c'], date: DateTime(2026, 10, 10)),
      _expense('late', amount: 80000, split: ['a', 'b', 'c', 'd'], date: DateTime(2026, 10, 18)),
    ];
    final firstHalf = BalanceCalculator.summarize(
      members: members,
      expenses: expenses,
      contributions: const [],
      range: DateRange(oct1, DateTime(2026, 10, 15)),
    );
    expect(firstHalf.balanceOf('d')!.sharePaisa, 0);
    expect(firstHalf.balanceOf('a')!.sharePaisa, 30000);

    final secondHalf = BalanceCalculator.summarize(
      members: members,
      expenses: expenses,
      contributions: const [],
      range: DateRange(oct16, DateTime(2026, 10, 31)),
    );
    expect(secondHalf.balanceOf('d')!.sharePaisa, 20000);
  });

  test('the payer gets credit, not the person who added the expense', () {
    final members = [_member('a', oct1), _member('b', oct1)];
    final expenses = [
      _expense('ride', amount: 60000, split: ['a', 'b'], date: oct1, by: 'a', paidBy: 'b'),
    ];
    final summary = BalanceCalculator.summarize(members: members, expenses: expenses, contributions: const []);
    expect(summary.balanceOf('b')!.paidPersonallyPaisa, 60000);
    expect(summary.balanceOf('a')!.paidPersonallyPaisa, 0);
    expect(summary.balanceOf('b')!.netPaisa, 30000);
    expect(summary.balanceOf('a')!.netPaisa, -30000);
  });
}
