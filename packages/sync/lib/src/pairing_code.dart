import 'dart:math';

/// Einmaliger Kopplungscode: 16 Zeichen Crockford-Base32 (80 Bit Zufall),
/// angezeigt als `XXXX-XXXX-XXXX-XXXX`.
abstract final class PairingCode {
  static const String _alphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
  static const int length = 16;

  static String generate() {
    final random = Random.secure();
    final buffer = StringBuffer();
    for (var i = 0; i < length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write('-');
      buffer.write(_alphabet[random.nextInt(_alphabet.length)]);
    }
    return buffer.toString();
  }

  /// Groß-/Kleinschreibung, Leerzeichen und Bindestriche egal,
  /// O wird zu 0, I und L werden zu 1. `null` bei ungültiger Eingabe.
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
