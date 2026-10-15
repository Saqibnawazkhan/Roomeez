import '../models/models.dart';

/// Single source of truth for who may do what. Used by the UI to decide which
/// controls to show **and** by repositories to reject unauthorized calls.
///
/// A production backend must enforce the same rules server-side (Supabase
/// row-level security); hiding a button is not security.
abstract final class PermissionPolicy {
  static bool isActiveMember(GroupMember? actor) => actor != null && actor.isActive;

  static bool canAddExpense(GroupMember? actor) => isActiveMember(actor);

  /// Only the original creator, while still an active member, can edit.
  /// Being the group manager grants no rights over others' expenses.
  static bool canEditExpense({required GroupMember? actor, required Expense expense}) {
    return isActiveMember(actor) &&
        actor!.groupId == expense.groupId &&
        actor.userId == expense.createdByUserId &&
        !expense.isVoided;
  }

  /// Voiding follows the same rule as editing.
  static bool canVoidExpense({required GroupMember? actor, required Expense expense}) {
    return canEditExpense(actor: actor, expense: expense);
  }

  static bool canAddMember(GroupMember? actor) => isActiveMember(actor);

  static bool canReviewJoinRequests(GroupMember? actor) => isActiveMember(actor);

  static bool canAddContribution(GroupMember? actor) => isActiveMember(actor);

  static bool canRemoveMember({required GroupMember? actor, required GroupMember target}) {
    return isActiveMember(actor) &&
        actor!.isManager &&
        actor.groupId == target.groupId &&
        target.isActive &&
        target.userId != actor.userId;
  }

  static bool canRegenerateCode(GroupMember? actor) => isActiveMember(actor) && actor!.isManager;
}
