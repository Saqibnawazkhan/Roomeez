/// A shared-living group, e.g. "Gulberg Apartment 4B".
class Group {
  const Group({
    required this.id,
    required this.name,
    required this.code,
    required this.createdByUserId,
    required this.createdAt,
    this.description,
  });

  final String id;
  final String name;
  final String? description;

  /// Short join code shown to members, e.g. `RMZ4B7`.
  final String code;
  final String createdByUserId;
  final DateTime createdAt;

  Group copyWith({String? name, String? description, String? code}) {
    return Group(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      code: code ?? this.code,
      createdByUserId: createdByUserId,
      createdAt: createdAt,
    );
  }
}

/// The limited information a non-member sees when looking up a join code.
/// It deliberately contains no expenses or member details.
class GroupPreview {
  const GroupPreview({
    required this.groupId,
    required this.name,
    required this.activeMemberCount,
    required this.isAlreadyMember,
    this.pendingRequestId,
  });

  final String groupId;
  final String name;
  final int activeMemberCount;
  final bool isAlreadyMember;
  final String? pendingRequestId;
}
