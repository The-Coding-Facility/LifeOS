import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Verschlüsselung der Sync-Nachrichten mit ChaCha20-Poly1305.
///
/// Testversion 0.2: Alle Geräte eines Datenbestands teilen einen zufälligen
/// 256-Bit-Bestandsschlüssel, der bei der Kopplung übertragen wird. Siehe
/// docs/adr/0004-sync-testversion.md. Gerätezertifikate mit mTLS folgen.
abstract final class SyncCrypto {
  static final _aead = Chacha20.poly1305Aead();
  static final _random = Random.secure();

  static const int nonceLength = 12;
  static const int macLength = 16;

  /// Nonce + Chiffretext + MAC. [aad] bindet die Nachricht an Pfad und Absender.
  static Future<Uint8List> seal(List<int> key, List<int> plaintext, String aad) async {
    final box = await _aead.encrypt(
      plaintext,
      secretKey: SecretKey(key),
      nonce: _aead.newNonce(),
      aad: utf8.encode(aad),
    );
    final builder = BytesBuilder(copy: false)
      ..add(box.nonce)
      ..add(box.cipherText)
      ..add(box.mac.bytes);
    return builder.takeBytes();
  }

  /// Entschlüsselt und prüft eine Nachricht aus [seal].
  /// Wirft bei falschem Schlüssel oder manipulierten Daten.
  static Future<List<int>> open(List<int> key, List<int> data, String aad) {
    if (data.length < nonceLength + macLength) {
      throw const FormatException('Nachricht zu kurz');
    }
    final box = SecretBox(
      data.sublist(nonceLength, data.length - macLength),
      nonce: data.sublist(0, nonceLength),
      mac: Mac(data.sublist(data.length - macLength)),
    );
    return _aead.decrypt(box, secretKey: SecretKey(key), aad: utf8.encode(aad));
  }

  /// Schlüssel aus einem Kopplungscode (80 Bit Zufall) per HKDF-SHA256.
  static Future<List<int>> pairingKey(String normalizedCode) async {
    final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
    final key = await hkdf.deriveKey(
      secretKey: SecretKey(utf8.encode(normalizedCode)),
      nonce: utf8.encode('lifeos-pairing-v1'),
      info: utf8.encode('pairing-key'),
    );
    return key.extractBytes();
  }

  /// Neuer zufälliger 256-Bit-Schlüssel.
  static List<int> randomKey() => List<int>.generate(32, (_) => _random.nextInt(256));
}
