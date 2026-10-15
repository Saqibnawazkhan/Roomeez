import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';
import '../repositories/contribution_repository.dart';
import 'live_query.dart';
import 'row_mappers.dart';
import 'supabase_errors.dart';

class SupabaseContributionRepository implements ContributionRepository {
  SupabaseContributionRepository(this._client, this._bus);

  final SupabaseClient _client;
  final RefreshBus _bus;

  @override
  Stream<List<Contribution>> watchContributions({required String groupId, required String viewerUserId}) => liveQuery(
    client: _client,
    bus: _bus,
    name: 'contributions-$groupId',
    tables: [TableWatch('contributions', column: 'group_id', value: groupId)],
    fetch: () async {
      final rows = await _client.from('contributions').select().eq('group_id', groupId).order('date', ascending: false);
      return rows.map(RowMappers.contribution).toList();
    },
  );

  @override
  Future<Contribution> addContribution({
    required String actorUserId,
    required String groupId,
    required String memberUserId,
    required int amountPaisa,
    required DateTime date,
    String? note,
  }) async {
    final contribution = await guarded(() async {
      final id = await _client.rpc<String>(
        'add_contribution',
        params: {
          'p_group': groupId,
          'p_member': memberUserId,
          'p_amount_paisa': amountPaisa,
          'p_date': RowMappers.isoDate(date),
          'p_note': note,
        },
      );
      return RowMappers.contribution(await _client.from('contributions').select().eq('id', id).single());
    });
    _bus.ping();
    return contribution;
  }
}
