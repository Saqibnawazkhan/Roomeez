/// A person with (or reserved for) an account.
///
/// People sign in with Google or an emailed code, so the verified [email]
/// identifies them. When a member adds someone by email before that person
/// has signed in, a placeholder is created with [isRegistered] = false and is
/// linked when they first sign in with that email. Members added without an
/// email are "offline" members who are never linked to an account.
class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.isRegistered,
    required this.hasCompletedProfile,
    required this.createdAt,
    this.email,
    this.phone,
  });

  final String id;
  final String name;

  /// Verified sign-in email, lower case. `null` for offline members.
  final String? email;

  /// Optional contact number (E.164, e.g. `+923001234567`). Not verified and
  /// never used to sign in.
  final String? phone;
  final bool isRegistered;
  final bool hasCompletedProfile;
  final DateTime createdAt;

  AppUser copyWith({String? name, bool? isRegistered, bool? hasCompletedProfile}) {
    return AppUser(
      id: id,
      name: name ?? this.name,
      email: email,
      phone: phone,
      isRegistered: isRegistered ?? this.isRegistered,
      hasCompletedProfile: hasCompletedProfile ?? this.hasCompletedProfile,
      createdAt: createdAt,
    );
  }

  /// A copy with a new name and phone (`null` clears the phone).
  AppUser withProfile({required String name, required String? phone}) {
    return AppUser(
      id: id,
      name: name,
      email: email,
      phone: phone,
      isRegistered: isRegistered,
      hasCompletedProfile: true,
      createdAt: createdAt,
    );
  }
}
