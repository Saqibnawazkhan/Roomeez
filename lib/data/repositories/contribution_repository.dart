import '../models/models.dart';

/// Group fund contributions. Contributions are kept separate from expenses.
abstract interface class ContributionRepository {
  Stream<List<Contribution>> watchContributions({required String groupId, required String viewerUserId});

  /// Any active member can record a contribution for an active member.
  Future<Contribution> addContribution({
    required String actorUserId,
    required String groupId,
    required String memberUserId,
    required int amountPaisa,
    required DateTime date,
    String? note,
  });
}
