import '../models/models.dart';

/// Sign-in with Google or a code sent by email. Both verify the email
/// address, which is what links a person to the groups they were added to.
///
/// Production: Supabase Auth. Demo: [MockAuthRepository], which sends nothing
/// and accepts a fixed code.
abstract interface class AuthRepository {
  AppUser? get currentUser;

  /// Emits the current user immediately, then on every change.
  Stream<AppUser?> authStateChanges();

  /// Whether "Continue with Google" can be offered.
  bool get supportsGoogle;

  Future<AppUser> signInWithGoogle();

  /// Emails a one-time sign-in code to [email].
  Future<void> sendEmailCode(String email);

  Future<AppUser> verifyEmailCode({required String email, required String code});

  /// Completes or updates the profile. [phone] is optional (normalized E.164)
  /// and `null` removes it.
  Future<AppUser> updateProfile({required String name, String? phone});

  Future<void> signOut();
}
