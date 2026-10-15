import 'package:intl/intl.dart';

/// Money helpers.
///
/// All amounts in the app are stored as integer **paisa** (1 PKR = 100 paisa).
/// Never use floating point for money: parse user input straight into paisa
/// and do all arithmetic on integers.
abstract final class Money {
  static const int paisaPerRupee = 100;

  static final NumberFormat _grouping = NumberFormat('#,##0', 'en_US');
  static final RegExp _inputPattern = RegExp(r'^\d{1,9}(\.\d{1,2})?$');

  /// Converts whole rupees to paisa.
  static int rupees(int rupees) => rupees * paisaPerRupee;

  /// Formats [paisa] for display, e.g. `PKR 1,250` or `PKR 1,250.50`.
  ///
  /// With [roundToRupee], the amount is shown to the nearest whole rupee.
  static String format(int paisa, {bool withCurrency = true, bool signed = false, bool roundToRupee = false}) {
    if (roundToRupee) {
      final rupees = (paisa.abs() + paisaPerRupee ~/ 2) ~/ paisaPerRupee;
      paisa = (paisa < 0 ? -rupees : rupees) * paisaPerRupee;
    }
    final abs = paisa.abs();
    final whole = abs ~/ paisaPerRupee;
    final fraction = abs % paisaPerRupee;
    var text = _grouping.format(whole);
    if (fraction != 0) {
      text = '$text.${fraction.toString().padLeft(2, '0')}';
    }
    if (withCurrency) text = 'PKR $text';
    if (paisa < 0) return '-$text';
    if (signed && paisa > 0) return '+$text';
    return text;
  }

  /// Formats [paisa] for pre-filling a text field, e.g. `1250` or `1250.5`.
  static String toInput(int paisa) {
    final whole = paisa ~/ paisaPerRupee;
    final fraction = paisa % paisaPerRupee;
    if (fraction == 0) return '$whole';
    final digits = fraction.toString().padLeft(2, '0');
    return '$whole.${digits.endsWith('0') ? digits[0] : digits}';
  }

  /// Parses user input such as `1,250` or `99.5` into paisa.
  ///
  /// Returns `null` for anything that is not a non-negative amount with at
  /// most two decimal places.
  static int? tryParse(String input) {
    final cleaned = input.replaceAll(',', '').replaceAll(' ', '').trim();
    if (!_inputPattern.hasMatch(cleaned)) return null;
    final parts = cleaned.split('.');
    final whole = int.parse(parts[0]);
    final fraction = parts.length > 1 ? int.parse(parts[1].padRight(2, '0')) : 0;
    return whole * paisaPerRupee + fraction;
  }
}
