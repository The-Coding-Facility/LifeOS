import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:drift/drift.dart';
import 'package:lifeos_persistence/lifeos_persistence.dart';

import 'sync_crypto.dart';
import 'sync_engine.dart';
import 'sync_entry.dart';
import 'sync_errors.dart';
import 'sync_protocol.dart';
import 'sync_settings.dart';

/// Wer dieses Gerät ist.
class DeviceIdentity {
  const DeviceIdentity({required this.id, required this.name, required this.platform});

  final String id;
  final String name;

  /// `windows`, `android` oder `ios`.
  final String platform;
}

/// Offene Kopplung: gilt 10 Minuten, höchstens 5 Fehlversuche.
class PairingInvite {
  PairingInvite({required this.key, required this.expiresAt});

  final List<int> key;
  final DateTime expiresAt;
  int failedAttempts = 0;

  bool get expired => DateTime.now().isAfter(expiresAt);
}

class _NotFound implements Exception {
  const _NotFound();
}

/// HTTP-Server, über den andere Geräte Änderungen abholen und abgeben.
///
/// Alle Nutzdaten sind mit ChaCha20-Poly1305 verschlüsselt und an Pfad und
/// Absender gebunden. Unbekannte Geräte werden abgewiesen.
class SyncServer {
  SyncServer({
    required LifeosDatabase db,
    required SyncEngine engine,
    required SyncSettings settings,
    required this.identity,
  })  : _db = db,
        _engine = engine,
        _settings = settings;

  final LifeosDatabase _db;
  final SyncEngine _engine;
  final SyncSettings _settings;
  final DeviceIdentity identity;

  HttpServer? _server;
  PairingInvite? invite;

  final _paired = StreamController<String>.broadcast();
  final _received = StreamController<void>.broadcast();

  /// Meldet die ID eines neu gekoppelten Geräts.
  Stream<String> get onPaired => _paired.stream;

  /// Meldet, dass ein anderes Gerät Änderungen abgegeben hat.
  Stream<void> get onReceived => _received.stream;

  int get port => _server?.port ?? 0;

  bool get isRunning => _server != null;

  Future<void> start({int port = SyncProtocol.defaultPort}) async {
    if (_server != null) return;
    HttpServer server;
    try {
      server = await HttpServer.bind(InternetAddress.anyIPv4, port);
    } on SocketException {
      server = await HttpServer.bind(InternetAddress.anyIPv4, 0);
    }
    _server = server;
    server.listen(_handle, onError: (Object _) {});
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    await _paired.close();
    await _received.close();
  }

  Future<void> _handle(HttpRequest request) async {
    final response = request.response;
    try {
      final fullPath = request.uri.path;
      if (request.method != 'POST' || !fullPath.startsWith(SyncProtocol.basePath)) {
        throw const _NotFound();
      }
      final path = fullPath.substring(SyncProtocol.basePath.length);
      final sender = request.headers.value(SyncProtocol.deviceHeader);
      if (sender == null || sender.isEmpty) {
        return await _plain(response, HttpStatus.badRequest);
      }
      final body = await readBytes(request);

      if (path == '/pair') {
        return await _handlePair(request, sender, body);
      }

      final peer = await (_db.select(_db.pairedDevices)
            ..where((device) => device.deviceId.equals(sender)))
          .getSingleOrNull();
      final key = await _settings.readVaultKey();
      if (peer == null || key == null) {
        return await _plain(response, HttpStatus.forbidden);
      }

      final Map<String, dynamic> message;
      try {
        final plain = await SyncCrypto.open(key, body, SyncProtocol.requestAad(path, sender));
        message = jsonDecode(utf8.decode(plain)) as Map<String, dynamic>;
      } on Object {
        return await _plain(response, HttpStatus.unauthorized);
      }

      final Map<String, Object?> reply = switch (path) {
        '/hello' => await _hello(request, sender, message),
        '/push' => await _push(message),
        '/pull' => await _pull(sender, message),
        _ => throw const _NotFound(),
      };
      await _sendSealed(response, key, path, reply);
    } on _NotFound {
      await _plain(response, HttpStatus.notFound);
    } catch (error) {
      await _plain(response, HttpStatus.internalServerError, '$error');
    }
  }

  Future<Map<String, Object?>> _hello(
    HttpRequest request,
    String sender,
    Map<String, dynamic> message,
  ) async {
    final base = <String, Object?>{
      'protocol': SyncProtocol.version,
      'schema': _engine.schemaVersion,
      'deviceId': identity.id,
      'name': identity.name,
      'platform': identity.platform,
    };
    if (message['protocol'] != SyncProtocol.version || message['schema'] != _engine.schemaVersion) {
      return {...base, 'error': 'version'};
    }
    final remoteHost = request.connectionInfo?.remoteAddress.address;
    final remotePort = message['port'];
    await (_db.update(_db.pairedDevices)..where((device) => device.deviceId.equals(sender))).write(
      PairedDevicesCompanion(
        name: Value(message['name'] as String? ?? 'Gerät'),
        address: remoteHost != null && remotePort is int && remotePort > 0
            ? Value('$remoteHost:$remotePort')
            : const Value.absent(),
      ),
    );
    return {...base, 'vector': await _engine.versionVector()};
  }

  Future<Map<String, Object?>> _push(Map<String, dynamic> message) async {
    final entries = [
      for (final item in message['entries'] as List<dynamic>)
        SyncEntry.fromJson(item as Map<String, dynamic>),
    ];
    final applied = await _engine.applyEntries(entries);
    if (applied > 0) _received.add(null);
    return {'applied': applied, 'vector': await _engine.versionVector()};
  }

  Future<Map<String, Object?>> _pull(String sender, Map<String, dynamic> message) async {
    final remoteVector = Map<String, int>.from(message['vector'] as Map<String, dynamic>);
    final requested = message['limit'] as int? ?? SyncProtocol.batchSize;
    final limit = math.max(1, math.min(requested, SyncProtocol.batchSize));
    final entries = await _engine.entriesMissingFrom(remoteVector, limit: limit + 1);
    final more = entries.length > limit;

    // Was das andere Gerät von uns hat, steht in seinem Vektor.
    await (_db.update(_db.pairedDevices)..where((device) => device.deviceId.equals(sender))).write(
      PairedDevicesCompanion(
        lastSyncAt: Value(DateTime.now().toUtc().millisecondsSinceEpoch),
        ackedSeq: Value(remoteVector[identity.id] ?? 0),
      ),
    );
    return {
      'entries': [for (final entry in entries.take(limit)) entry.toJson()],
      'more': more,
    };
  }

  Future<void> _handlePair(HttpRequest request, String sender, List<int> body) async {
    final response = request.response;
    final current = invite;
    if (current == null || current.expired) {
      invite = null;
      return _plain(response, HttpStatus.gone);
    }

    final Map<String, dynamic> message;
    try {
      final plain = await SyncCrypto.open(current.key, body, SyncProtocol.requestAad('/pair', sender));
      message = jsonDecode(utf8.decode(plain)) as Map<String, dynamic>;
    } on Object {
      current.failedAttempts++;
      if (current.failedAttempts >= 5) invite = null;
      return _plain(response, HttpStatus.unauthorized);
    }

    final vault = await _settings.ensureVault();
    final remoteHost = request.connectionInfo?.remoteAddress.address;
    final remotePort = message['port'];
    await _db.into(_db.pairedDevices).insertOnConflictUpdate(
          PairedDevicesCompanion.insert(
            deviceId: sender,
            name: message['name'] as String? ?? 'Gerät',
            platform: message['platform'] as String? ?? 'unbekannt',
            address: Value(
              remoteHost != null && remotePort is int && remotePort > 0
                  ? '$remoteHost:$remotePort'
                  : null,
            ),
            addedAt: DateTime.now().toUtc().millisecondsSinceEpoch,
          ),
        );
    invite = null;
    await _sendSealed(response, current.key, '/pair', {
      'vaultId': vault.id,
      'vaultKey': base64Encode(vault.key),
      'deviceId': identity.id,
      'name': identity.name,
      'platform': identity.platform,
    });
    _paired.add(sender);
  }

  Future<void> _sendSealed(
    HttpResponse response,
    List<int> key,
    String path,
    Map<String, Object?> message,
  ) async {
    final sealed = await SyncCrypto.seal(
      key,
      utf8.encode(jsonEncode(message)),
      SyncProtocol.responseAad(path, identity.id),
    );
    response
      ..statusCode = HttpStatus.ok
      ..headers.set(SyncProtocol.deviceHeader, identity.id)
      ..headers.contentType = ContentType.binary
      ..contentLength = sealed.length
      ..add(sealed);
    await response.close();
  }

  static Future<void> _plain(HttpResponse response, int status, [String message = '']) async {
    try {
      response
        ..statusCode = status
        ..write(message);
      await response.close();
    } on Object {
      // Antwort war schon begonnen oder die Verbindung ist weg.
    }
  }
}

/// Liest einen Datenstrom vollständig, höchstens [SyncProtocol.maxBodyBytes].
Future<Uint8List> readBytes(Stream<List<int>> stream) async {
  final builder = BytesBuilder(copy: false);
  await for (final chunk in stream) {
    builder.add(chunk);
    if (builder.length > SyncProtocol.maxBodyBytes) {
      throw const SyncException('Nachricht zu groß');
    }
  }
  return builder.takeBytes();
}

/// HTTP-Client für Anfragen an andere Geräte.
class SyncClient {
  SyncClient(this.identity, {this.timeout = const Duration(seconds: 20)});

  final DeviceIdentity identity;
  final Duration timeout;

  /// Schickt [message] verschlüsselt an [address] (`host:port`) und liefert
  /// die ID des antwortenden Geräts und seine entschlüsselte Antwort.
  Future<(String, Map<String, dynamic>)> post(
    String address,
    String path,
    Map<String, Object?> message,
    List<int> key,
  ) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 4);
    try {
      final request = await client
          .postUrl(Uri.parse('http://$address${SyncProtocol.basePath}$path'))
          .timeout(timeout);
      final sealed = await SyncCrypto.seal(
        key,
        utf8.encode(jsonEncode(message)),
        SyncProtocol.requestAad(path, identity.id),
      );
      request.headers.set(SyncProtocol.deviceHeader, identity.id);
      request.headers.contentType = ContentType.binary;
      request.contentLength = sealed.length;
      request.add(sealed);
      final response = await request.close().timeout(timeout);
      final bytes = await readBytes(response).timeout(timeout);
      if (response.statusCode != HttpStatus.ok) {
        throw SyncHttpException(response.statusCode, utf8.decode(bytes, allowMalformed: true));
      }
      final serverId = response.headers.value(SyncProtocol.deviceHeader) ?? '';
      final plain = await SyncCrypto.open(key, bytes, SyncProtocol.responseAad(path, serverId));
      return (serverId, jsonDecode(utf8.decode(plain)) as Map<String, dynamic>);
    } finally {
      client.close(force: true);
    }
  }
}
