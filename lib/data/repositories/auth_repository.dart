import '../models/models.dart';

/// Phone-number + one-time-code authentication.
///
/// Production: Supabase Auth phone OTP. Prototype: [MockAuthRepository],
/// which sends no SMS and accepts a fixed demo code.
abstract interface class AuthRepository {
  AppUser? get currentUser;

  /// Emits the current user immediately, then on every change.
  Stream<AppUser?> authStateChanges();

  /// Starts sign-up or log-in for [phone] (normalized E.164).
  Future<void> requestCode({required String phone, required bool isSignUp});

  /// Verifies the code and signs the user in.
  Future<AppUser> verifyCode({required String phone, required String code, required bool isSignUp});

  /// Completes or updates the signed-in user's profile.
  Future<AppUser> updateProfile({required String name});

  Future<void> signOut();
}
