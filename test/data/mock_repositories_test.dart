import 'package:flutter_test/flutter_test.dart';
import 'package:roomeez/core/errors/app_exception.dart';
import 'package:roomeez/data/mock/mock_auth_repository.dart';
import 'package:roomeez/data/mock/mock_contribution_repository.dart';
import 'package:roomeez/data/mock/mock_expense_repository.dart';
import 'package:roomeez/data/mock/mock_group_repository.dart';
import 'package:roomeez/data/mock/mock_store.dart';
import 'package:roomeez/data/models/models.dart';
import 'package:roomeez/data/repositories/group_repository.dart';
import 'package:roomeez/data/services/balance_calculator.dart';

import '../test_helpers.dart';

const apt = 'g_apartment';

ExpenseDraft _draft({
  String title = 'Test groceries',
  int amount = 50000,
  List<String> split = const ['u_ali', 'u_hamza', 'u_usman'],
  String paidBy = 'u_ali',
  DateTime? date,
}) {
  return ExpenseDraft(
    title: title,
    date: date ?? testNow,
    category: ExpenseCategory.groceries,
    items: const [],
    quickAmountPaisa: amount,
    paidByUserId: paidBy,
    paymentSource: PaymentSource.personal,
    splitAmongUserIds: split,
  );
}

void main() {
  late MockStore store;
  late MockExpenseRepository expenses;
  late MockGroupRepository groups;

  setUp(() {
    store = seededStore();
    expenses = MockExpenseRepository(store);
    groups = MockGroupRepository(store);
  });

  group('expense ownership', () {
    test('records the actor as the immutable creator', () async {
      final e = await expenses.addExpense(
        actorUserId: 'u_usman',
        groupId: apt,
        draft: _draft(paidBy: 'u_hamza'),
      );
      expect(e.createdByUserId, 'u_usman');
      expect(e.paidByUserId, 'u_hamza');
    });

    test('the creator can correct their expense (PKR 500 -> 600)', () async {
      final e = await expenses.addExpense(actorUserId: 'u_hamza', groupId: apt, draft: _draft(amount: 50000));
      final updated = await expenses.updateExpense(
        actorUserId: 'u_hamza',
        expenseId: e.id,
        draft: _draft(amount: 60000),
      );
      expect(updated.totalPaisa, 60000);
      expect(updated.createdByUserId, 'u_hamza');
      expect(updated.isEdited, isTrue);
    });

    test('other members cannot edit someone else\'s expense', () async {
      final e = await expenses.addExpense(actorUserId: 'u_hamza', groupId: apt, draft: _draft());
      await expectLater(
        expenses.updateExpense(actorUserId: 'u_usman', expenseId: e.id, draft: _draft(amount: 1)),
        throwsA(isA<PermissionDeniedException>()),
      );
    });

    test('the group manager cannot edit someone else\'s expense either', () async {
      // Ali manages the apartment group.
      final e = await expenses.addExpense(actorUserId: 'u_hamza', groupId: apt, draft: _draft());
      await expectLater(
        expenses.updateExpense(actorUserId: 'u_ali', expenseId: e.id, draft: _draft(amount: 1)),
        throwsA(isA<PermissionDeniedException>()),
      );
      await expectLater(
        expenses.voidExpense(actorUserId: 'u_ali', expenseId: e.id, reason: 'mine now'),
        throwsA(isA<PermissionDeniedException>()),
      );
    });

    test('a removed creator keeps their records but can no longer edit them', () async {
      final e = await expenses.addExpense(actorUserId: 'u_usman', groupId: apt, draft: _draft());
      await groups.removeMember(actorUserId: 'u_ali', groupId: apt, memberId: 'm_${apt}_u_usman');

      expect(store.expenses[e.id], isNotNull);
      expect(store.expenses[e.id]!.createdByUserId, 'u_usman');
      await expectLater(
        expenses.updateExpense(actorUserId: 'u_usman', expenseId: e.id, draft: _draft(amount: 1)),
        throwsA(isA<PermissionDeniedException>()),
      );
      // Ownership is not transferred to the manager.
      await expectLater(
        expenses.updateExpense(actorUserId: 'u_ali', expenseId: e.id, draft: _draft(amount: 1)),
        throwsA(isA<PermissionDeniedException>()),
      );
    });

    test('voiding keeps the record but removes it from totals', () async {
      final before = store.expenses.length;
      final e = await expenses.addExpense(actorUserId: 'u_ali', groupId: apt, draft: _draft(amount: 70000));
      await expenses.voidExpense(actorUserId: 'u_ali', expenseId: e.id, reason: 'Entered twice');

      expect(store.expenses.length, before + 1);
      expect(store.expenses[e.id]!.isVoided, isTrue);
      final summary = BalanceCalculator.summarize(
        members: store.membersOf(apt),
        expenses: [store.expenses[e.id]!],
        contributions: const [],
      );
      expect(summary.totalExpensesPaisa, 0);
      // A voided expense can't be edited afterwards.
      await expectLater(
        expenses.updateExpense(actorUserId: 'u_ali', expenseId: e.id, draft: _draft()),
        throwsA(isA<PermissionDeniedException>()),
      );
    });

    test('members who were not in the group on the date cannot share an expense', () async {
      // Bilal joined 6 days before testNow.
      await expectLater(
        expenses.addExpense(
          actorUserId: 'u_ali',
          groupId: apt,
          draft: _draft(split: ['u_ali', 'u_bilal'], date: DateTime(2026, 10, 1)),
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('invalid amounts are rejected', () async {
      await expectLater(
        expenses.addExpense(actorUserId: 'u_ali', groupId: apt, draft: _draft(amount: 0)),
        throwsA(isA<ValidationException>()),
      );
    });
  });

  group('group access', () {
    test('non-members cannot see a group\'s expenses', () async {
      // Zain has only requested to join.
      await expectLater(
        expenses.watchExpenses(groupId: apt, viewerUserId: 'u_zain').first,
        throwsA(isA<PermissionDeniedException>()),
      );
    });

    test('former members lose access', () async {
      await expectLater(
        expenses.watchExpenses(groupId: apt, viewerUserId: 'u_fahad').first,
        throwsA(isA<PermissionDeniedException>()),
      );
    });

    test('any member can approve a join request', () async {
      await groups.approveJoinRequest(actorUserId: 'u_usman', requestId: 'r_zain');
      final list = await expenses.watchExpenses(groupId: apt, viewerUserId: 'u_zain').first;
      expect(list, isNotEmpty);
      expect(store.activeMembership(apt, 'u_zain')!.startDate, DateTime(2026, 10, 15));
    });

    test('only the manager can remove members', () async {
      await expectLater(
        groups.removeMember(actorUserId: 'u_hamza', groupId: apt, memberId: 'm_${apt}_u_usman'),
        throwsA(isA<PermissionDeniedException>()),
      );
    });

    test('any member can add a member', () async {
      final m = await groups.addMember(
        actorUserId: 'u_bilal',
        groupId: apt,
        member: const NewMemberInput(name: 'Saad Ali', phone: '+923009998887'),
        startDate: testNow,
      );
      expect(m.isActive, isTrue);
      expect(store.users[m.userId]!.isRegistered, isFalse);
    });

    test('the manager role passes on when the manager leaves', () async {
      final result = await groups.leaveGroup(actorUserId: 'u_ali', groupId: apt);
      expect(result.newManagerName, isNotNull);
      final managers = store.membersOf(apt).where((m) => m.isManager).toList();
      expect(managers, hasLength(1));
      expect(managers.single.userId, isNot('u_ali'));
    });

    test('creating a group makes the creator manager and records contributions', () async {
      final group = await groups.createGroup(
        actorUserId: 'u_bilal',
        input: const NewGroupInput(
          name: 'Model Town Flat',
          members: [NewMemberInput(name: 'Omar Farooq', phone: '+923004445556')],
          initialContributionsByPhone: {'+923451234567': 500000, '+923004445556': 500000},
        ),
      );
      expect(group.code, matches(RegExp(r'^[A-Z0-9]{6}$')));
      expect(store.activeMembership(group.id, 'u_bilal')!.isManager, isTrue);
      final contributions = await MockContributionRepository(
        store,
      ).watchContributions(groupId: group.id, viewerUserId: 'u_bilal').first;
      expect(contributions.fold(0, (sum, c) => sum + c.amountPaisa), 1000000);
    });
  });

  group('auth', () {
    test('signing up with a number a member added links the account', () async {
      final auth = MockAuthRepository(store);
      await auth.requestCode(phone: '+923071234567', isSignUp: true);
      final user = await auth.verifyCode(phone: '+923071234567', code: '123456', isSignUp: true);
      expect(user.id, 'u_danish');
      expect(user.isRegistered, isTrue);
      final groupsForDanish = await groups.watchGroupsForUser(user.id).first;
      expect(groupsForDanish.map((g) => g.id), contains('g_hostel'));
    });

    test('a wrong code is rejected', () async {
      final auth = MockAuthRepository(store);
      await expectLater(
        auth.verifyCode(phone: '+923001234567', code: '000000', isSignUp: false),
        throwsA(isA<ValidationException>()),
      );
    });
  });
}
