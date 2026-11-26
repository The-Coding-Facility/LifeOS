/// Datum kurz und deutsch: `heute 14:05`, `gestern`, `26.11.2026`.
String formatShortDate(DateTime time, {DateTime? now}) {
  final local = time.toLocal();
  final today = (now ?? DateTime.now()).toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  final sameDay = local.year == today.year && local.month == today.month && local.day == today.day;
  if (sameDay) return 'heute ${two(local.hour)}:${two(local.minute)}';
  final yesterday = today.subtract(const Duration(days: 1));
  if (local.year == yesterday.year && local.month == yesterday.month && local.day == yesterday.day) {
    return 'gestern';
  }
  return '${two(local.day)}.${two(local.month)}.${local.year}';
}
