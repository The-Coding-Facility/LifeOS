/// Deutsche Datums- und Zeittexte ohne zusätzliche Pakete.
library;

const List<String> germanMonths = [
  'Januar', 'Februar', 'März', 'April', 'Mai', 'Juni',
  'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember',
];

const List<String> germanMonthsShort = [
  'Jan', 'Feb', 'Mär', 'Apr', 'Mai', 'Jun', 'Jul', 'Aug', 'Sep', 'Okt', 'Nov', 'Dez',
];

const List<String> germanWeekdays = [
  'Montag', 'Dienstag', 'Mittwoch', 'Donnerstag', 'Freitag', 'Samstag', 'Sonntag',
];

const List<String> germanWeekdaysShort = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];

String _two(int value) => value.toString().padLeft(2, '0');

/// `26.11.2026`
String formatDate(DateTime date) => '${_two(date.day)}.${_two(date.month)}.${date.year}';

/// `Donnerstag, 26. November 2026`
String formatDateLong(DateTime date) =>
    '${germanWeekdays[date.weekday - 1]}, ${date.day}. ${germanMonths[date.month - 1]} ${date.year}';

/// `Do, 26.11.`
String formatDateShort(DateTime date) =>
    '${germanWeekdaysShort[date.weekday - 1]}, ${date.day}.${date.month}.';

/// `November 2026`
String formatMonthYear(DateTime date) => '${germanMonths[date.month - 1]} ${date.year}';

/// `14:05`
String formatTime(DateTime time) => '${_two(time.hour)}:${_two(time.minute)}';
