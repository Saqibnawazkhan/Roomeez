import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/errors/app_exception.dart';
import '../models/models.dart';
import '../repositories/auth_repository.dart';
import 'row_mappers.dart';
import 'supabase_errors.dart';

/// Phone + SMS code sign-in with Supabase Auth. The `profiles` row is created
/// (or linked to a placeholder added by a group member) by a database trigger.
class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);

  final SupabaseClient _client;
  final StreamController<AppUser?> _changes = StreamController<AppUser?>.broadcast();
  StreamSubscription<AuthState>? _subscription;
  AppUser? _user;

  /// Loads the profile of a saved session. Call once before the app starts so
  /// the router knows whether someone is signed in.
  Future<void> init() async {
    await _reload();
    _subscription = _client.auth.onAuthStateChange.listen((state) {
      if (state.event == AuthChangeEvent.signedOut) {
        _set(null);
      } else if (state.event == AuthChangeEvent.signedIn || state.event == AuthChangeEvent.userUpdated) {
        _reload();
      }
    });
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    await _changes.close();
  }

  Future<void> _reload() async {
    if (_client.auth.currentSession == null) {
      _set(null);
      return;
    }
    try {
      final row = await _client.from('profiles').select().maybeSingle();
      _set(row == null ? null : RowMappers.profile(row));
    } catch (_) {
      // Keep the last known profile when offline.
    }
  }

  void _set(AppUser? user) {
    final before = _user;
    _user = user;
    final changed =
        before?.id != user?.id ||
        before?.name != user?.name ||
        before?.hasCompletedProfile != user?.hasCompletedProfile;
    if (changed && !_changes.isClosed) _changes.add(user);
  }

  @override
  AppUser? get currentUser => _user;

  @override
  Stream<AppUser?> authStateChanges() async* {
    yield _user;
    yield* _changes.stream;
  }

  @override
  Future<void> requestCode({required String phone, required bool isSignUp}) {
    // Signing up with a number that already has an account simply logs in.
    return guarded(() => _client.auth.signInWithOtp(phone: phone, shouldCreateUser: isSignUp));
  }

  @override
  Future<AppUser> verifyCode({required String phone, required String code, required bool isSignUp}) {
    return guarded(() async {
      await _client.auth.verifyOTP(phone: phone, token: code.trim(), type: OtpType.sms);
      await _reload();
      final user = _user;
      if (user == null) throw const NotFoundException('Your profile could not be loaded. Please try again.');
      return user;
    });
  }

  @override
  Future<AppUser> updateProfile({required String name}) {
    return guarded(() async {
      await _client.rpc<void>('update_my_profile', params: {'p_name': name});
      await _reload();
      return _user!;
    });
  }

  @override
  Future<void> signOut() async {
    await guarded(() => _client.auth.signOut());
    _set(null);
  }
}
