import 'package:intl/intl.dart';

/// Strips the time component, keeping the local calendar day.
DateTime dateOnly(DateTime value) => DateTime(value.year, value.month, value.day);

/// Today's date (no time component).
DateTime today() => dateOnly(DateTime.now());

/// An inclusive range of calendar days.
class DateRange {
  DateRange(DateTime start, DateTime end)
    : start = dateOnly(start),
      end = dateOnly(end),
      assert(!dateOnly(end).isBefore(dateOnly(start)), 'end before start');

  final DateTime start;
  final DateTime end;

  bool contains(DateTime value) {
    final day = dateOnly(value);
    return !day.isBefore(start) && !day.isAfter(end);
  }

  /// Number of calendar days in the range, inclusive.
  int get dayCount {
    final s = DateTime.utc(start.year, start.month, start.day);
    final e = DateTime.utc(end.year, end.month, end.day);
    return e.difference(s).inDays + 1;
  }

  @override
  bool operator ==(Object other) => other is DateRange && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => AppDates.range(this);
}

/// Period presets used by the dashboard, expense list and reports.
enum PeriodPreset {
  thisMonth('This month'),
  last15Days('Last 15 days'),
  last10Days('Last 10 days'),
  allTime('All time'),
  custom('Custom');

  const PeriodPreset(this.label);
  final String label;
}

/// A selected period: a preset, or a custom range.
class PeriodFilter {
  const PeriodFilter(this.preset, {this.customRange});

  const PeriodFilter.thisMonth() : this(PeriodPreset.thisMonth);

  final PeriodPreset preset;
  final DateRange? customRange;

  /// Resolves the filter to a concrete range. `null` means "all time".
  DateRange? resolve([DateTime? now]) {
    final day = dateOnly(now ?? DateTime.now());
    switch (preset) {
      case PeriodPreset.thisMonth:
        return DateRange(DateTime(day.year, day.month), day);
      case PeriodPreset.last15Days:
        return DateRange(DateTime(day.year, day.month, day.day - 14), day);
      case PeriodPreset.last10Days:
        return DateRange(DateTime(day.year, day.month, day.day - 9), day);
      case PeriodPreset.allTime:
        return null;
      case PeriodPreset.custom:
        return customRange;
    }
  }

  String describe([DateTime? now]) {
    final range = resolve(now);
    return range == null ? 'All time' : AppDates.range(range);
  }

  @override
  bool operator ==(Object other) => other is PeriodFilter && other.preset == preset && other.customRange == customRange;

  @override
  int get hashCode => Object.hash(preset, customRange);
}

/// Display formats for dates. Uses `en_US`, which intl ships by default.
abstract final class AppDates {
  static final DateFormat _day = DateFormat('d MMM yyyy');
  static final DateFormat _short = DateFormat('d MMM');
  static final DateFormat _weekday = DateFormat('EEE, d MMM');
  static final DateFormat _dateTime = DateFormat('d MMM yyyy, h:mm a');
  static final DateFormat _iso = DateFormat('yyyy-MM-dd');
  static final DateFormat _month = DateFormat('MMM yyyy');

  /// `15 Oct 2026`
  static String day(DateTime value) => _day.format(value);

  /// `15 Oct`
  static String short(DateTime value) => _short.format(value);

  /// `Wed, 15 Oct`
  static String weekday(DateTime value) => _weekday.format(value);

  /// `15 Oct 2026, 3:45 PM`
  static String dateTime(DateTime value) => _dateTime.format(value);

  /// `Oct 2026`
  static String month(DateTime value) => _month.format(value);

  /// `2026-10-15`, used in URLs.
  static String iso(DateTime value) => _iso.format(value);

  static DateTime? tryParseIso(String? value) {
    if (value == null) return null;
    try {
      return _iso.parseStrict(value);
    } on FormatException {
      return null;
    }
  }

  /// `Today`, `Yesterday` or `Wed, 15 Oct`.
  static String relativeDay(DateTime value, [DateTime? now]) {
    final day = dateOnly(value);
    final current = dateOnly(now ?? DateTime.now());
    if (day == current) return 'Today';
    if (day == DateTime(current.year, current.month, current.day - 1)) {
      return 'Yesterday';
    }
    return day.year == current.year ? weekday(day) : AppDates.day(day);
  }

  /// `1 Oct – 15 Oct 2026` (or full dates across years).
  static String range(DateRange range) {
    if (range.start == range.end) return day(range.start);
    if (range.start.year == range.end.year) {
      return '${short(range.start)} – ${day(range.end)}';
    }
    return '${day(range.start)} – ${day(range.end)}';
  }
}
