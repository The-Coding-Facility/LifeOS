import 'dart:convert';

import 'package:lifeos_core/lifeos_core.dart';
import 'package:lifeos_persistence/lifeos_persistence.dart';

import 'sync_crypto.dart';

/// Gerätebezogene Sync-Einstellungen in `local_meta` (verschlüsselte DB).
class SyncSettings {
  SyncSettings(this._meta);

  static const String _vaultIdKey = 'sync.vault_id';
  static const String _vaultKeyKey = 'sync.vault_key';
  static const String _deviceNameKey = 'sync.device_name';

  final LocalMetaStore _meta;

  /// Bestandsschlüssel oder `null`, solange dieses Gerät nie gekoppelt war.
  Future<List<int>?> readVaultKey() async {
    final value = await _meta.get(_vaultKeyKey);
    return value == null ? null : base64Decode(value);
  }

  Future<String?> readVaultId() => _meta.get(_vaultIdKey);

  /// Liefert den vorhandenen Bestand oder legt einen neuen an.
  Future<({String id, List<int> key})> ensureVault() async {
    final id = await readVaultId();
    final key = await readVaultKey();
    if (id != null && key != null) return (id: id, key: key);
    final newId = Ids.newId();
    final newKey = SyncCrypto.randomKey();
    await writeVault(newId, newKey);
    return (id: newId, key: newKey);
  }

  /// Übernimmt den Bestand eines anderen Geräts beim Koppeln.
  Future<void> writeVault(String id, List<int> key) async {
    await _meta.set(_vaultIdKey, id);
    await _meta.set(_vaultKeyKey, base64Encode(key));
  }

  Future<String?> readDeviceName() => _meta.get(_deviceNameKey);

  Future<void> writeDeviceName(String name) => _meta.set(_deviceNameKey, name.trim());
}
