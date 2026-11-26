import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:lifeos_core/lifeos_core.dart';

import 'database.dart';
import 'local_meta_store.dart';

/// Art einer protokollierten Änderung.
enum ChangeOp { upsert, delete }

/// Feldgruppe, die den Löschzustand eines Datensatzes trägt.
const String deletedFieldGroup = '_deleted';

/// Schreibt für jede fachliche Änderung einen Eintrag ins Änderungsprotokoll.
///
/// Regel aus der Architektur: Ohne Protokolleintrag gibt es keine Änderung.
/// Repositories rufen [record] deshalb in derselben Transaktion auf, in der
/// sie die Fachtabelle ändern.
class ChangeRecorder {
  ChangeRecorder._(this._db, this._meta, this._clock);

  static const String _deviceIdKey = 'device_id';
  static const String _seqKey = 'change_seq';
  static const String _hlcKey = 'hlc_last';

  final LifeosDatabase _db;
  final LocalMetaStore _meta;
  final HlcClock _clock;

  /// ID dieses Geräts. Wird beim ersten Start erzeugt und bleibt danach gleich.
  String get deviceId => _clock.nodeId;

  /// Öffnet den Recorder. Legt beim ersten Start die Geräte-ID an und setzt
  /// die Uhr auf den zuletzt gespeicherten Stand, damit sie nie rückwärts läuft.
  static Future<ChangeRecorder> open(
    LifeosDatabase db, {
    int Function()? wallClock,
  }) async {
    final meta = LocalMetaStore(db);
    var deviceId = await meta.get(_deviceIdKey);
    if (deviceId == null) {
      deviceId = Ids.newId();
      await meta.set(_deviceIdKey, deviceId);
    }
    final lastPacked = await meta.get(_hlcKey);
    final clock = HlcClock(
      nodeId: deviceId,
      wallClock: wallClock,
      last: lastPacked == null ? null : Hlc.parse(lastPacked),
    );
    return ChangeRecorder._(db, meta, clock);
  }

  /// Protokolliert eine Änderung an [recordId] in [entity].
  ///
  /// [groups] enthält je geänderter Feldgruppe die neuen Werte, z. B.
  /// `{'done': {'done': true, 'done_at': 1764160000000}}`. Werte müssen
  /// JSON-kodierbar sein. Zu jeder Gruppe wird der bisherige HLC als
  /// Vorgänger gespeichert, damit der Sync gleichzeitige Änderungen erkennt.
  ///
  /// Gibt den HLC der Änderung zurück, den das Repository als `updatedHlc`
  /// in die Fachtabelle schreibt.
  Future<Hlc> record({
    required String entity,
    required String recordId,
    required ChangeOp op,
    required Map<String, Map<String, Object?>> groups,
    String? txId,
  }) {
    if (groups.isEmpty) {
      throw ArgumentError.value(groups, 'groups', 'Mindestens eine Feldgruppe nötig.');
    }
    return _db.transaction(() async {
      final hlc = _clock.now();
      final packed = hlc.pack();
      final payload = <String, Object?>{};

      for (final group in groups.entries) {
        final previousQuery = _db.select(_db.rowClocks)
          ..where(
            (clock) =>
                clock.entity.equals(entity) &
                clock.recordId.equals(recordId) &
                clock.fieldGroup.equals(group.key),
          );
        final previous = await previousQuery.getSingleOrNull();
        payload[group.key] = <String, Object?>{
          'values': group.value,
          'prev': previous?.hlc,
        };
        await _db.into(_db.rowClocks).insertOnConflictUpdate(
              RowClocksCompanion.insert(
                entity: entity,
                recordId: recordId,
                fieldGroup: group.key,
                hlc: packed,
                device: deviceId,
              ),
            );
      }

      final seq = await _nextSeq();
      await _db.into(_db.changeLog).insert(
            ChangeLogCompanion.insert(
              originDevice: deviceId,
              seq: seq,
              hlc: packed,
              entity: entity,
              recordId: recordId,
              op: op.name,
              payload: jsonEncode(payload),
              txId: txId ?? Ids.newId(),
            ),
          );
      await _meta.set(_hlcKey, packed);
      return hlc;
    });
  }

  /// Verarbeitet den Zeitstempel einer empfangenen Änderung, damit spätere
  /// lokale Änderungen garantiert danach einsortiert werden.
  ///
  /// Wirft [ClockDriftException], wenn [remote] unplausibel weit in der
  /// Zukunft liegt.
  Future<void> observe(Hlc remote) async {
    final updated = _clock.receive(remote);
    await _meta.set(_hlcKey, updated.pack());
  }

  Future<int> _nextSeq() async {
    final current = int.tryParse(await _meta.get(_seqKey) ?? '') ?? 0;
    final next = current + 1;
    await _meta.set(_seqKey, '$next');
    return next;
  }
}
