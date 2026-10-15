import '../models/models.dart';

/// Expense records.
///
/// Rules every implementation must enforce (production: Supabase row-level
/// security plus a trigger keeping `created_by` immutable):
/// * Any active member can add an expense and view the group's expenses.
/// * Only the expense's creator, while an active member, can edit or void it.
///   The group manager has no extra rights over other people's expenses.
/// * There is deliberately **no** method to remove an expense. Mistakes are
///   fixed by editing, or by voiding (kept visible, excluded from totals).
abstract interface class ExpenseRepository {
  Stream<List<Expense>> watchExpenses({required String groupId, required String viewerUserId});

  Future<Expense> addExpense({required String actorUserId, required String groupId, required ExpenseDraft draft});

  Future<Expense> updateExpense({required String actorUserId, required String expenseId, required ExpenseDraft draft});

  Future<Expense> voidExpense({required String actorUserId, required String expenseId, required String reason});
}
