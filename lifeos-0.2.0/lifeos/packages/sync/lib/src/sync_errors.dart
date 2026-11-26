import 'dart:async';
import 'dart:io';

/// Fehler beim Synchronisieren mit einer für Menschen lesbaren Meldung.
class SyncException implements Exception {
  const SyncException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Das andere Gerät hat mit einem HTTP-Fehler geantwortet.
class SyncHttpException implements Exception {
  const SyncHttpException(this.statusCode, this.body);

  final int statusCode;
  final String body;

  @override
  String toString() => 'HTTP $statusCode $body';
}

/// Im empfangenen Protokoll fehlen Einträge. Darf nicht vorkommen, wird
/// aber abgefangen, statt Daten lückenhaft zu übernehmen.
class SyncGapException implements Exception {
  const SyncGapException(this.originDevice, this.expectedSeq, this.receivedSeq);

  final String originDevice;
  final int expectedSeq;
  final int receivedSeq;

  @override
  String toString() =>
      'Lücke im Änderungsprotokoll von $originDevice: erwartet $expectedSeq, erhalten $receivedSeq';
}

/// Übersetzt einen Fehler in eine kurze deutsche Meldung für die Oberfläche.
String describeSyncError(Object error) => switch (error) {
      SyncException(:final message) => message,
      SyncHttpException(statusCode: 401) =>
        'Code falsch oder Schlüssel passt nicht. Bitte neu koppeln.',
      SyncHttpException(statusCode: 403) =>
        'Das andere Gerät kennt dieses Gerät nicht. Bitte neu koppeln.',
      SyncHttpException(statusCode: 410) =>
        'Auf dem anderen Gerät ist keine Kopplung geöffnet oder der Code ist abgelaufen.',
      SyncHttpException(:final statusCode) => 'Das andere Gerät meldet Fehler $statusCode.',
      SocketException() => 'Gerät nicht erreichbar. Gleiches WLAN? Firewall?',
      TimeoutException() => 'Keine Antwort vom anderen Gerät (Zeitüberschreitung).',
      SyncGapException() => 'Unvollständige Daten empfangen. Bitte erneut synchronisieren.',
      _ => 'Unerwarteter Fehler: $error',
    };
