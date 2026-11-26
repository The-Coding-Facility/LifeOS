import 'package:lifeos_persistence/lifeos_persistence.dart';

/// Ein Eintrag des Änderungsprotokolls, wie er zwischen Geräten reist.
class SyncEntry {
  const SyncEntry({
    required this.originDevice,
    required this.seq,
    required this.hlc,
    required this.entity,
    required this.recordId,
    required this.op,
    required this.payload,
    required this.txId,
  });

  factory SyncEntry.fromRow(ChangeLogEntry row) => SyncEntry(
        originDevice: row.originDevice,
        seq: row.seq,
        hlc: row.hlc,
        entity: row.entity,
        recordId: row.recordId,
        op: row.op,
        payload: row.payload,
        txId: row.txId,
      );

  factory SyncEntry.fromJson(Map<String, dynamic> json) => SyncEntry(
        originDevice: json['o'] as String,
        seq: json['s'] as int,
        hlc: json['h'] as String,
        entity: json['e'] as String,
        recordId: json['r'] as String,
        op: json['op'] as String,
        payload: json['p'] as String,
        txId: json['t'] as String,
      );

  final String originDevice;
  final int seq;
  final String hlc;
  final String entity;
  final String recordId;
  final String op;

  /// JSON wie vom `ChangeRecorder` geschrieben.
  final String payload;
  final String txId;

  Map<String, Object> toJson() => {
        'o': originDevice,
        's': seq,
        'h': hlc,
        'e': entity,
        'r': recordId,
        'op': op,
        'p': payload,
        't': txId,
      };

  ChangeLogCompanion toCompanion() => ChangeLogCompanion.insert(
        originDevice: originDevice,
        seq: seq,
        hlc: hlc,
        entity: entity,
        recordId: recordId,
        op: op,
        payload: payload,
        txId: txId,
      );
}
