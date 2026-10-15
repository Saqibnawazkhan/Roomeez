import '../../core/errors/app_exception.dart';
import '../models/models.dart';
import '../repositories/auth_repository.dart';
import 'mock_store.dart';

/// PROTOTYPE ONLY. No SMS is sent; the code is always [demoCode].
class MockAuthRepository implements AuthRepository {
  MockAuthRepository(this._store);

  static const String demoCode = '123456';

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
  Future<void> requestCode({required String phone, required bool isSignUp}) async {
    await _store.simulateLatency();
    final user = _store.userByPhone(phone);
    final registered = user != null && user.isRegistered;
    if (isSignUp && registered) {
      throw const ConflictException('An account with this number already exists. Log in instead.');
    }
    if (!isSignUp && !registered) {
      throw const NotFoundException('No account found for this number. Sign up first.');
    }
  }

  @override
  Future<AppUser> verifyCode({required String phone, required String code, required bool isSignUp}) async {
    await _store.simulateLatency();
    if (code.trim() != demoCode) {
      throw const ValidationException('Incorrect code. Please try again.');
    }
    var user = _store.userByPhone(phone);
    if (isSignUp) {
      if (user != null && user.isRegistered) {
        throw const ConflictException('An account with this number already exists. Log in instead.');
      }
      // Link a placeholder created when a member added this number, or create
      // a brand-new account.
      user = (user ?? _store.findOrCreateUser(name: '', phone: phone)).copyWith(
        isRegistered: true,
        hasCompletedProfile: false,
      );
      _store.users[user.id] = user;
    } else if (user == null || !user.isRegistered) {
      throw const NotFoundException('No account found for this number. Sign up first.');
    }
    _store.sessionUserId = user.id;
    _store.notify();
    return user;
  }

  @override
  Future<AppUser> updateProfile({required String name}) async {
    await _store.simulateLatency();
    final user = currentUser;
    if (user == null) throw const PermissionDeniedException('Please log in again.');
    final trimmed = name.trim();
    if (trimmed.length < 2) throw const ValidationException('Enter your full name.');
    final updated = user.copyWith(name: trimmed, hasCompletedProfile: true);
    _store.users[user.id] = updated;
    // Keep the name shown in the user's active groups in sync.
    for (final m in _store.members.values.toList()) {
      if (m.userId == user.id && m.isActive) {
        _store.members[m.id] = m.copyWith(displayName: trimmed);
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
