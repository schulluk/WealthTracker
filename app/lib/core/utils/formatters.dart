import 'package:intl/intl.dart';

/// Currency formatter for displaying monetary values.
/// Displays whole numbers only (floored).
String formatCurrency(double value, String currency) {
  final format = NumberFormat.currency(
    locale: 'de_CH',
    symbol: currency,
    decimalDigits: 0,
  );
  return format.format(value.floor());
}

/// Compact currency formatter for large values.
String formatCurrencyCompact(double value, String currency) {
  final format = NumberFormat.compactCurrency(
    locale: 'de_CH',
    symbol: currency,
    decimalDigits: 0,
  );
  return format.format(value);
}

/// Compact number formatter for chart axis (no currency symbol).
String formatChartAxisValue(double value) {
  if (value >= 1000000) {
    final m = value / 1000000;
    // Use enough decimals to avoid duplicate labels (e.g. 1.05M vs 1.1M)
    final s = m.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
    return '${s}M';
  } else if (value >= 1000) {
    return '${(value / 1000).toStringAsFixed(0)}K';
  }
  return value.toStringAsFixed(0);
}

/// Date formatter for snapshot dates.
/// [formatSetting] can be: 'system', 'dmy', 'mdy', 'ymd'
String formatDate(DateTime date, [String formatSetting = 'system']) {
  final pattern = _getDatePattern(formatSetting);
  return DateFormat(pattern).format(date);
}

/// Get the date pattern for a given format setting.
String _getDatePattern(String formatSetting) {
  switch (formatSetting) {
    case 'dmy':
      return 'dd.MM.yyyy';
    case 'mdy':
      return 'MM/dd/yyyy';
    case 'ymd':
      return 'yyyy-MM-dd';
    case 'system':
    default:
      // Use system locale - yMd gives locale-appropriate format
      return 'yMd';
  }
}

/// Get display name for a date format setting.
String getDateFormatDisplayName(String formatSetting) {
  switch (formatSetting) {
    case 'dmy':
      return 'DD.MM.YYYY';
    case 'mdy':
      return 'MM/DD/YYYY';
    case 'ymd':
      return 'YYYY-MM-DD';
    case 'system':
    default:
      return 'System Default';
  }
}

/// Short date formatter for compact displays (e.g., "Jan 31" or "31 Jan").
String formatDateShort(DateTime date) {
  return DateFormat('d MMM').format(date);
}

/// Date formatter for API requests.
String formatDateForApi(DateTime date) {
  return DateFormat('yyyy-MM-dd').format(date);
}

/// Percentage formatter.
String formatPercentage(double value) {
  final sign = value >= 0 ? '+' : '';
  return '$sign${value.toStringAsFixed(2)}%';
}

/// Smart date formatter with relative time for recent dates.
/// Returns "today, date", "yesterday, date", "X days ago, date" for recent,
/// or just the date for older dates.
String formatDateSmart(DateTime date, [String formatSetting = 'system']) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final dateOnly = DateTime(date.year, date.month, date.day);
  final difference = today.difference(dateOnly).inDays;

  final formattedDate = formatDate(date, formatSetting);

  if (difference == 0) {
    return 'today, $formattedDate';
  } else if (difference == 1) {
    return 'yesterday, $formattedDate';
  } else if (difference >= 2 && difference <= 6) {
    return '$difference days ago, $formattedDate';
  } else if (difference == 7) {
    return '1 week ago, $formattedDate';
  } else {
    return formattedDate;
  }
}
