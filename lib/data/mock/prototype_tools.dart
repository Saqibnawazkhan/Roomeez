import '../../core/errors/app_exception.dart';
import '../models/models.dart';
import '../repositories/group_repository.dart';
import 'mock_auth_repository.dart';
import 'mock_seed.dart';
import 'mock_store.dart';

/// PROTOTYPE ONLY. Shortcuts for user testing that have no production
/// equivalent: switching between sample accounts and simulating another
/// member approving a join request. Every screen that uses this labels the
/// action as a prototype feature.
class PrototypeTools {
  PrototypeTools(this._store, this._groups);

  final MockStore _store;
  final GroupRepository _groups;

  /// The sign-in code accepted by the demo.
  String get demoCode => MockAuthRepository.demoCode;

  List<AppUser> get sampleUsers => [
    for (final id in sampleUserIds)
      if (_store.users[id] != null) _store.users[id]!,
  ];

  Future<void> signInAs(String userId) async {
    if (!_store.users.containsKey(userId)) {
      throw const NotFoundException('Sample user not found.');
    }
    _store.sessionUserId = userId;
    _store.notify();
  }

  /// Approves [requestId] as if an existing member did it. Prefers the
  /// manager, otherwise any active member.
  Future<String> simulateApprovalByMember(String requestId) async {
    final request = _store.joinRequests[requestId];
    if (request == null) throw const NotFoundException('Join request not found.');
    final active = _store.membersOf(request.groupId).where((m) => m.isActive).toList()
      ..sort((a, b) => (a.isManager ? 0 : 1).compareTo(b.isManager ? 0 : 1));
    if (active.isEmpty) throw const ConflictException('This group has no members to approve you.');
    await _groups.approveJoinRequest(actorUserId: active.first.userId, requestId: requestId);
    return active.first.displayName;
  }
}
