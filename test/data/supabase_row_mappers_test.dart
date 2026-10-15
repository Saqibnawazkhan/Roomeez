import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:roomeez/core/errors/app_exception.dart';
import 'package:roomeez/data/models/models.dart';
import 'package:roomeez/data/supabase/row_mappers.dart';
import 'package:roomeez/data/supabase/supabase_errors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Rows produced by the real schema (supabase/tests/db.test.mjs writes them).
final Map<String, dynamic> rows =
    jsonDecode(File('test/fixtures/supabase_rows.json').readAsStringSync()) as Map<String, dynamic>;

Map<String, dynamic> row(String name) => rows[name] as Map<String, dynamic>;

void main() {
  test('profile row maps to AppUser', () {
    final user = RowMappers.profile(row('profile'));
    expect(user.name, 'Hamza Khan');
    expect(user.phone, '+923211234567');
    expect(user.isRegistered, isTrue);
    expect(user.hasCompletedProfile, isFalse);
  });

  test('group and member rows map', () {
    final group = RowMappers.group(row('group'));
    expect(group.code, matches(RegExp(r'^[A-Z0-9]{6}$')));
    final member = RowMappers.member(row('member'));
    expect(member.status, MemberStatus.removed);
    expect(member.role, MemberRole.member);
    expect(member.endDate, isNotNull);
    expect(member.startDate, DateTime(member.startDate.year, member.startDate.month, member.startDate.day));
  });

  test('join request row maps', () {
    final request = RowMappers.joinRequest(row('joinRequest'));
    expect(request.status, JoinRequestStatus.approved);
    expect(request.decidedAt, isNotNull);
    expect(request.groupName, 'Gulberg Apartment 4B');
  });

  test('expense row maps, and the app computes the same total as the database', () {
    final expense = RowMappers.expense(row('expense'));
    expect(expense.items, hasLength(2));
    expect(expense.paymentSource, PaymentSource.personal);
    expect(expense.splitAmongUserIds, hasLength(3));
    expect(expense.totalPaisa, RowMappers.integer(row('expense')['total_paisa']));

    final voided = RowMappers.expense(row('voidedExpense'));
    expect(voided.isVoided, isTrue);
    expect(voided.voidReason, 'Entered twice');
    expect(voided.totalPaisa, RowMappers.integer(row('voidedExpense')['total_paisa']));
  });

  test('contribution row maps', () {
    final contribution = RowMappers.contribution(row('contribution'));
    expect(contribution.type, ContributionType.topUp);
    expect(contribution.amountPaisa, 300000);
    expect(contribution.note, 'Joining');
  });

  test('expense payload matches what add_expense expects', () {
    final payload = RowMappers.expensePayload(
      ExpenseDraft(
        title: 'Rent share',
        date: DateTime(2026, 10, 5),
        category: ExpenseCategory.bills,
        items: const [],
        quickAmountPaisa: 450000,
        paymentSource: PaymentSource.groupFund,
        paidByUserId: 'ignored-for-fund',
        splitAmongUserIds: const ['a', 'b'],
      ),
    );
    expect(payload['date'], '2026-10-05');
    expect(payload['category'], 'bills');
    expect(payload['payment_source'], 'group_fund');
    expect(payload['paid_by'], isNull);
    expect(payload['quick_amount_paisa'], 450000);
    expect(payload['items'], isEmpty);
  });

  test('database error codes become app exceptions with their message', () {
    AppException map(String code, String message) =>
        mapSupabaseError(PostgrestException(message: message, code: code));

    expect(map('RZ403', 'Only the person who added this expense can change it.'), isA<PermissionDeniedException>());
    expect(map('RZ404', 'Expense not found.'), isA<NotFoundException>());
    expect(map('RZ409', 'Already a member.'), isA<ConflictException>());
    expect(map('RZ422', 'Add a title for the expense.').message, 'Add a title for the expense.');
    expect(map('42501', 'permission denied for table expenses'), isA<PermissionDeniedException>());
    expect(mapSupabaseError(const AuthException('Signups not allowed for otp')), isA<NotFoundException>());
    expect(mapSupabaseError(const AuthException('Token has expired or is invalid')), isA<ValidationException>());
  });
}
