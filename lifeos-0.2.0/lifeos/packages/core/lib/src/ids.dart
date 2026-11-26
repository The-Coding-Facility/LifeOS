import 'package:uuid/uuid.dart';

/// Erzeugt die IDs aller Datensätze.
abstract final class Ids {
  static const Uuid _uuid = Uuid();

  /// Fester Namensraum für deterministische IDs von LifeOS.
  static const String namespace = '6f1c2a4e-8b3d-4f7a-9c5e-2d8b1a7e4c90';

  /// Neue, weltweit eindeutige und zeitlich sortierbare ID (UUIDv7).
  static String newId() => _uuid.v7();

  /// Deterministische ID (UUIDv5). Gleiche Eingaben ergeben auf jedem Gerät
  /// dieselbe ID, z. B. für „ein Daily Report pro Tag“.
  ///
  /// [scope] trennt die Bereiche, etwa `daily_report` oder `tag:finance`.
  static String deterministic(String scope, String key) =>
      _uuid.v5(namespace, '$scope:$key');

  /// Vereinheitlicht Namen für deterministische IDs (Zutaten, Tags).
  static String normalizeName(String name) =>
      name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}
