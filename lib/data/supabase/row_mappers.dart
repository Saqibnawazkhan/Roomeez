import '../../core/utils/dates.dart';
import '../models/models.dart';

/// Conversions between database rows (see supabase/migrations) and models.
/// Kept free of Supabase types so they can be unit tested.
abstract final class RowMappers {
  static DateTime date(Object? value) {
    final parsed = DateTime.parse(value as String);
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  static DateTime timestamp(Object? value) => DateTime.parse(value as String).toLocal();

  static DateTime? maybeTimestamp(Object? value) => value == null ? null : timestamp(value);

  static int integer(Object? value) => (value as num).toInt();

  static String isoDate(DateTime value) => AppDates.iso(value);

  static AppUser profile(Map<String, dynamic> row) => AppUser(
    id: row['id'] as String,
    name: row['name'] as String? ?? '',
    phone: row['phone'] as String,
    isRegistered: row['auth_user_id'] != null,
    hasCompletedProfile: row['has_completed_profile'] as bool? ?? false,
    createdAt: timestamp(row['created_at']),
  );

  static Group group(Map<String, dynamic> row) => Group(
    id: row['id'] as String,
    name: row['name'] as String,
    description: row['description'] as String?,
    code: row['code'] as String,
    createdByUserId: row['created_by'] as String,
    createdAt: timestamp(row['created_at']),
  );

  static GroupMember member(Map<String, dynamic> row) => GroupMember(
    id: row['id'] as String,
    groupId: row['group_id'] as String,
    userId: row['profile_id'] as String,
    displayName: row['display_name'] as String,
    phone: row['phone'] as String,
    role: MemberRole.values.byName(row['role'] as String),
    status: MemberStatus.values.byName(row['status'] as String),
    startDate: date(row['start_date']),
    endDate: row['end_date'] == null ? null : date(row['end_date']),
    addedByUserId: row['added_by'] as String?,
  );

  static JoinRequest joinRequest(Map<String, dynamic> row) => JoinRequest(
    id: row['id'] as String,
    groupId: row['group_id'] as String,
    groupName: row['group_name'] as String,
    userId: row['profile_id'] as String,
    name: row['name'] as String,
    phone: row['phone'] as String,
    status: JoinRequestStatus.values.byName(row['status'] as String),
    requestedAt: timestamp(row['requested_at']),
    decidedByUserId: row['decided_by'] as String?,
    decidedAt: maybeTimestamp(row['decided_at']),
  );

  static PaymentSource paymentSource(String value) =>
      value == 'group_fund' ? PaymentSource.groupFund : PaymentSource.personal;

  static String paymentSourceValue(PaymentSource value) => value == PaymentSource.groupFund ? 'group_fund' : 'personal';

  static Expense expense(Map<String, dynamic> row) => Expense(
    id: row['id'] as String,
    groupId: row['group_id'] as String,
    title: row['title'] as String,
    date: date(row['date']),
    category: ExpenseCategory.values.byName(row['category'] as String),
    items: [
      for (final item in (row['items'] as List? ?? const []).cast<Map<String, dynamic>>())
        ExpenseItem(
          id: item['id'] as String? ?? '',
          name: item['name'] as String,
          quantityMilli: integer(item['quantity_milli']),
          unitPricePaisa: integer(item['unit_price_paisa']),
        ),
    ],
    quickAmountPaisa: row['quick_amount_paisa'] == null ? null : integer(row['quick_amount_paisa']),
    createdByUserId: row['created_by'] as String,
    paidByUserId: row['paid_by'] as String?,
    paymentSource: paymentSource(row['payment_source'] as String),
    splitAmongUserIds: (row['split_among'] as List).cast<String>(),
    notes: row['notes'] as String?,
    status: ExpenseStatus.values.byName(row['status'] as String),
    createdAt: timestamp(row['created_at']),
    editedAt: maybeTimestamp(row['edited_at']),
    voidedAt: maybeTimestamp(row['voided_at']),
    voidReason: row['void_reason'] as String?,
  );

  static Contribution contribution(Map<String, dynamic> row) => Contribution(
    id: row['id'] as String,
    groupId: row['group_id'] as String,
    memberUserId: row['member_profile_id'] as String,
    amountPaisa: integer(row['amount_paisa']),
    date: date(row['date']),
    type: row['type'] == 'initial' ? ContributionType.initial : ContributionType.topUp,
    recordedByUserId: row['recorded_by'] as String,
    createdAt: timestamp(row['created_at']),
    note: row['note'] as String?,
  );

  /// The payload expected by the `add_expense` / `update_expense` functions.
  static Map<String, dynamic> expensePayload(ExpenseDraft draft) => {
    'title': draft.title,
    'date': isoDate(draft.date),
    'category': draft.category.name,
    'items': [
      for (final item in draft.items)
        {
          if (item.id.isNotEmpty) 'id': item.id,
          'name': item.name,
          'quantity_milli': item.quantityMilli,
          'unit_price_paisa': item.unitPricePaisa,
        },
    ],
    'quick_amount_paisa': draft.isItemized ? null : draft.quickAmountPaisa,
    'payment_source': paymentSourceValue(draft.paymentSource),
    'paid_by': draft.paymentSource == PaymentSource.groupFund ? null : draft.paidByUserId,
    'split_among': draft.splitAmongUserIds,
    'notes': draft.notes,
  };
}
