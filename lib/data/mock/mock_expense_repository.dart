import '../../core/errors/app_exception.dart';
import '../../core/utils/dates.dart';
import '../models/models.dart';
import '../repositories/expense_repository.dart';
import '../services/expense_validator.dart';
import '../services/permission_policy.dart';
import 'mock_store.dart';

/// PROTOTYPE ONLY. Enforces creator-only editing in the data layer, not just
/// in the UI. There is intentionally no way to remove an expense.
class MockExpenseRepository implements ExpenseRepository {
  MockExpenseRepository(this._store);

  final MockStore _store;

  @override
  Stream<List<Expense>> watchExpenses({required String groupId, required String viewerUserId}) {
    return _store.watch(() {
      _store.requireActiveMember(groupId, viewerUserId);
      return _store.expenses.values.where((e) => e.groupId == groupId).toList()..sort((a, b) {
        final byDate = b.date.compareTo(a.date);
        return byDate != 0 ? byDate : b.createdAt.compareTo(a.createdAt);
      });
    });
  }

  @override
  Future<Expense> addExpense({
    required String actorUserId,
    required String groupId,
    required ExpenseDraft draft,
  }) async {
    await _store.simulateLatency();
    final actor = _store.requireActiveMember(groupId, actorUserId);
    if (!PermissionPolicy.canAddExpense(actor)) {
      throw const PermissionDeniedException('You can\'t add expenses to this group.');
    }
    final clean = _validate(groupId, draft);
    final expense = Expense(
      id: _store.newId('expense'),
      groupId: groupId,
      title: clean.title,
      date: clean.date,
      category: clean.category,
      items: clean.items,
      quickAmountPaisa: clean.quickAmountPaisa,
      createdByUserId: actorUserId,
      paidByUserId: clean.paidByUserId,
      paymentSource: clean.paymentSource,
      splitAmongUserIds: clean.splitAmongUserIds,
      notes: clean.notes,
      status: ExpenseStatus.active,
      createdAt: _store.now(),
    );
    _store.expenses[expense.id] = expense;
    _store.notify();
    return expense;
  }

  @override
  Future<Expense> updateExpense({
    required String actorUserId,
    required String expenseId,
    required ExpenseDraft draft,
  }) async {
    await _store.simulateLatency();
    final existing = _requireEditable(actorUserId, expenseId);
    final clean = _validate(existing.groupId, draft);
    final updated = existing.applyDraft(clean, editedAt: _store.now());
    _store.expenses[expenseId] = updated;
    _store.notify();
    return updated;
  }

  @override
  Future<Expense> voidExpense({required String actorUserId, required String expenseId, required String reason}) async {
    await _store.simulateLatency();
    final existing = _requireEditable(actorUserId, expenseId);
    final trimmed = reason.trim();
    if (trimmed.isEmpty) throw const ValidationException('Add a short reason for voiding.');
    final voided = existing.markVoided(at: _store.now(), reason: trimmed);
    _store.expenses[expenseId] = voided;
    _store.notify();
    return voided;
  }

  Expense _requireEditable(String actorUserId, String expenseId) {
    final existing = _store.expenses[expenseId];
    if (existing == null) throw const NotFoundException('Expense not found.');
    final actor = _store.activeMembership(existing.groupId, actorUserId);
    if (!PermissionPolicy.canEditExpense(actor: actor, expense: existing)) {
      if (existing.isVoided) {
        throw const PermissionDeniedException('Voided expenses can\'t be changed.');
      }
      throw const PermissionDeniedException('Only the person who added this expense can change it.');
    }
    return existing;
  }

  /// Validates the draft and checks referenced members belong to the group on
  /// the expense date. Returns a normalized copy.
  ExpenseDraft _validate(String groupId, ExpenseDraft draft) {
    ExpenseValidator.check(draft);
    final day = dateOnly(draft.date);
    final members = _store.membersOf(groupId);
    bool coversDay(String userId) => members.any((m) => m.userId == userId && m.coversDay(day));

    for (final userId in draft.splitAmongUserIds) {
      if (!coversDay(userId)) {
        throw const ValidationException('Only people who were members on the expense date can share it.');
      }
    }
    final paidBy = draft.paymentSource == PaymentSource.groupFund ? null : draft.paidByUserId;
    if (paidBy != null && !coversDay(paidBy)) {
      throw const ValidationException('The payer must have been a member on the expense date.');
    }
    final notes = draft.notes?.trim();
    return ExpenseDraft(
      title: draft.title.trim(),
      date: day,
      category: draft.category,
      items: [
        for (final item in draft.items)
          ExpenseItem(
            id: item.id.isEmpty ? _store.newId('item') : item.id,
            name: item.name.trim(),
            quantityMilli: item.quantityMilli,
            unitPricePaisa: item.unitPricePaisa,
          ),
      ],
      quickAmountPaisa: draft.isItemized ? null : draft.quickAmountPaisa,
      paidByUserId: paidBy,
      paymentSource: draft.paymentSource,
      splitAmongUserIds: draft.splitAmongUserIds.toSet().toList(),
      notes: notes == null || notes.isEmpty ? null : notes,
    );
  }
}
