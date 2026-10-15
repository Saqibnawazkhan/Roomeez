enum ContributionType {
  initial('Initial contribution'),
  topUp('Top-up');

  const ContributionType(this.label);
  final String label;
}

/// Money a member puts into the group fund. A contribution is **not** an
/// expense: it increases the fund that expenses can later be paid from.
class Contribution {
  const Contribution({
    required this.id,
    required this.groupId,
    required this.memberUserId,
    required this.amountPaisa,
    required this.date,
    required this.type,
    required this.recordedByUserId,
    required this.createdAt,
    this.note,
  });

  final String id;
  final String groupId;
  final String memberUserId;
  final int amountPaisa;
  final DateTime date;
  final ContributionType type;
  final String recordedByUserId;
  final DateTime createdAt;
  final String? note;
}
