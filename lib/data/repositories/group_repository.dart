import '../models/models.dart';

class NewMemberInput {
  const NewMemberInput({required this.name, this.email, this.phone, this.initialContributionPaisa = 0});

  final String name;

  /// With an email the person joins automatically when they sign in with it.
  /// Without one they are an offline member.
  final String? email;

  /// Optional normalized E.164 phone number, for the record only.
  final String? phone;

  /// Optional opening contribution to the group fund (group creation only).
  final int initialContributionPaisa;
}

class NewGroupInput {
  const NewGroupInput({required this.name, required this.members, this.description, this.myContributionPaisa = 0});

  final String name;
  final String? description;

  /// Members other than the creator.
  final List<NewMemberInput> members;

  /// The creator's opening contribution to the group fund, in paisa.
  final int myContributionPaisa;
}

/// Result of leaving a group, so the UI can explain what happened.
class LeaveGroupResult {
  const LeaveGroupResult({this.newManagerName});

  /// Set when the manager role passed to another member.
  final String? newManagerName;
}

/// Groups, membership and join requests.
///
/// Every method takes the acting user explicitly. Implementations must verify
/// that the actor is allowed to perform the action; the UI hiding a button is
/// not sufficient. (Production: Supabase row-level security.)
abstract interface class GroupRepository {
  /// Groups where [userId] is currently an active member.
  Stream<List<Group>> watchGroupsForUser(String userId);

  /// Emits a [PermissionDeniedException] error if [viewerUserId] is not an
  /// active member.
  Stream<Group> watchGroup({required String groupId, required String viewerUserId});

  /// All membership records (active and former) of the group.
  Stream<List<GroupMember>> watchMembers({required String groupId, required String viewerUserId});

  Future<Group> createGroup({required String actorUserId, required NewGroupInput input});

  /// Looks up a group by join code without granting access to its records.
  Future<GroupPreview> findGroupByCode({required String code, required String userId});

  /// Any active member can add a member.
  Future<GroupMember> addMember({
    required String actorUserId,
    required String groupId,
    required NewMemberInput member,
    required DateTime startDate,
  });

  /// Only the group manager can remove a member. Their expenses are kept.
  Future<void> removeMember({required String actorUserId, required String groupId, required String memberId});

  Future<LeaveGroupResult> leaveGroup({required String actorUserId, required String groupId});

  /// Only the group manager can issue a new join code.
  Future<Group> regenerateCode({required String actorUserId, required String groupId});

  /// Pending join requests of a group, visible to its active members.
  Stream<List<JoinRequest>> watchPendingJoinRequests({required String groupId, required String viewerUserId});

  /// Join requests made by [userId].
  Stream<List<JoinRequest>> watchMyJoinRequests(String userId);

  /// The request carries the requester's own email and phone.
  Future<JoinRequest> requestToJoin({required String userId, required String code, required String name});

  /// Any active member can approve or decline a join request.
  Future<void> approveJoinRequest({required String actorUserId, required String requestId});

  Future<void> declineJoinRequest({required String actorUserId, required String requestId});
}
