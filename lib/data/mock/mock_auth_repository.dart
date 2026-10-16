import '../../core/errors/app_exception.dart';
import '../models/models.dart';
import '../repositories/auth_repository.dart';
import 'mock_store.dart';

/// DEMO ONLY. No email is sent; the code is always [demoCode]. "Continue with
/// Google" signs in a fixed demo Google account.
class MockAuthRepository implements AuthRepository {
  MockAuthRepository(this._store);

  static const String demoCode = '123456';
  static const String demoGoogleEmail = 'sara.khan@gmail.com';

  static final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  final MockStore _store;

  @override
  AppUser? get currentUser {
    final id = _store.sessionUserId;
    return id == null ? null : _store.users[id];
  }

  @override
  Stream<AppUser?> authStateChanges() {
    return _store
        .watch(() => currentUser)
        .distinct((a, b) => a?.id == b?.id && a?.name == b?.name && a?.hasCompletedProfile == b?.hasCompletedProfile);
  }

  @override
  bool get supportsGoogle => true;

  @override
  Future<AppUser> signInWithGoogle() async {
    await _store.simulateLatency();
    return _signIn(demoGoogleEmail, googleName: 'Sara Khan');
  }

  @override
  Future<void> sendEmailCode(String email) async {
    await _store.simulateLatency();
    if (!_emailPattern.hasMatch(email.trim())) {
      throw const ValidationException('Enter a valid email address.');
    }
  }

  @override
  Future<AppUser> verifyEmailCode({required String email, required String code}) async {
    await _store.simulateLatency();
    if (code.trim() != demoCode) {
      throw const ValidationException('Incorrect code. Please try again.');
    }
    return _signIn(email);
  }

  /// Links a placeholder added by a group member, or creates a new account.
  AppUser _signIn(String email, {String? googleName}) {
    var user = _store.findOrCreateMemberUser(name: googleName ?? '', email: email);
    if (!user.isRegistered) {
      user = user.copyWith(isRegistered: true, name: user.name.isEmpty ? googleName : null);
      _store.users[user.id] = user;
    }
    _store.sessionUserId = user.id;
    _store.notify();
    return user;
  }

  @override
  Future<AppUser> updateProfile({required String name, String? phone}) async {
    await _store.simulateLatency();
    final user = currentUser;
    if (user == null) throw const PermissionDeniedException('Please log in again.');
    final trimmed = name.trim();
    if (trimmed.length < 2) throw const ValidationException('Enter your full name.');
    final updated = user.withProfile(name: trimmed, phone: phone);
    _store.users[user.id] = updated;
    // Keep the name and number shown in the user's active groups in sync.
    for (final m in _store.members.values.toList()) {
      if (m.userId == user.id && m.isActive) {
        _store.members[m.id] = m.withContact(displayName: trimmed, phone: phone);
      }
    }
    _store.notify();
    return updated;
  }

  @override
  Future<void> signOut() async {
    _store.sessionUserId = null;
    _store.notify();
  }
}
