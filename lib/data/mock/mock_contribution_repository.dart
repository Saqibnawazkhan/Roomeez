import '../../core/errors/app_exception.dart';
import '../../core/utils/dates.dart';
import '../models/models.dart';
import '../repositories/contribution_repository.dart';
import '../services/permission_policy.dart';
import 'mock_store.dart';

/// PROTOTYPE ONLY.
class MockContributionRepository implements ContributionRepository {
  MockContributionRepository(this._store);

  final MockStore _store;

  @override
  Stream<List<Contribution>> watchContributions({required String groupId, required String viewerUserId}) {
    return _store.watch(() {
      _store.requireActiveMember(groupId, viewerUserId);
      return _store.contributions.values.where((c) => c.groupId == groupId).toList()
        ..sort((a, b) => b.date.compareTo(a.date));
    });
  }

  @override
  Future<Contribution> addContribution({
    required String actorUserId,
    required String groupId,
    required String memberUserId,
    required int amountPaisa,
    required DateTime date,
    String? note,
  }) async {
    await _store.simulateLatency();
    final actor = _store.requireActiveMember(groupId, actorUserId);
    if (!PermissionPolicy.canAddContribution(actor)) {
      throw const PermissionDeniedException('You can\'t record contributions for this group.');
    }
    if (_store.activeMembership(groupId, memberUserId) == null) {
      throw const ValidationException('Contributions can only be recorded for active members.');
    }
    if (amountPaisa <= 0) throw const ValidationException('Enter an amount above zero.');
    if (dateOnly(date).isAfter(_store.todayDate())) {
      throw const ValidationException('The date can\'t be in the future.');
    }
    final trimmed = note?.trim();
    final contribution = Contribution(
      id: _store.newId('contribution'),
      groupId: groupId,
      memberUserId: memberUserId,
      amountPaisa: amountPaisa,
      date: dateOnly(date),
      type: ContributionType.topUp,
      recordedByUserId: actorUserId,
      createdAt: _store.now(),
      note: trimmed == null || trimmed.isEmpty ? null : trimmed,
    );
    _store.contributions[contribution.id] = contribution;
    _store.notify();
    return contribution;
  }
}
