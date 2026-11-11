import 'package:intl/intl.dart';

/// Formats a byte count the way Android's storage settings do (1 KB is
/// 1000 bytes), for example `1.4 GB` or `830 KB`.
String formatBytes(int bytes, [String? locale]) {
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1000 && unit < units.length - 1) {
    value /= 1000;
    unit++;
  }
  final number =
      (NumberFormat.decimalPattern(locale)
            ..minimumFractionDigits = 0
            ..maximumFractionDigits = unit == 0 || value >= 100 ? 0 : 1)
          .format(value);
  return '$number ${units[unit]}';
}

/// A whole number with grouping, for example `12,345`.
String formatCount(int count, [String? locale]) =>
    NumberFormat.decimalPattern(locale).format(count);

/// A date in the user's locale and time zone, for example `3 Mar 2024`.
String formatDate(DateTime time, [String? locale]) =>
    DateFormat.yMMMd(locale).format(time.toLocal());

/// A date and time in the user's locale and time zone, for example
/// `3 Mar 2024, 14:05`.
String formatDateTime(DateTime time, [String? locale]) =>
    DateFormat.yMMMd(locale).add_Hm().format(time.toLocal());

/// A length of time as a player shows it: `0:07`, `3:25` or `1:02:09`.
String formatDuration(Duration duration) {
  final total = duration.isNegative ? 0 : duration.inSeconds;
  final hours = total ~/ 3600;
  final minutes = (total % 3600) ~/ 60;
  final seconds = (total % 60).toString().padLeft(2, '0');
  return hours > 0
      ? '$hours:${minutes.toString().padLeft(2, '0')}:$seconds'
      : '$minutes:$seconds';
}
