/// Item quantities are stored as integer thousandths ("milli-units") so that
/// values like 1.5 kg work without floating point.
abstract final class Quantity {
  static const int scale = 1000;

  static final RegExp _inputPattern = RegExp(r'^\d{1,6}(\.\d{1,3})?$');

  /// Converts a whole quantity to milli-units.
  static int units(int units) => units * scale;

  /// Parses input such as `2` or `1.5`. Returns `null` when invalid.
  static int? tryParse(String input) {
    final cleaned = input.replaceAll(' ', '').trim();
    if (!_inputPattern.hasMatch(cleaned)) return null;
    final parts = cleaned.split('.');
    final whole = int.parse(parts[0]);
    final fraction = parts.length > 1 ? int.parse(parts[1].padRight(3, '0')) : 0;
    return whole * scale + fraction;
  }

  /// Formats milli-units for display, trimming trailing zeros: `1500` -> `1.5`.
  static String format(int milli) {
    final whole = milli ~/ scale;
    final fraction = milli % scale;
    if (fraction == 0) return '$whole';
    var digits = fraction.toString().padLeft(3, '0');
    while (digits.endsWith('0')) {
      digits = digits.substring(0, digits.length - 1);
    }
    return '$whole.$digits';
  }

  /// Line total in paisa for [quantityMilli] units at [unitPricePaisa] each,
  /// rounded half-up to the nearest paisa using integer arithmetic only.
  static int lineTotal({required int unitPricePaisa, required int quantityMilli}) {
    return (unitPricePaisa * quantityMilli + scale ~/ 2) ~/ scale;
  }
}
