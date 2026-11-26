import 'package:lifeos_persistence/lifeos_persistence.dart';

import 'pin_hasher.dart';

/// Speichert die Sicherheitsdaten in der verschlüsselten Datenbank.
///
/// Vorerst nur gerätebezogen in `local_meta`, siehe docs/adr/0003.
class SecurityStore {
  SecurityStore(this._meta);

  static const String _pinSalt = 'security.pin_salt';
  static const String _pinHash = 'security.pin_hash';
  static const String _recoveryHash = 'security.recovery_hash';
  static const String _failedAttempts = 'security.failed_attempts';
  static const String _lockoutUntil = 'security.lockout_until';

  final LocalMetaStore _meta;

  Future<PinHash?> readPin() async {
    final salt = await _meta.get(_pinSalt);
    final hash = await _meta.get(_pinHash);
    if (salt == null || hash == null) return null;
    return PinHash(salt: salt, hash: hash);
  }

  Future<void> writePin(PinHash pin) async {
    await _meta.set(_pinSalt, pin.salt);
    await _meta.set(_pinHash, pin.hash);
  }

  Future<String?> readRecoveryHash() => _meta.get(_recoveryHash);

  Future<void> writeRecoveryHash(String hash) => _meta.set(_recoveryHash, hash);

  Future<int> readFailedAttempts() async =>
      int.tryParse(await _meta.get(_failedAttempts) ?? '') ?? 0;

  Future<void> writeFailedAttempts(int count) =>
      _meta.set(_failedAttempts, '$count');

  Future<DateTime?> readLockoutUntil() async {
    final millis = int.tryParse(await _meta.get(_lockoutUntil) ?? '');
    return millis == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
  }

  Future<void> writeLockoutUntil(DateTime? until) => until == null
      ? _meta.remove(_lockoutUntil)
      : _meta.set(_lockoutUntil, '${until.toUtc().millisecondsSinceEpoch}');
}
