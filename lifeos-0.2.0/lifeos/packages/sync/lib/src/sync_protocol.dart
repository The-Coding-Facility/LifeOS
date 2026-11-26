/// Feste Werte des Sync-Protokolls (Version 1).
abstract final class SyncProtocol {
  static const int version = 1;

  /// Standard-Port. Ist er belegt, nimmt der Server einen freien Port.
  static const int defaultPort = 47321;

  static const String basePath = '/lifeos/v1';
  static const String deviceHeader = 'x-lifeos-device';

  /// Einträge pro Übertragung.
  static const int batchSize = 500;

  /// Größte akzeptierte Nachricht.
  static const int maxBodyBytes = 32 * 1024 * 1024;

  static String requestAad(String path, String sender) => 'req|$path|$sender';

  static String responseAad(String path, String sender) => 'res|$path|$sender';
}
