import '../../core/utils/dates.dart';
import 'models.dart';

/// Everything about one group that a member's screens need, as seen by
/// [viewerUserId]. Pure data; no side effects.
class GroupSnapshot {
  GroupSnapshot({
    required this.group,
    required this.members,
    required this.expenses,
    required this.contributions,
    required this.viewerUserId,
  });

  final Group group;

  /// All membership records, including former members.
  final List<GroupMember> members;
  final List<Expense> expenses;
  final List<Contribution> contributions;
  final String viewerUserId;

  /// The viewer's active membership, if any.
  late final GroupMember? me = activeMembershipOf(viewerUserId);

  late final List<GroupMember> activeMembers = members.where((m) => m.isActive).toList()
    ..sort((a, b) {
      if (a.isManager != b.isManager) return a.isManager ? -1 : 1;
      return a.startDate.compareTo(b.startDate);
    });

  /// Former memberships of people who are not currently active.
  late final List<GroupMember> formerMembers =
      members.where((m) => !m.isActive && activeMembershipOf(m.userId) == null).toList()
        ..sort((a, b) => (b.endDate ?? b.startDate).compareTo(a.endDate ?? a.startDate));

  GroupMember? get manager {
    for (final m in activeMembers) {
      if (m.isManager) return m;
    }
    return null;
  }

  GroupMember? activeMembershipOf(String userId) {
    for (final m in members) {
      if (m.userId == userId && m.isActive) return m;
    }
    return null;
  }

  /// The active membership, or the most recent past one.
  GroupMember? membershipOf(String userId) {
    final active = activeMembershipOf(userId);
    if (active != null) return active;
    GroupMember? latest;
    for (final m in members) {
      if (m.userId != userId) continue;
      if (latest == null || m.startDate.isAfter(latest.startDate)) latest = m;
    }
    return latest;
  }

  String nameOf(String? userId) {
    if (userId == null) return 'Group fund';
    return membershipOf(userId)?.displayName ?? 'Former member';
  }

  /// Distinct members whose membership covers [day], in display order.
  List<GroupMember> membersCoveringDay(DateTime day) {
    final seen = <String>{};
    final result = <GroupMember>[];
    final ordered = [...activeMembers, ...members.where((m) => !m.isActive)];
    for (final m in ordered) {
      if (m.coversDay(day) && seen.add(m.userId)) result.add(m);
    }
    return result;
  }

  /// Memberships that overlap [range] at any point.
  List<GroupMember> membersOverlapping(DateRange range) {
    return members.where((m) {
      final startsBeforeEnd = !m.startDate.isAfter(range.end);
      final endsAfterStart = m.endDate == null || !m.endDate!.isBefore(range.start);
      return startsBeforeEnd && endsAfterStart;
    }).toList()..sort((a, b) => a.startDate.compareTo(b.startDate));
  }

  Expense? expenseById(String id) {
    for (final e in expenses) {
      if (e.id == id) return e;
    }
    return null;
  }
}
