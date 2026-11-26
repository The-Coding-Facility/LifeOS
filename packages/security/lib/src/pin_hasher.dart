import 'dart:convert';
import 'dart:isolate';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

/// Gespeicherter PIN-Hash mit Salt, beides Base64.
class PinHash {
  const PinHash({required this.salt, required this.hash});

  final String salt;
  final String hash;
}

/// Hasht und prüft PINs mit Argon2id.
///
/// Die Parameter sind bewusst moderat, siehe docs/adr/0003. Die Berechnung
/// läuft in einem eigenen Isolate, damit die Oberfläche nicht hängt.
class PinHasher {
  const PinHasher({this.memoryKb = 8 * 1024, this.iterations = 2});

  /// Speicherbedarf von Argon2id in KiB.
  final int memoryKb;

  /// Anzahl der Durchläufe.
  final int iterations;

  static final RegExp _pinPattern = RegExp(r'^\d{6,12}$');

  /// Gültig sind 6 bis 12 Ziffern.
  static bool isValidPin(String pin) => _pinPattern.hasMatch(pin);

  Future<PinHash> hash(String pin) async {
    final salt = randomBytes(16);
    final derived = await _derive(pin, salt);
    return PinHash(salt: base64Encode(salt), hash: base64Encode(derived));
  }

  Future<bool> verify(String pin, PinHash stored) async {
    final derived = await _derive(pin, base64Decode(stored.salt));
    return constantTimeEquals(derived, base64Decode(stored.hash));
  }

  Future<List<int>> _derive(String pin, List<int> salt) {
    final memory = memoryKb;
    final rounds = iterations;
    return Isolate.run(() async {
      final algorithm = Argon2id(
        memory: memory,
        parallelism: 1,
        iterations: rounds,
        hashLength: 32,
      );
      final key = await algorithm.deriveKeyFromPassword(password: pin, nonce: salt);
      return key.extractBytes();
    });
  }
}

/// Kryptografisch sichere Zufallsbytes.
List<int> randomBytes(int length) {
  final random = Random.secure();
  return List<int>.generate(length, (_) => random.nextInt(256));
}

/// Vergleich in konstanter Zeit, damit die Laufzeit nichts verrät.
bool constantTimeEquals(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  var difference = 0;
  for (var i = 0; i < a.length; i++) {
    difference |= a[i] ^ b[i];
  }
  return difference == 0;
}
