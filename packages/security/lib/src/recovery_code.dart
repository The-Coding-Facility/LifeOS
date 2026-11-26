import 'dart:math';

/// Wiederherstellungscode für eine vergessene PIN.
///
/// 24 Zeichen aus dem Crockford-Base32-Alphabet (ohne I, L, O, U), also
/// 120 Bit Zufall. Anzeige in Sechsergruppen zu je vier Zeichen.
abstract final class RecoveryCode {
  static const String _alphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';

  /// Anzahl der Zeichen ohne Bindestriche.
  static const int length = 24;

  /// Neuer Code, z. B. `7QK2-M9XA-...`.
  static String generate() {
    final random = Random.secure();
    final buffer = StringBuffer();
    for (var i = 0; i < length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write('-');
      buffer.write(_alphabet[random.nextInt(_alphabet.length)]);
    }
    return buffer.toString();
  }

  /// Vereinheitlicht eine Eingabe: Groß-/Kleinschreibung, Leerzeichen und
  /// Bindestriche egal, O wird zu 0, I und L werden zu 1.
  /// Gibt `null` zurück, wenn die Eingabe kein gültiger Code sein kann.
  static String? normalize(String input) {
    final cleaned = input
        .toUpperCase()
        .replaceAll(RegExp(r'[\s-]'), '')
        .replaceAll('O', '0')
        .replaceAll('I', '1')
        .replaceAll('L', '1');
    if (cleaned.length != length) return null;
    for (var i = 0; i < cleaned.length; i++) {
      if (!_alphabet.contains(cleaned[i])) return null;
    }
    return cleaned;
  }
}
