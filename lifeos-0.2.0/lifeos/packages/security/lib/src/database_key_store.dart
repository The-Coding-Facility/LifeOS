import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Verwahrt den Datenbankschlüssel im Schlüsselspeicher des Systems
/// (iOS Keychain, Android Keystore, Windows an das Benutzerkonto gebunden).
class DatabaseKeyStore {
  DatabaseKeyStore({FlutterSecureStorage? storage})
      : _storage = storage ??
            FlutterSecureStorage(
              // Nach dem ersten Entsperren lesbar (für Hintergrund-Sync),
              // nie auf ein anderes Gerät übertragen.
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock_this_device,
              ),
            );

  static const String _keyName = 'lifeos_db_key_v1';
  static final RegExp _hexKey = RegExp(r'^[0-9a-f]{64}$');

  final FlutterSecureStorage _storage;

  /// Gespeicherter Schlüssel oder `null`, wenn noch keiner existiert.
  Future<String?> read() async {
    final value = await _storage.read(key: _keyName);
    if (value == null) return null;
    if (!_hexKey.hasMatch(value)) {
      throw StateError('Der gespeicherte Datenbankschlüssel ist beschädigt.');
    }
    return value;
  }

  /// Erzeugt einen neuen 256-Bit-Schlüssel und speichert ihn.
  ///
  /// Nur aufrufen, wenn noch keine Datenbankdatei existiert. Sonst wäre die
  /// vorhandene Datenbank unlesbar.
  Future<String> create() async {
    final random = Random.secure();
    final key = List<String>.generate(
      32,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    await _storage.write(key: _keyName, value: key);
    return key;
  }
}
