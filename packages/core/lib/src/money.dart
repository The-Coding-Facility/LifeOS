/// Geldbeträge sind in LifeOS immer ganze Cent (`int`), nie Kommazahlen.
library;

/// `123456` → `1.234,56 €`. Mit [withSign] bekommen positive Beträge ein `+`.
String formatCents(int cents, {bool withSign = false}) {
  final negative = cents < 0;
  final absolute = cents.abs();
  final euros = (absolute ~/ 100).toString();
  final rest = (absolute % 100).toString().padLeft(2, '0');

  final grouped = StringBuffer();
  for (var i = 0; i < euros.length; i++) {
    if (i > 0 && (euros.length - i) % 3 == 0) grouped.write('.');
    grouped.write(euros[i]);
  }

  final sign = negative ? '-' : (withSign && cents > 0 ? '+' : '');
  return '$sign$grouped,$rest €';
}

/// Liest einen Betrag, wie Menschen ihn tippen: `12,5`, `12.50`, `1.234,56`,
/// `-3`, `7 €`. Gibt `null` zurück, wenn die Eingabe kein Betrag ist.
///
/// Regeln: Kommen `.` und `,` vor, ist das zuletzt stehende das
/// Dezimalzeichen. Ein `.` mit genau drei Ziffern dahinter ist ein
/// Tausenderpunkt. Mehr als zwei Nachkommastellen sind ungültig.
int? parseCents(String input) {
  var text = input.replaceAll('€', '').replaceAll(' ', '').trim();
  if (text.isEmpty) return null;

  var negative = false;
  if (text.startsWith('-')) {
    negative = true;
    text = text.substring(1);
  } else if (text.startsWith('+')) {
    text = text.substring(1);
  }
  if (text.isEmpty) return null;

  final lastDot = text.lastIndexOf('.');
  final lastComma = text.lastIndexOf(',');
  String? decimalSeparator;
  if (lastDot >= 0 && lastComma >= 0) {
    decimalSeparator = lastDot > lastComma ? '.' : ',';
  } else if (lastComma >= 0) {
    decimalSeparator = ',';
  } else if (lastDot >= 0) {
    final digitsAfter = text.length - lastDot - 1;
    final singleDot = text.indexOf('.') == lastDot;
    decimalSeparator = (singleDot && digitsAfter != 3) ? '.' : null;
  }

  String wholePart;
  var fractionPart = '';
  if (decimalSeparator == null) {
    wholePart = text;
  } else {
    final index = text.lastIndexOf(decimalSeparator);
    wholePart = text.substring(0, index);
    fractionPart = text.substring(index + 1);
  }

  final thousands = decimalSeparator == ',' ? '.' : (decimalSeparator == '.' ? ',' : '.');
  if (!_validGrouping(wholePart, thousands)) return null;
  wholePart = wholePart.replaceAll(thousands, '');

  if (wholePart.isEmpty) wholePart = '0';
  if (!_digitsOnly(wholePart) || !_digitsOnly(fractionPart)) return null;
  if (fractionPart.length > 2) return null;
  if (decimalSeparator != null && fractionPart.isEmpty) return null;

  final euros = int.parse(wholePart);
  final cents = int.parse(fractionPart.padRight(2, '0'));
  final value = euros * 100 + cents;
  return negative ? -value : value;
}

bool _digitsOnly(String text) => RegExp(r'^\d*$').hasMatch(text);

/// Tausendertrennzeichen nur zwischen Dreiergruppen, nie doppelt.
bool _validGrouping(String whole, String separator) {
  if (!whole.contains(separator)) return true;
  final parts = whole.split(separator);
  if (parts.first.isEmpty || parts.first.length > 3) return false;
  for (final part in parts.skip(1)) {
    if (part.length != 3) return false;
  }
  return true;
}
