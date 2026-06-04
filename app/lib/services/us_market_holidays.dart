/// Calculates US stock market (NYSE) holidays purely from the calendar,
/// with no external service.
///
/// Used to shift sync reminder notifications off non-trading days. Only
/// holidays that can be derived from simple rules are included:
/// fixed dates (with weekend observance), nth-weekday-of-month holidays,
/// and Good Friday (derived from Easter via the Computus algorithm).
class UsMarketHolidays {
  const UsMarketHolidays._();

  /// Whether [date] (compared by year/month/day) is a US market holiday.
  static bool isHoliday(DateTime date) {
    for (final holiday in _holidaysForYear(date.year)) {
      if (holiday.month == date.month && holiday.day == date.day) {
        return true;
      }
    }
    return false;
  }

  /// All observed market holidays for [year].
  static List<DateTime> _holidaysForYear(int year) {
    return [
      _newYear(year), // New Year's Day (Jan 1)
      _nthWeekdayOfMonth(year, 1, DateTime.monday, 3), // MLK Day
      _nthWeekdayOfMonth(year, 2, DateTime.monday, 3), // Presidents' Day
      _goodFriday(year), // Good Friday (Easter - 2 days)
      _lastWeekdayOfMonth(year, 5, DateTime.monday), // Memorial Day
      _observed(DateTime(year, 6, 19)), // Juneteenth
      _observed(DateTime(year, 7, 4)), // Independence Day
      _nthWeekdayOfMonth(year, 9, DateTime.monday, 1), // Labor Day
      _nthWeekdayOfMonth(year, 11, DateTime.thursday, 4), // Thanksgiving
      _observed(DateTime(year, 12, 25)), // Christmas
    ];
  }

  /// Federal observance: a holiday on Saturday is observed the preceding
  /// Friday; on Sunday, the following Monday.
  static DateTime _observed(DateTime date) {
    if (date.weekday == DateTime.saturday) {
      return date.subtract(const Duration(days: 1));
    }
    if (date.weekday == DateTime.sunday) {
      return date.add(const Duration(days: 1));
    }
    return date;
  }

  /// New Year's Day. Only the Sunday->Monday observance applies; when Jan 1
  /// falls on a Saturday the market is not closed for it (and the weekend is
  /// skipped anyway), so we avoid shifting into the previous year.
  static DateTime _newYear(int year) {
    final date = DateTime(year, 1, 1);
    if (date.weekday == DateTime.sunday) {
      return date.add(const Duration(days: 1));
    }
    return date;
  }

  /// The [n]th [weekday] of [month] (e.g. 3rd Monday). [weekday] uses
  /// [DateTime.monday]..[DateTime.sunday].
  static DateTime _nthWeekdayOfMonth(int year, int month, int weekday, int n) {
    final first = DateTime(year, month, 1);
    final offset = (weekday - first.weekday + 7) % 7;
    return DateTime(year, month, 1 + offset + (n - 1) * 7);
  }

  /// The last [weekday] of [month].
  static DateTime _lastWeekdayOfMonth(int year, int month, int weekday) {
    final last = DateTime(year, month + 1, 0); // day 0 -> last day of month
    final offset = (last.weekday - weekday + 7) % 7;
    return DateTime(year, month, last.day - offset);
  }

  /// Good Friday is two days before Easter Sunday.
  static DateTime _goodFriday(int year) {
    return _easterSunday(year).subtract(const Duration(days: 2));
  }

  /// Easter Sunday via the Anonymous Gregorian algorithm (Computus).
  static DateTime _easterSunday(int year) {
    final a = year % 19;
    final b = year ~/ 100;
    final c = year % 100;
    final d = b ~/ 4;
    final e = b % 4;
    final f = (b + 8) ~/ 25;
    final g = (b - f + 1) ~/ 3;
    final h = (19 * a + b - d - g + 15) % 30;
    final i = c ~/ 4;
    final k = c % 4;
    final l = (32 + 2 * e + 2 * i - h - k) % 7;
    final m = (a + 11 * h + 22 * l) ~/ 451;
    final month = (h + l - 7 * m + 114) ~/ 31;
    final day = ((h + l - 7 * m + 114) % 31) + 1;
    return DateTime(year, month, day);
  }
}
