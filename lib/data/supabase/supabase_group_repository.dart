import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/errors/app_exception.dart';
import '../models/models.dart';
import '../repositories/group_repository.dart';
import 'live_query.dart';
import 'row_mappers.dart';
import 'supabase_errors.dart';

/// Groups, membership and join requests. Reads use row-level security; every
/// write is a database function that checks the caller's rights.
class SupabaseGroupRepository implements GroupRepository {
  SupabaseGroupRepository(this._client, this._bus);

  final SupabaseClient _client;
  final RefreshBus _bus;

  static const _noAccess = PermissionDeniedException('You are not an active member of this group.');

  Future<T> _write<T>(Future<T> Function() action) async {
    final result = await guarded(action);
    _bus.ping();
    return result;
  }

  @override
  Stream<List<Group>> watchGroupsForUser(String userId) => liveQuery(
    client: _client,
    bus: _bus,
    name: 'my-groups',
    tables: [
      TableWatch('group_members', column: 'profile_id', value: userId),
      const TableWatch('groups'),
    ],
    fetch: () async {
      final rows = await _client.from('groups').select().order('created_at', ascending: false);
      return rows.map(RowMappers.group).toList();
    },
  );

  @override
  Stream<Group> watchGroup({required String groupId, required String viewerUserId}) => liveQuery(
    client: _client,
    bus: _bus,
    name: 'group-$groupId',
    tables: [
      TableWatch('groups', column: 'id', value: groupId),
      TableWatch('group_members', column: 'group_id', value: groupId),
    ],
    fetch: () async {
      final row = await _client.from('groups').select().eq('id', groupId).maybeSingle();
      if (row == null) throw _noAccess;
      return RowMappers.group(row);
    },
  );

  @override
  Stream<List<GroupMember>> watchMembers({required String groupId, required String viewerUserId}) => liveQuery(
    client: _client,
    bus: _bus,
    name: 'members-$groupId',
    tables: [TableWatch('group_members', column: 'group_id', value: groupId)],
    fetch: () async {
      final rows = await _client.from('group_members').select().eq('group_id', groupId);
      if (rows.isEmpty) throw _noAccess;
      return rows.map(RowMappers.member).toList();
    },
  );

  Future<Group> _group(String id) async =>
      RowMappers.group(await _client.from('groups').select().eq('id', id).single());

  @override
  Future<Group> createGroup({required String actorUserId, required NewGroupInput input}) => _write(() async {
    final id = await _client.rpc<String>(
      'create_group',
      params: {
        'p_name': input.name,
        'p_description': input.description,
        'p_members': [
          for (final m in input.members) {'name': m.name, 'phone': m.phone},
        ],
        'p_contributions': [
          for (final e in input.initialContributionsByPhone.entries) {'phone': e.key, 'amount_paisa': e.value},
        ],
      },
    );
    return _group(id);
  });

  @override
  Future<GroupPreview> findGroupByCode({required String code, required String userId}) => guarded(() async {
    final rows = await _client.rpc<List<dynamic>>('find_group_by_code', params: {'p_code': code});
    final row = rows.cast<Map<String, dynamic>>().first;
    return GroupPreview(
      groupId: row['group_id'] as String,
      name: row['name'] as String,
      activeMemberCount: RowMappers.integer(row['active_member_count']),
      isAlreadyMember: row['is_already_member'] as bool,
      pendingRequestId: row['pending_request_id'] as String?,
    );
  });

  @override
  Future<GroupMember> addMember({
    required String actorUserId,
    required String groupId,
    required NewMemberInput member,
    required DateTime startDate,
  }) => _write(() async {
    final id = await _client.rpc<String>(
      'add_member',
      params: {
        'p_group': groupId,
        'p_name': member.name,
        'p_phone': member.phone,
        'p_start_date': RowMappers.isoDate(startDate),
      },
    );
    return RowMappers.member(await _client.from('group_members').select().eq('id', id).single());
  });

  @override
  Future<void> removeMember({required String actorUserId, required String groupId, required String memberId}) =>
      _write(() => _client.rpc<void>('remove_member', params: {'p_group': groupId, 'p_member': memberId}));

  @override
  Future<LeaveGroupResult> leaveGroup({required String actorUserId, required String groupId}) => _write(() async {
    final newManager = await _client.rpc<String?>('leave_group', params: {'p_group': groupId});
    return LeaveGroupResult(newManagerName: newManager);
  });

  @override
  Future<Group> regenerateCode({required String actorUserId, required String groupId}) => _write(() async {
    await _client.rpc<String>('regenerate_group_code', params: {'p_group': groupId});
    return _group(groupId);
  });

  @override
  Stream<List<JoinRequest>> watchPendingJoinRequests({required String groupId, required String viewerUserId}) =>
      liveQuery(
        client: _client,
        bus: _bus,
        name: 'requests-$groupId',
        tables: [TableWatch('join_requests', column: 'group_id', value: groupId)],
        fetch: () async {
          final rows = await _client
              .from('join_requests')
              .select()
              .eq('group_id', groupId)
              .eq('status', 'pending')
              .order('requested_at');
          return rows.map(RowMappers.joinRequest).toList();
        },
      );

  @override
  Stream<List<JoinRequest>> watchMyJoinRequests(String userId) => liveQuery(
    client: _client,
    bus: _bus,
    name: 'my-requests',
    tables: [TableWatch('join_requests', column: 'profile_id', value: userId)],
    fetch: () async {
      final rows = await _client
          .from('join_requests')
          .select()
          .eq('profile_id', userId)
          .order('requested_at', ascending: false);
      return rows.map(RowMappers.joinRequest).toList();
    },
  );

  @override
  Future<JoinRequest> requestToJoin({
    required String userId,
    required String code,
    required String name,
    required String phone,
  }) => _write(() async {
    // The phone on the request is always the signed-in user's own number.
    final id = await _client.rpc<String>('request_to_join', params: {'p_code': code, 'p_name': name});
    return RowMappers.joinRequest(await _client.from('join_requests').select().eq('id', id).single());
  });

  @override
  Future<void> approveJoinRequest({required String actorUserId, required String requestId}) =>
      _write(() => _client.rpc<void>('decide_join_request', params: {'p_request': requestId, 'p_approve': true}));

  @override
  Future<void> declineJoinRequest({required String actorUserId, required String requestId}) =>
      _write(() => _client.rpc<void>('decide_join_request', params: {'p_request': requestId, 'p_approve': false}));
}
