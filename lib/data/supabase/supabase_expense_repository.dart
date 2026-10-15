import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';
import '../repositories/expense_repository.dart';
import 'live_query.dart';
import 'row_mappers.dart';
import 'supabase_errors.dart';

/// Expenses. Creator-only editing and the no-delete rule are enforced by the
/// database (functions, row-level security and triggers), not just here.
class SupabaseExpenseRepository implements ExpenseRepository {
  SupabaseExpenseRepository(this._client, this._bus);

  final SupabaseClient _client;
  final RefreshBus _bus;

  Future<Expense> _load(String id) async =>
      RowMappers.expense(await _client.from('expenses').select().eq('id', id).single());

  @override
  Stream<List<Expense>> watchExpenses({required String groupId, required String viewerUserId}) => liveQuery(
    client: _client,
    bus: _bus,
    name: 'expenses-$groupId',
    tables: [TableWatch('expenses', column: 'group_id', value: groupId)],
    fetch: () async {
      final rows = await _client
          .from('expenses')
          .select()
          .eq('group_id', groupId)
          .order('date', ascending: false)
          .order('created_at', ascending: false);
      return rows.map(RowMappers.expense).toList();
    },
  );

  @override
  Future<Expense> addExpense({required String actorUserId, required String groupId, required ExpenseDraft draft}) =>
      _write(() async {
        final id = await _client.rpc<String>(
          'add_expense',
          params: {'p_group': groupId, 'p_expense': RowMappers.expensePayload(draft)},
        );
        return _load(id);
      });

  @override
  Future<Expense> updateExpense({
    required String actorUserId,
    required String expenseId,
    required ExpenseDraft draft,
  }) => _write(() async {
    await _client.rpc<void>(
      'update_expense',
      params: {'p_expense': expenseId, 'p_data': RowMappers.expensePayload(draft)},
    );
    return _load(expenseId);
  });

  @override
  Future<Expense> voidExpense({required String actorUserId, required String expenseId, required String reason}) =>
      _write(() async {
        await _client.rpc<void>('void_expense', params: {'p_expense': expenseId, 'p_reason': reason});
        return _load(expenseId);
      });

  Future<T> _write<T>(Future<T> Function() action) async {
    final result = await guarded(action);
    _bus.ping();
    return result;
  }
}
