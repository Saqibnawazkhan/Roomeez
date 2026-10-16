import 'dart:async';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/errors/app_exception.dart';
import '../models/models.dart';
import '../repositories/auth_repository.dart';
import 'row_mappers.dart';
import 'supabase_errors.dart';

/// Google or email-code sign-in with Supabase Auth. The `profiles` row is
/// created (or linked to a placeholder a group member added by email) by a
/// database trigger.
class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client, {required String googleWebClientId}) : _googleWebClientId = googleWebClientId;

  final SupabaseClient _client;
  final String _googleWebClientId;
  final StreamController<AppUser?> _changes = StreamController<AppUser?>.broadcast();
  StreamSubscription<AuthState>? _subscription;
  Future<void>? _googleReady;
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

  Future<AppUser> _signedInUser() async {
    await _reload();
    final user = _user;
    if (user == null) throw const NotFoundException('Your profile could not be loaded. Please try again.');
    return user;
  }

  @override
  AppUser? get currentUser => _user;

  @override
  Stream<AppUser?> authStateChanges() async* {
    yield _user;
    yield* _changes.stream;
  }

  @override
  bool get supportsGoogle => _googleWebClientId.isNotEmpty;

  @override
  Future<AppUser> signInWithGoogle() async {
    final google = GoogleSignIn.instance;
    final GoogleSignInAccount account;
    try {
      await (_googleReady ??= google.initialize(serverClientId: _googleWebClientId));
      account = await google.authenticate();
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) {
        throw const ValidationException('Google sign-in was cancelled.');
      }
      throw ValidationException('Google sign-in failed: ${error.description ?? error.code.name}');
    }
    final idToken = account.authentication.idToken;
    if (idToken == null) throw const ValidationException('Google didn\'t return a sign-in token. Please try again.');
    return guarded(() async {
      await _client.auth.signInWithIdToken(provider: OAuthProvider.google, idToken: idToken);
      return _signedInUser();
    });
  }

  @override
  Future<void> sendEmailCode(String email) {
    return guarded(() => _client.auth.signInWithOtp(email: email.trim().toLowerCase(), shouldCreateUser: true));
  }

  @override
  Future<AppUser> verifyEmailCode({required String email, required String code}) {
    return guarded(() async {
      await _client.auth.verifyOTP(email: email.trim().toLowerCase(), token: code.trim(), type: OtpType.email);
      return _signedInUser();
    });
  }

  @override
  Future<AppUser> updateProfile({required String name, String? phone}) {
    return guarded(() async {
      await _client.rpc<void>('update_my_profile', params: {'p_name': name, 'p_phone': phone});
      return _signedInUser();
    });
  }

  @override
  Future<void> signOut() async {
    // Only this device's session; other devices stay signed in.
    await guarded(() => _client.auth.signOut(scope: SignOutScope.local));
    if (supportsGoogle) {
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {
        // Not signed in with Google on this device.
      }
    }
    _set(null);
  }
}
