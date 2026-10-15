import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/errors/app_exception.dart';
import '../../data/models/group_snapshot.dart';
import '../../data/models/models.dart';

const _signedOut = PermissionDeniedException('Please log in again.');

/// Groups the signed-in user is an active member of.
final myGroupsProvider = StreamProvider<List<Group>>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return Stream.value(const []);
  return ref.watch(groupRepositoryProvider).watchGroupsForUser(userId);
});

/// Join requests the signed-in user has sent.
final myJoinRequestsProvider = StreamProvider<List<JoinRequest>>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return Stream.value(const []);
  return ref.watch(groupRepositoryProvider).watchMyJoinRequests(userId);
});

final groupProvider = StreamProvider.family<Group, String>((ref, groupId) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return Stream.error(_signedOut);
  return ref.watch(groupRepositoryProvider).watchGroup(groupId: groupId, viewerUserId: userId);
});

final groupMembersProvider = StreamProvider.family<List<GroupMember>, String>((ref, groupId) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return Stream.error(_signedOut);
  return ref.watch(groupRepositoryProvider).watchMembers(groupId: groupId, viewerUserId: userId);
});

final groupExpensesProvider = StreamProvider.family<List<Expense>, String>((ref, groupId) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return Stream.error(_signedOut);
  return ref.watch(expenseRepositoryProvider).watchExpenses(groupId: groupId, viewerUserId: userId);
});

final groupContributionsProvider = StreamProvider.family<List<Contribution>, String>((ref, groupId) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return Stream.error(_signedOut);
  return ref.watch(contributionRepositoryProvider).watchContributions(groupId: groupId, viewerUserId: userId);
});

final pendingJoinRequestsProvider = StreamProvider.family<List<JoinRequest>, String>((ref, groupId) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return Stream.error(_signedOut);
  return ref.watch(groupRepositoryProvider).watchPendingJoinRequests(groupId: groupId, viewerUserId: userId);
});

/// Everything a group screen needs, combined into one value.
final groupSnapshotProvider = Provider.family<AsyncValue<GroupSnapshot>, String>((ref, groupId) {
  final userId = ref.watch(currentUserIdProvider);
  final group = ref.watch(groupProvider(groupId));
  final members = ref.watch(groupMembersProvider(groupId));
  final expenses = ref.watch(groupExpensesProvider(groupId));
  final contributions = ref.watch(groupContributionsProvider(groupId));

  for (final value in <AsyncValue<Object>>[group, members, expenses, contributions]) {
    if (value.hasError) {
      return AsyncValue.error(value.error!, value.stackTrace ?? StackTrace.current);
    }
  }
  if (userId == null || !group.hasValue || !members.hasValue || !expenses.hasValue || !contributions.hasValue) {
    return const AsyncValue.loading();
  }
  return AsyncValue.data(
    GroupSnapshot(
      group: group.requireValue,
      members: members.requireValue,
      expenses: expenses.requireValue,
      contributions: contributions.requireValue,
      viewerUserId: userId,
    ),
  );
});
