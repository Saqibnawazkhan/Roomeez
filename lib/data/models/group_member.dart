import '../../core/utils/dates.dart';

/// The manager is a regular member who can additionally remove members and
/// regenerate the join code. It starts as the group creator and passes to
/// the longest-standing member if the manager leaves.
enum MemberRole { manager, member }

enum MemberStatus {
  active('Active'),
  left('Left'),
  removed('Removed');

  const MemberStatus(this.label);
  final String label;
}

/// One membership period of a user in a group. If a person leaves and is
/// added again later, a new record is created so history stays accurate.
class GroupMember {
  const GroupMember({
    required this.id,
    required this.groupId,
    required this.userId,
    required this.displayName,
    required this.phone,
    required this.role,
    required this.status,
    required this.startDate,
    this.endDate,
    this.addedByUserId,
  });

  final String id;
  final String groupId;
  final String userId;
  final String displayName;
  final String phone;
  final MemberRole role;
  final MemberStatus status;

  /// First day this person shares group expenses.
  final DateTime startDate;

  /// Last day of membership, set when the member leaves or is removed.
  final DateTime? endDate;
  final String? addedByUserId;

  bool get isActive => status == MemberStatus.active;
  bool get isManager => role == MemberRole.manager && isActive;

  /// Whether this membership period covers [day].
  bool coversDay(DateTime day) {
    final d = dateOnly(day);
    return !d.isBefore(startDate) && (endDate == null || !d.isAfter(endDate!));
  }

  GroupMember copyWith({String? displayName, MemberRole? role, MemberStatus? status, DateTime? endDate}) {
    return GroupMember(
      id: id,
      groupId: groupId,
      userId: userId,
      displayName: displayName ?? this.displayName,
      phone: phone,
      role: role ?? this.role,
      status: status ?? this.status,
      startDate: startDate,
      endDate: endDate ?? this.endDate,
      addedByUserId: addedByUserId,
    );
  }
}
