enum JoinRequestStatus { pending, approved, declined }

/// A request to join a group by code. Any active member can approve it.
class JoinRequest {
  const JoinRequest({
    required this.id,
    required this.groupId,
    required this.groupName,
    required this.userId,
    required this.name,
    required this.phone,
    required this.status,
    required this.requestedAt,
    this.decidedByUserId,
    this.decidedAt,
  });

  final String id;
  final String groupId;

  /// Copied at request time so the requester can see which group they asked
  /// to join without being given access to the group itself.
  final String groupName;
  final String userId;
  final String name;
  final String phone;
  final JoinRequestStatus status;
  final DateTime requestedAt;
  final String? decidedByUserId;
  final DateTime? decidedAt;

  bool get isPending => status == JoinRequestStatus.pending;

  JoinRequest decide({required JoinRequestStatus status, required String byUserId, required DateTime at}) {
    return JoinRequest(
      id: id,
      groupId: groupId,
      groupName: groupName,
      userId: userId,
      name: name,
      phone: phone,
      status: status,
      requestedAt: requestedAt,
      decidedByUserId: byUserId,
      decidedAt: at,
    );
  }
}
