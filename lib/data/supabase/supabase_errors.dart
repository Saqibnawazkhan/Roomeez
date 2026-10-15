import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/errors/app_exception.dart';

/// Turns Supabase/PostgREST errors into the app's [AppException]s.
///
/// The database functions raise custom SQLSTATEs with user-facing messages
/// (see supabase/migrations): RZ401, RZ403, RZ404, RZ409, RZ422.
AppException mapSupabaseError(Object error) {
  if (error is AppException) return error;
  if (error is PostgrestException) {
    final message = error.message;
    switch (error.code) {
      case 'RZ401':
        return const PermissionDeniedException('Please log in again.');
      case 'RZ403':
        return PermissionDeniedException(message);
      case 'RZ404':
        return NotFoundException(message);
      case 'RZ409':
        return ConflictException(message);
      case 'RZ422':
        return ValidationException(message);
      case '42501':
        return const PermissionDeniedException('You don\'t have permission to do that.');
    }
    return const NetworkException('Something went wrong on the server. Please try again.');
  }
  if (error is AuthRetryableFetchException) return const NetworkException();
  if (error is AuthException) {
    final text = '${error.code ?? ''} ${error.message}'.toLowerCase();
    if (text.contains('signups not allowed') || text.contains('otp_disabled') || text.contains('user not found')) {
      return const NotFoundException('No account found for this number. Sign up first.');
    }
    if (text.contains('expired') || text.contains('invalid')) {
      return const ValidationException('Incorrect or expired code. Please try again.');
    }
    if (text.contains('phone') && (text.contains('provider') || text.contains('disabled'))) {
      return const ValidationException('Phone login isn\'t set up on the server yet.');
    }
    if (text.contains('rate') || text.contains('security purposes')) {
      return const ValidationException('Too many attempts. Please wait a minute and try again.');
    }
    return ValidationException(error.message);
  }
  final text = error.toString();
  if (text.contains('SocketException') || text.contains('ClientException') || text.contains('Failed host lookup')) {
    return const NetworkException();
  }
  return const NetworkException('Something went wrong. Please try again.');
}

/// Runs [action] and rethrows any failure as an [AppException].
Future<T> guarded<T>(Future<T> Function() action) async {
  try {
    return await action();
  } catch (error) {
    throw mapSupabaseError(error);
  }
}
