import '../../core/errors/app_exception.dart';
import '../../core/utils/dates.dart';
import '../models/models.dart';
import '../repositories/group_repository.dart';
import '../services/group_code_generator.dart';
import '../services/permission_policy.dart';
import 'mock_store.dart';

/// PROTOTYPE ONLY. Enforces the same permission rules a real backend must.
class MockGroupRepository implements GroupRepository {
  MockGroupRepository(this._store);

  final MockStore _store;

  @override
  Stream<List<Group>> watchGroupsForUser(String userId) {
    return _store.watch(() {
      final groups = _store.groups.values.where((g) => _store.activeMembership(g.id, userId) != null).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return groups;
    });
  }

  @override
  Stream<Group> watchGroup({required String groupId, required String viewerUserId}) {
    return _store.watch(() {
      _store.requireActiveMember(groupId, viewerUserId);
      return _store.requireGroup(groupId);
    });
  }

  @override
  Stream<List<GroupMember>> watchMembers({required String groupId, required String viewerUserId}) {
    return _store.watch(() {
      _store.requireActiveMember(groupId, viewerUserId);
      return _store.membersOf(groupId);
    });
  }

  @override
  Future<Group> createGroup({required String actorUserId, required NewGroupInput input}) async {
    await _store.simulateLatency();
    final creator = _store.users[actorUserId];
    if (creator == null) throw const PermissionDeniedException('Please log in again.');
    final name = input.name.trim();
    if (name.isEmpty) throw const ValidationException('Enter a group name.');

    final now = _store.now();
    final day = _store.todayDate();
    final group = Group(
      id: _store.newId('group'),
      name: name,
      description: _emptyToNull(input.description),
      code: _store.uniqueGroupCode(),
      createdByUserId: creator.id,
      createdAt: now,
    );
    _store.groups[group.id] = group;

    final creatorMember = GroupMember(
      id: _store.newId('member'),
      groupId: group.id,
      userId: creator.id,
      displayName: creator.name,
      email: creator.email,
      phone: creator.phone,
      role: MemberRole.manager,
      status: MemberStatus.active,
      startDate: day,
      addedByUserId: creator.id,
    );
    _store.members[creatorMember.id] = creatorMember;
    _contribute(group.id, creator.id, input.myContributionPaisa, day, creator.id);

    for (final input in input.members) {
      final user = _store.findOrCreateMemberUser(name: input.name.trim(), email: input.email, phone: input.phone);
      if (_store.activeMembership(group.id, user.id) != null) continue;
      final member = GroupMember(
        id: _store.newId('member'),
        groupId: group.id,
        userId: user.id,
        displayName: user.isRegistered && user.name.isNotEmpty ? user.name : input.name.trim(),
        email: user.email,
        phone: input.phone,
        role: MemberRole.member,
        status: MemberStatus.active,
        startDate: day,
        addedByUserId: creator.id,
      );
      _store.members[member.id] = member;
      _contribute(group.id, user.id, input.initialContributionPaisa, day, creator.id);
    }

    _store.notify();
    return group;
  }

  void _contribute(String groupId, String userId, int amount, DateTime day, String recordedBy) {
    if (amount <= 0) return;
    final contribution = Contribution(
      id: _store.newId('contribution'),
      groupId: groupId,
      memberUserId: userId,
      amountPaisa: amount,
      date: day,
      type: ContributionType.initial,
      recordedByUserId: recordedBy,
      createdAt: _store.now(),
    );
    _store.contributions[contribution.id] = contribution;
  }

  @override
  Future<GroupPreview> findGroupByCode({required String code, required String userId}) async {
    await _store.simulateLatency();
    final normalized = GroupCodeFormat.normalize(code);
    final group = _store.groupByCode(normalized);
    if (group == null) {
      throw NotFoundException('No group found with code $normalized. Check the code and try again.');
    }
    String? pendingId;
    for (final r in _store.joinRequests.values) {
      if (r.groupId == group.id && r.userId == userId && r.isPending) pendingId = r.id;
    }
    return GroupPreview(
      groupId: group.id,
      name: group.name,
      activeMemberCount: _store.membersOf(group.id).where((m) => m.isActive).length,
      isAlreadyMember: _store.activeMembership(group.id, userId) != null,
      pendingRequestId: pendingId,
    );
  }

  @override
  Future<GroupMember> addMember({
    required String actorUserId,
    required String groupId,
    required NewMemberInput member,
    required DateTime startDate,
  }) async {
    await _store.simulateLatency();
    final actor = _store.requireActiveMember(groupId, actorUserId);
    if (!PermissionPolicy.canAddMember(actor)) {
      throw const PermissionDeniedException('You can\'t add members to this group.');
    }
    final name = member.name.trim();
    if (name.isEmpty) throw const ValidationException('Enter the member\'s name.');
    final user = _store.findOrCreateMemberUser(name: name, email: member.email, phone: member.phone);
    if (_store.activeMembership(groupId, user.id) != null) {
      throw ConflictException('${user.name.isEmpty ? name : user.name} is already a member of this group.');
    }
    final created = GroupMember(
      id: _store.newId('member'),
      groupId: groupId,
      userId: user.id,
      displayName: user.isRegistered && user.name.isNotEmpty ? user.name : name,
      email: user.email,
      phone: member.phone,
      role: MemberRole.member,
      status: MemberStatus.active,
      startDate: dateOnly(startDate),
      addedByUserId: actorUserId,
    );
    _store.members[created.id] = created;
    _resolvePendingRequests(groupId, user.id, actorUserId, JoinRequestStatus.approved);
    _store.notify();
    return created;
  }

  @override
  Future<void> removeMember({required String actorUserId, required String groupId, required String memberId}) async {
    await _store.simulateLatency();
    final actor = _store.requireActiveMember(groupId, actorUserId);
    final target = _store.members[memberId];
    if (target == null || target.groupId != groupId) {
      throw const NotFoundException('Member not found.');
    }
    if (!PermissionPolicy.canRemoveMember(actor: actor, target: target)) {
      throw const PermissionDeniedException('Only the group manager can remove other members.');
    }
    // The membership ends; every expense they recorded stays untouched.
    _store.members[memberId] = target.copyWith(
      status: MemberStatus.removed,
      role: MemberRole.member,
      endDate: _store.todayDate(),
    );
    _store.notify();
  }

  @override
  Future<LeaveGroupResult> leaveGroup({required String actorUserId, required String groupId}) async {
    await _store.simulateLatency();
    final actor = _store.requireActiveMember(groupId, actorUserId);
    _store.members[actor.id] = actor.copyWith(
      status: MemberStatus.left,
      role: MemberRole.member,
      endDate: _store.todayDate(),
    );
    String? newManagerName;
    if (actor.isManager) {
      final successor = successorFor(groupId, leavingUserId: actorUserId);
      if (successor != null) {
        _store.members[successor.id] = successor.copyWith(role: MemberRole.manager);
        newManagerName = successor.displayName;
      }
    }
    _store.notify();
    return LeaveGroupResult(newManagerName: newManagerName);
  }

  /// The longest-standing other active member, who becomes manager.
  GroupMember? successorFor(String groupId, {required String leavingUserId}) {
    final candidates = _store.membersOf(groupId).where((m) => m.isActive && m.userId != leavingUserId).toList()
      ..sort((a, b) {
        final byStart = a.startDate.compareTo(b.startDate);
        return byStart != 0 ? byStart : a.id.compareTo(b.id);
      });
    return candidates.isEmpty ? null : candidates.first;
  }

  @override
  Future<Group> regenerateCode({required String actorUserId, required String groupId}) async {
    await _store.simulateLatency();
    final actor = _store.requireActiveMember(groupId, actorUserId);
    if (!PermissionPolicy.canRegenerateCode(actor)) {
      throw const PermissionDeniedException('Only the group manager can change the join code.');
    }
    final updated = _store.requireGroup(groupId).copyWith(code: _store.uniqueGroupCode());
    _store.groups[groupId] = updated;
    _store.notify();
    return updated;
  }

  @override
  Stream<List<JoinRequest>> watchPendingJoinRequests({required String groupId, required String viewerUserId}) {
    return _store.watch(() {
      _store.requireActiveMember(groupId, viewerUserId);
      return _store.joinRequests.values.where((r) => r.groupId == groupId && r.isPending).toList()
        ..sort((a, b) => a.requestedAt.compareTo(b.requestedAt));
    });
  }

  @override
  Stream<List<JoinRequest>> watchMyJoinRequests(String userId) {
    return _store.watch(() {
      return _store.joinRequests.values.where((r) => r.userId == userId).toList()
        ..sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
    });
  }

  @override
  Future<JoinRequest> requestToJoin({required String userId, required String code, required String name}) async {
    await _store.simulateLatency();
    final group = _store.groupByCode(GroupCodeFormat.normalize(code));
    if (group == null) throw const NotFoundException('No group found with this code.');
    if (_store.activeMembership(group.id, userId) != null) {
      throw const ConflictException('You are already a member of this group.');
    }
    for (final r in _store.joinRequests.values) {
      if (r.groupId == group.id && r.userId == userId && r.isPending) return r;
    }
    final requester = _store.users[userId];
    final request = JoinRequest(
      id: _store.newId('request'),
      groupId: group.id,
      groupName: group.name,
      userId: userId,
      name: name.trim(),
      email: requester?.email,
      phone: requester?.phone,
      status: JoinRequestStatus.pending,
      requestedAt: _store.now(),
    );
    _store.joinRequests[request.id] = request;
    _store.notify();
    return request;
  }

  @override
  Future<void> approveJoinRequest({required String actorUserId, required String requestId}) async {
    await _store.simulateLatency();
    final request = _requirePending(requestId);
    final actor = _store.requireActiveMember(request.groupId, actorUserId);
    if (!PermissionPolicy.canReviewJoinRequests(actor)) {
      throw const PermissionDeniedException('You can\'t review join requests for this group.');
    }
    if (_store.activeMembership(request.groupId, request.userId) == null) {
      final member = GroupMember(
        id: _store.newId('member'),
        groupId: request.groupId,
        userId: request.userId,
        displayName: request.name,
        email: request.email,
        phone: request.phone,
        role: MemberRole.member,
        status: MemberStatus.active,
        startDate: _store.todayDate(),
        addedByUserId: actorUserId,
      );
      _store.members[member.id] = member;
    }
    _store.joinRequests[requestId] = request.decide(
      status: JoinRequestStatus.approved,
      byUserId: actorUserId,
      at: _store.now(),
    );
    _store.notify();
  }

  @override
  Future<void> declineJoinRequest({required String actorUserId, required String requestId}) async {
    await _store.simulateLatency();
    final request = _requirePending(requestId);
    final actor = _store.requireActiveMember(request.groupId, actorUserId);
    if (!PermissionPolicy.canReviewJoinRequests(actor)) {
      throw const PermissionDeniedException('You can\'t review join requests for this group.');
    }
    _store.joinRequests[requestId] = request.decide(
      status: JoinRequestStatus.declined,
      byUserId: actorUserId,
      at: _store.now(),
    );
    _store.notify();
  }

  JoinRequest _requirePending(String requestId) {
    final request = _store.joinRequests[requestId];
    if (request == null) throw const NotFoundException('Join request not found.');
    if (!request.isPending) throw const ConflictException('This request was already handled.');
    return request;
  }

  void _resolvePendingRequests(String groupId, String userId, String byUserId, JoinRequestStatus status) {
    for (final r in _store.joinRequests.values.toList()) {
      if (r.groupId == groupId && r.userId == userId && r.isPending) {
        _store.joinRequests[r.id] = r.decide(status: status, byUserId: byUserId, at: _store.now());
      }
    }
  }

  static String? _emptyToNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
