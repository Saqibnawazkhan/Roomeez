/// Errors raised by repositories and services. The UI shows [message] as-is,
/// so keep it short and user-friendly.
sealed class AppException implements Exception {
  const AppException(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// The signed-in user is not allowed to perform the action.
class PermissionDeniedException extends AppException {
  const PermissionDeniedException(super.message);
}

/// A record does not exist (or is not visible to the user).
class NotFoundException extends AppException {
  const NotFoundException(super.message);
}

/// Input failed validation.
class ValidationException extends AppException {
  const ValidationException(super.message);
}

/// The action conflicts with the current state, e.g. already a member.
class ConflictException extends AppException {
  const ConflictException(super.message);
}

/// Returns a user-facing message for any error.
String describeError(Object error) {
  if (error is AppException) return error.message;
  return 'Something went wrong. Please try again.';
}
