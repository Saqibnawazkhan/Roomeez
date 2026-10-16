/// Pakistani mobile number helpers. Numbers are stored in E.164 form,
/// e.g. `+923001234567`.
abstract final class PhoneNumber {
  static final RegExp _separators = RegExp(r'[\s\-()]');

  /// Normalizes `0300 1234567`, `923001234567` or `+92 300 1234567` to
  /// `+923001234567`. Returns `null` if the input is not a valid PK mobile.
  static String? normalize(String input) {
    final digits = input.replaceAll(_separators, '');
    if (RegExp(r'^03\d{9}$').hasMatch(digits)) return '+92${digits.substring(1)}';
    if (RegExp(r'^\+923\d{9}$').hasMatch(digits)) return digits;
    if (RegExp(r'^923\d{9}$').hasMatch(digits)) return '+$digits';
    if (RegExp(r'^00923\d{9}$').hasMatch(digits)) return '+${digits.substring(2)}';
    return null;
  }

  /// For optional phone fields: an empty value is fine (`null`), otherwise it
  /// must be a valid number.
  static String? optionalFieldError(String? input) {
    final text = (input ?? '').trim();
    if (text.isEmpty || normalize(text) != null) return null;
    return 'Enter a valid number, e.g. 0300 1234567';
  }

  /// The normalized number, or `null` when the optional field is empty.
  static String? normalizeOptional(String input) => input.trim().isEmpty ? null : normalize(input);

  /// Formats a normalized number for display: `+92 300 1234567`.
  static String format(String normalized) {
    if (!RegExp(r'^\+923\d{9}$').hasMatch(normalized)) return normalized;
    return '+92 ${normalized.substring(3, 6)} ${normalized.substring(6)}';
  }
}
