String formatMoney(double value, {bool decimals = true}) {
  final isWhole = value == value.roundToDouble();
  return value.toStringAsFixed(decimals && !isWhole ? 2 : 0);
}

String formatDate(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

String formatChineseDate(DateTime date) => '${date.month}月${date.day}日';

String formatDateTime(DateTime date) {
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  final second = date.second.toString().padLeft(2, '0');
  return '${formatDate(date)} $hour:$minute:$second';
}

String formatShortDate(DateTime date) => '${date.month}月${date.day}日';

DateTime startOfDay(DateTime date) => DateTime(date.year, date.month, date.day);

DateTime endOfDay(DateTime date) =>
    DateTime(date.year, date.month, date.day, 23, 59, 59, 999);

bool isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

bool hasPreciseTime(DateTime billDate, DateTime? recordedAt) {
  if (recordedAt == null || !isSameDay(billDate, recordedAt)) return false;
  return recordedAt.hour != 0 ||
      recordedAt.minute != 0 ||
      recordedAt.second != 0;
}
