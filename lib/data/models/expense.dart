import '../../core/utils/quantity.dart';

enum ExpenseCategory {
  breakfast('Breakfast'),
  lunch('Lunch'),
  dinner('Dinner'),
  groceries('Groceries'),
  household('Household'),
  bills('Bills'),
  transport('Transport'),
  other('Other');

  const ExpenseCategory(this.label);
  final String label;
}

enum PaymentSource {
  personal('Personal money'),
  groupFund('Group fund');

  const PaymentSource(this.label);
  final String label;
}

/// Expenses are never deleted. A mistaken entry is either edited or voided by
/// its creator; a voided expense stays visible but is excluded from totals.
enum ExpenseStatus { active, voided }

class ExpenseItem {
  const ExpenseItem({required this.id, required this.name, required this.quantityMilli, required this.unitPricePaisa});

  final String id;
  final String name;

  /// Quantity in thousandths, see [Quantity].
  final int quantityMilli;
  final int unitPricePaisa;

  int get lineTotalPaisa => Quantity.lineTotal(unitPricePaisa: unitPricePaisa, quantityMilli: quantityMilli);
}

/// The editable fields of an expense, used when adding or editing.
/// Ownership fields are intentionally absent: they are set by the repository.
class ExpenseDraft {
  const ExpenseDraft({
    required this.title,
    required this.date,
    required this.category,
    required this.items,
    required this.paymentSource,
    required this.splitAmongUserIds,
    this.quickAmountPaisa,
    this.paidByUserId,
    this.notes,
  });

  final String title;
  final DateTime date;
  final ExpenseCategory category;

  /// Itemized entries. When empty, [quickAmountPaisa] is the total.
  final List<ExpenseItem> items;
  final int? quickAmountPaisa;

  /// Who paid from their own pocket. `null` when paid from the group fund.
  final String? paidByUserId;
  final PaymentSource paymentSource;

  /// Members who share this expense equally.
  final List<String> splitAmongUserIds;
  final String? notes;

  bool get isItemized => items.isNotEmpty;

  int get totalPaisa => isItemized ? items.fold(0, (sum, item) => sum + item.lineTotalPaisa) : (quickAmountPaisa ?? 0);
}

class Expense {
  const Expense({
    required this.id,
    required this.groupId,
    required this.title,
    required this.date,
    required this.category,
    required this.items,
    required this.createdByUserId,
    required this.paymentSource,
    required this.splitAmongUserIds,
    required this.status,
    required this.createdAt,
    this.quickAmountPaisa,
    this.paidByUserId,
    this.notes,
    this.editedAt,
    this.voidedAt,
    this.voidReason,
  });

  final String id;
  final String groupId;
  final String title;
  final DateTime date;
  final ExpenseCategory category;
  final List<ExpenseItem> items;
  final int? quickAmountPaisa;

  /// The user who created the record. Immutable: only this user may ever edit
  /// or void the expense. Separate from [paidByUserId].
  final String createdByUserId;
  final String? paidByUserId;
  final PaymentSource paymentSource;
  final List<String> splitAmongUserIds;
  final String? notes;
  final ExpenseStatus status;
  final DateTime createdAt;
  final DateTime? editedAt;
  final DateTime? voidedAt;
  final String? voidReason;

  bool get isItemized => items.isNotEmpty;
  bool get isVoided => status == ExpenseStatus.voided;
  bool get isEdited => editedAt != null;

  int get totalPaisa => isItemized ? items.fold(0, (sum, item) => sum + item.lineTotalPaisa) : (quickAmountPaisa ?? 0);

  ExpenseDraft toDraft() => ExpenseDraft(
    title: title,
    date: date,
    category: category,
    items: items,
    quickAmountPaisa: quickAmountPaisa,
    paidByUserId: paidByUserId,
    paymentSource: paymentSource,
    splitAmongUserIds: splitAmongUserIds,
    notes: notes,
  );

  /// Returns a copy with the editable fields replaced by [draft]. The id,
  /// group and creator are preserved.
  Expense applyDraft(ExpenseDraft draft, {required DateTime editedAt}) {
    return Expense(
      id: id,
      groupId: groupId,
      title: draft.title,
      date: draft.date,
      category: draft.category,
      items: draft.items,
      quickAmountPaisa: draft.isItemized ? null : draft.quickAmountPaisa,
      createdByUserId: createdByUserId,
      paidByUserId: draft.paidByUserId,
      paymentSource: draft.paymentSource,
      splitAmongUserIds: draft.splitAmongUserIds,
      notes: draft.notes,
      status: status,
      createdAt: createdAt,
      editedAt: editedAt,
      voidedAt: voidedAt,
      voidReason: voidReason,
    );
  }

  Expense markVoided({required DateTime at, required String reason}) {
    return Expense(
      id: id,
      groupId: groupId,
      title: title,
      date: date,
      category: category,
      items: items,
      quickAmountPaisa: quickAmountPaisa,
      createdByUserId: createdByUserId,
      paidByUserId: paidByUserId,
      paymentSource: paymentSource,
      splitAmongUserIds: splitAmongUserIds,
      notes: notes,
      status: ExpenseStatus.voided,
      createdAt: createdAt,
      editedAt: editedAt,
      voidedAt: at,
      voidReason: reason,
    );
  }
}
