import 'database.dart';

/// Zugriff auf gerätebezogene Schlüssel-Wert-Paare in `local_meta`.
class LocalMetaStore {
  LocalMetaStore(this._db);

  final LifeosDatabase _db;

  Future<String?> get(String key) async {
    final query = _db.select(_db.localMeta)
      ..where((entry) => entry.metaKey.equals(key));
    final row = await query.getSingleOrNull();
    return row?.metaValue;
  }

  Future<void> set(String key, String value) async {
    await _db
        .into(_db.localMeta)
        .insertOnConflictUpdate(LocalMetaCompanion.insert(metaKey: key, metaValue: value));
  }

  Future<void> remove(String key) async {
    await (_db.delete(_db.localMeta)..where((entry) => entry.metaKey.equals(key)))
        .go();
  }
}
