import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:drift/drift.dart';
import 'package:lifeos_persistence/lifeos_persistence.dart';

import 'network.dart';
import 'pairing_code.dart';
import 'sync_crypto.dart';
import 'sync_engine.dart';
import 'sync_entry.dart';
import 'sync_errors.dart';
import 'sync_protocol.dart';
import 'sync_settings.dart';
import 'transport.dart';

/// Grober Zustand für das Sync-Symbol auf dem Dashboard.
enum SyncPhase { localOnly, syncing, synced, offline }

class SyncState {
  const SyncState({
    required this.phase,
    this.pending = 0,
    this.conflicts = 0,
    this.lastSync,
    this.message,
  });

  final SyncPhase phase;

  /// Eigene Änderungen, die noch nicht jedes gekoppelte Gerät hat.
  final int pending;

  /// Offene Konflikte.
  final int conflicts;
  final DateTime? lastSync;

  /// Letzte Fehlermeldung, falls kein Gerät erreichbar war.
  final String? message;
}

/// Angebot zum Koppeln, angezeigt auf dem Gerät, das schon Daten hat.
class PairingOffer {
  const PairingOffer({
    required this.code,
    required this.expiresAt,
    required this.addresses,
    required this.port,
  });

  final String code;
  final DateTime expiresAt;

  /// Eigene Adressen im lokalen Netz, ohne Port.
  final List<String> addresses;
  final int port;
}

/// Steuert Server, Kopplung und regelmäßigen Abgleich mit allen gekoppelten
/// Geräten.
///
/// Ausgelöst wird der Abgleich beim Start, alle 30 Sekunden, 2 Sekunden
/// nach jeder Änderung und auf Knopfdruck.
class SyncService {
  SyncService._(this._db, this.engine, this._settings, this.identity)
      : _client = SyncClient(identity),
        _server = SyncServer(db: _db, engine: engine, settings: _settings, identity: identity);

  /// Baut den Dienst auf. [defaultName] gilt, solange kein Name gespeichert ist.
  static Future<SyncService> create({
    required LifeosDatabase db,
    required ChangeRecorder recorder,
    required String platform,
    required String defaultName,
  }) async {
    final settings = SyncSettings(LocalMetaStore(db));
    final name = await settings.readDeviceName() ?? defaultName;
    final identity = DeviceIdentity(id: recorder.deviceId, name: name, platform: platform);
    return SyncService._(db, SyncEngine(db, recorder), settings, identity);
  }

  final LifeosDatabase _db;
  final SyncEngine engine;
  final SyncSettings _settings;
  final DeviceIdentity identity;
  final SyncClient _client;
  final SyncServer _server;

  final _states = StreamController<SyncState>.broadcast();
  SyncState _state = const SyncState(phase: SyncPhase.localOnly);
  Timer? _ticker;
  Timer? _debounce;
  StreamSubscription<Object?>? _changes;
  Future<void>? _inFlight;
  bool _again = false;

  SyncState get state => _state;

  Stream<SyncState> get states => _states.stream;

  /// Meldet die ID eines Geräts, das sich gerade mit diesem gekoppelt hat.
  Stream<String> get onPaired => _server.onPaired;

  /// Port des eigenen Servers, 0 wenn er nicht läuft.
  int get port => _server.port;

  bool get serverRunning => _server.isRunning;

  /// Startet Server und Zeitgeber. Scheitert der Server (z. B. keine
  /// Netzwerkrechte), funktioniert die App trotzdem, nur ohne Sync-Empfang.
  Future<void> start({int port = SyncProtocol.defaultPort}) async {
    try {
      await _server.start(port: port);
    } on Object catch (error) {
      _emit(SyncState(phase: SyncPhase.offline, message: 'Sync-Server startet nicht: $error'));
    }
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) => syncNow());
    _changes = _db.tableUpdates(TableUpdateQuery.onTable(_db.changeLog)).listen((_) {
      _debounce?.cancel();
      _debounce = Timer(const Duration(seconds: 2), syncNow);
    });
    unawaited(syncNow());
  }

  Future<void> dispose() async {
    _ticker?.cancel();
    _debounce?.cancel();
    await _changes?.cancel();
    await _server.stop();
    await _states.close();
  }

  Stream<List<PairedDevice>> watchDevices() => _db.select(_db.pairedDevices).watch();

  /// Gleicht mit allen gekoppelten Geräten ab. Läuft schon ein Abgleich,
  /// wird direkt danach ein weiterer gestartet. Das zurückgegebene Future
  /// endet erst, wenn auch dieser fertig ist.
  Future<void> syncNow() {
    final running = _inFlight;
    if (running != null) {
      _again = true;
      return running;
    }
    final future = _runLoop();
    _inFlight = future;
    return future;
  }

  Future<void> _runLoop() async {
    try {
      do {
        _again = false;
        await _syncAllOnce();
      } while (_again);
    } on Object catch (error) {
      _emit(SyncState(
        phase: SyncPhase.offline,
        pending: _state.pending,
        lastSync: _state.lastSync,
        message: describeSyncError(error),
      ));
    } finally {
      _inFlight = null;
    }
  }

  // ---------------------------------------------------------------- Kopplung

  /// Öffnet eine Kopplung für 10 Minuten und liefert Code und Adressen.
  Future<PairingOffer> startPairing() async {
    await _settings.ensureVault();
    final code = PairingCode.generate();
    final key = await SyncCrypto.pairingKey(PairingCode.normalize(code)!);
    final expiresAt = DateTime.now().add(const Duration(minutes: 10));
    _server.invite = PairingInvite(key: key, expiresAt: expiresAt);
    return PairingOffer(
      code: code,
      expiresAt: expiresAt,
      addresses: await localAddresses(),
      port: _server.port,
    );
  }

  void cancelPairing() => _server.invite = null;

  /// Koppelt dieses Gerät mit dem Gerät unter [address], das gerade
  /// [code] anzeigt. Übernimmt dessen Bestandsschlüssel und gleicht ab.
  Future<PairedDevice> joinWith({required String address, required String code}) async {
    final normalizedCode = PairingCode.normalize(code);
    if (normalizedCode == null) {
      throw const SyncException('Der Code muss 16 Zeichen haben, z. B. ABCD-EFGH-JKMN-PQRS.');
    }
    final target = normalizeAddress(address);
    final key = await SyncCrypto.pairingKey(normalizedCode);
    final (serverId, reply) = await _client.post(target, '/pair', {
      'deviceId': identity.id,
      'name': identity.name,
      'platform': identity.platform,
      'port': _server.port,
    }, key);
    if (serverId.isEmpty || serverId == identity.id) {
      throw const SyncException('Das Gerät hat sich nicht korrekt ausgewiesen.');
    }
    await _settings.writeVault(
      reply['vaultId'] as String,
      base64Decode(reply['vaultKey'] as String),
    );
    await _db.into(_db.pairedDevices).insertOnConflictUpdate(
          PairedDevicesCompanion.insert(
            deviceId: serverId,
            name: reply['name'] as String? ?? 'Gerät',
            platform: reply['platform'] as String? ?? 'unbekannt',
            address: Value(target),
            addedAt: DateTime.now().toUtc().millisecondsSinceEpoch,
          ),
        );
    unawaited(syncNow());
    return (_db.select(_db.pairedDevices)..where((device) => device.deviceId.equals(serverId)))
        .getSingle();
  }

  /// Neue Adresse für ein gekoppeltes Gerät, z. B. nach IP-Wechsel.
  Future<void> updateAddress(String deviceId, String address) async {
    await (_db.update(_db.pairedDevices)..where((device) => device.deviceId.equals(deviceId)))
        .write(PairedDevicesCompanion(address: Value(normalizeAddress(address))));
    unawaited(syncNow());
  }

  /// Entfernt ein Gerät nur aus der lokalen Liste. Ein echter Widerruf mit
  /// Schlüsselwechsel folgt mit den Gerätezertifikaten.
  Future<void> forget(String deviceId) async {
    await (_db.delete(_db.pairedDevices)..where((device) => device.deviceId.equals(deviceId))).go();
    unawaited(syncNow());
  }

  // ---------------------------------------------------------------- Abgleich

  Future<void> _syncAllOnce() async {
    final peers = await _db.select(_db.pairedDevices).get();
    if (peers.isEmpty) {
      _emit(SyncState(phase: SyncPhase.localOnly, conflicts: await engine.openConflictCount()));
      return;
    }
    final key = await _settings.readVaultKey();
    if (key == null) {
      _emit(const SyncState(phase: SyncPhase.offline, message: 'Kein Bestandsschlüssel. Bitte neu koppeln.'));
      return;
    }

    _emit(SyncState(
      phase: SyncPhase.syncing,
      pending: _state.pending,
      conflicts: _state.conflicts,
      lastSync: _state.lastSync,
    ));

    var reachedAny = false;
    String? lastError;
    for (final peer in peers) {
      final address = peer.address;
      if (address == null) continue;
      try {
        await _syncWith(peer, address, key);
        reachedAny = true;
      } on Object catch (error) {
        lastError = '${peer.name}: ${describeSyncError(error)}';
      }
    }

    _emit(SyncState(
      phase: reachedAny ? SyncPhase.synced : SyncPhase.offline,
      pending: await _pendingCount(),
      conflicts: await engine.openConflictCount(),
      lastSync: reachedAny ? DateTime.now() : _state.lastSync,
      message: reachedAny ? null : lastError ?? 'Kein gekoppeltes Gerät hat eine Adresse.',
    ));
  }

  Future<void> _syncWith(PairedDevice peer, String address, List<int> key) async {
    final (serverId, hello) = await _client.post(address, '/hello', {
      'protocol': SyncProtocol.version,
      'schema': engine.schemaVersion,
      'deviceId': identity.id,
      'name': identity.name,
      'platform': identity.platform,
      'port': _server.port,
      'vector': await engine.versionVector(),
    }, key);
    if (serverId != peer.deviceId) {
      throw SyncException('Unter $address antwortet ein anderes Gerät.');
    }
    if (hello['error'] == 'version') {
      throw const SyncException('Die App-Versionen passen nicht zusammen. Bitte beide Geräte aktualisieren.');
    }

    // Abgeben: alles, was das andere Gerät noch nicht hat.
    var remoteVector = Map<String, int>.from(hello['vector'] as Map<String, dynamic>);
    while (true) {
      final batch = await engine.entriesMissingFrom(remoteVector, limit: SyncProtocol.batchSize);
      if (batch.isEmpty) break;
      final (_, pushed) = await _client.post(address, '/push', {
        'entries': [for (final entry in batch) entry.toJson()],
      }, key);
      final nextVector = Map<String, int>.from(pushed['vector'] as Map<String, dynamic>);
      if (_sameVector(nextVector, remoteVector)) {
        throw const SyncException('Das andere Gerät hat die Änderungen nicht übernommen.');
      }
      remoteVector = nextVector;
    }

    // Abholen: alles, was dieses Gerät noch nicht hat.
    var more = true;
    while (more) {
      final (_, pulled) = await _client.post(address, '/pull', {
        'vector': await engine.versionVector(),
        'limit': SyncProtocol.batchSize,
      }, key);
      final entries = [
        for (final item in pulled['entries'] as List<dynamic>)
          SyncEntry.fromJson(item as Map<String, dynamic>),
      ];
      if (entries.isNotEmpty) await engine.applyEntries(entries);
      more = pulled['more'] == true && entries.isNotEmpty;
    }

    await (_db.update(_db.pairedDevices)..where((device) => device.deviceId.equals(peer.deviceId)))
        .write(
      PairedDevicesCompanion(
        name: Value(hello['name'] as String? ?? peer.name),
        lastSyncAt: Value(DateTime.now().toUtc().millisecondsSinceEpoch),
        ackedSeq: Value(remoteVector[identity.id] ?? 0),
      ),
    );
  }

  Future<int> _pendingCount() async {
    final own = await engine.ownLatestSeq();
    final peers = await _db.select(_db.pairedDevices).get();
    if (peers.isEmpty) return 0;
    final minAcked = peers.map((peer) => peer.ackedSeq).reduce(math.min);
    return math.max(0, own - minAcked);
  }

  static bool _sameVector(Map<String, int> a, Map<String, int> b) =>
      a.length == b.length && a.entries.every((entry) => b[entry.key] == entry.value);

  void _emit(SyncState state) {
    _state = state;
    if (!_states.isClosed) _states.add(state);
  }
}
