import 'package:flutter_test/flutter_test.dart';
import 'package:roomeez/core/utils/dates.dart';
import 'package:roomeez/core/utils/money.dart';
import 'package:roomeez/core/utils/phone.dart';
import 'package:roomeez/core/utils/quantity.dart';

void main() {
  group('Money', () {
    test('parses input into integer paisa without floating point', () {
      expect(Money.tryParse('1250'), 125000);
      expect(Money.tryParse('1,250.5'), 125050);
      expect(Money.tryParse('0.1'), 10);
      expect(Money.tryParse('99.99'), 9999);
      expect(Money.tryParse(' 15,000 '), 1500000);
    });

    test('rejects invalid or negative input', () {
      expect(Money.tryParse(''), isNull);
      expect(Money.tryParse('-5'), isNull);
      expect(Money.tryParse('1.234'), isNull);
      expect(Money.tryParse('abc'), isNull);
    });

    test('formats PKR amounts', () {
      expect(Money.format(1500000), 'PKR 15,000');
      expect(Money.format(125050), 'PKR 1,250.50');
      expect(Money.format(-60000), '-PKR 600');
      expect(Money.format(60000, signed: true), '+PKR 600');
      expect(Money.format(0, signed: true), 'PKR 0');
    });

    test('round-trips through the input format', () {
      for (final paisa in [0, 5, 50, 125050, 1500000, 99]) {
        expect(Money.tryParse(Money.toInput(paisa)), paisa);
      }
    });
  });

  group('Quantity', () {
    test('parses decimals into milli-units', () {
      expect(Quantity.tryParse('2'), 2000);
      expect(Quantity.tryParse('1.5'), 1500);
      expect(Quantity.tryParse('0.125'), 125);
      expect(Quantity.tryParse('1.2345'), isNull);
    });

    test('computes line totals exactly', () {
      // 1.5 kg at PKR 240.00 = PKR 360.00
      expect(Quantity.lineTotal(unitPricePaisa: 24000, quantityMilli: 1500), 36000);
      // 3 x PKR 33.33 = PKR 99.99
      expect(Quantity.lineTotal(unitPricePaisa: 3333, quantityMilli: 3000), 9999);
      // 0.333 x PKR 1.00 = 33.3 paisa, rounds to 33
      expect(Quantity.lineTotal(unitPricePaisa: 100, quantityMilli: 333), 33);
    });

    test('formats without trailing zeros', () {
      expect(Quantity.format(2000), '2');
      expect(Quantity.format(1500), '1.5');
      expect(Quantity.format(125), '0.125');
    });
  });

  group('PhoneNumber', () {
    test('normalizes Pakistani mobile formats', () {
      expect(PhoneNumber.normalize('0300 1234567'), '+923001234567');
      expect(PhoneNumber.normalize('03001234567'), '+923001234567');
      expect(PhoneNumber.normalize('+92 300-1234567'), '+923001234567');
      expect(PhoneNumber.normalize('923001234567'), '+923001234567');
      expect(PhoneNumber.normalize('12345'), isNull);
      expect(PhoneNumber.normalize('0421234567'), isNull);
    });

    test('formats for display', () {
      expect(PhoneNumber.format('+923001234567'), '+92 300 1234567');
    });
  });

  group('Periods', () {
    final now = DateTime(2026, 10, 15, 18, 30);

    test('presets resolve to inclusive day ranges', () {
      final last10 = const PeriodFilter(PeriodPreset.last10Days).resolve(now)!;
      expect(last10.start, DateTime(2026, 10, 6));
      expect(last10.end, DateTime(2026, 10, 15));
      expect(last10.dayCount, 10);

      final last15 = const PeriodFilter(PeriodPreset.last15Days).resolve(now)!;
      expect(last15.dayCount, 15);

      final month = const PeriodFilter.thisMonth().resolve(now)!;
      expect(month.start, DateTime(2026, 10, 1));
      expect(const PeriodFilter(PeriodPreset.allTime).resolve(now), isNull);
    });

    test('ranges include both ends', () {
      final range = DateRange(DateTime(2026, 10, 1), DateTime(2026, 10, 15));
      expect(range.contains(DateTime(2026, 10, 1, 23, 59)), isTrue);
      expect(range.contains(DateTime(2026, 10, 15)), isTrue);
      expect(range.contains(DateTime(2026, 10, 16)), isFalse);
      expect(range.contains(DateTime(2026, 9, 30)), isFalse);
    });
  });
}
