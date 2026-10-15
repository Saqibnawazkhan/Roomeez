/// A person with (or reserved for) an account.
///
/// When a member adds someone by phone number before that person has signed
/// up, a placeholder user is created with [isRegistered] = false. When the
/// person later signs up with the same number, the account is linked.
class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.phone,
    required this.isRegistered,
    required this.hasCompletedProfile,
    required this.createdAt,
  });

  final String id;
  final String name;

  /// Normalized E.164 phone number, e.g. `+923001234567`.
  final String phone;
  final bool isRegistered;
  final bool hasCompletedProfile;
  final DateTime createdAt;

  AppUser copyWith({String? name, bool? isRegistered, bool? hasCompletedProfile}) {
    return AppUser(
      id: id,
      name: name ?? this.name,
      phone: phone,
      isRegistered: isRegistered ?? this.isRegistered,
      hasCompletedProfile: hasCompletedProfile ?? this.hasCompletedProfile,
      createdAt: createdAt,
    );
  }
}
