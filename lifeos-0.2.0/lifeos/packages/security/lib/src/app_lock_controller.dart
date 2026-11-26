import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'pin_hasher.dart';
import 'recovery_code.dart';
import 'security_store.dart';

/// Zustand der App-Sperre.
enum LockState { loading, needsSetup, locked, unlocked }

/// Ergebnis eines Entsperrversuchs.
sealed class UnlockResult {
  const UnlockResult();
}

class UnlockSuccess extends UnlockResult {
  const UnlockSuccess();
}

class UnlockWrongPin extends UnlockResult {
  const UnlockWrongPin(this.failedAttempts, this.retryAfter);

  final int failedAttempts;

  /// Ab wann der nächste Versuch möglich ist, `null` = sofort.
  final DateTime? retryAfter;
}

class UnlockBlocked extends UnlockResult {
  const UnlockBlocked(this.retryAfter);

  final DateTime retryAfter;
}

/// Wird in `main()` mit der echten Instanz überschrieben.
final appLockControllerProvider = Provider<AppLockController>(
  (ref) => throw UnimplementedError(
    'appLockControllerProvider muss in main() überschrieben werden.',
  ),
);

/// Steuert PIN-Einrichtung, Entsperren, automatische Sperre und Reset.
///
/// Ablauf bei Einrichtung und Reset: Nach [setupPin] bzw.
/// [resetWithRecoveryCode] steht der neue Code in [pendingRecoveryCode].
/// Erst [confirmRecoveryCodeSaved] entsperrt die App. So sieht man den Code
/// garantiert, bevor es weitergeht.
class AppLockController extends ChangeNotifier {
  AppLockController({
    required SecurityStore store,
    PinHasher hasher = const PinHasher(),
    this.timeout = const Duration(minutes: 10),
    DateTime Function()? now,
  })  : _store = store,
        _hasher = hasher,
        _now = now ?? DateTime.now;

  /// Fehlversuche ohne Wartezeit.
  static const int freeAttempts = 4;

  /// Wartezeit beim ersten gesperrten Versuch, danach verdoppelt.
  static const Duration baseLockout = Duration(seconds: 30);

  /// Obergrenze der Wartezeit.
  static const Duration maxLockout = Duration(hours: 1);

  final SecurityStore _store;
  final PinHasher _hasher;
  final DateTime Function() _now;

  /// Sperre nach dieser Zeit ohne Eingabe.
  final Duration timeout;

  LockState _state = LockState.loading;
  String? _pendingRecoveryCode;
  DateTime _lastActivity = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  Timer? _ticker;

  LockState get state => _state;

  /// Neuer Wiederherstellungscode, der noch bestätigt werden muss.
  String? get pendingRecoveryCode => _pendingRecoveryCode;

  /// Liest den gespeicherten Zustand und startet die Inaktivitätsprüfung.
  Future<void> init() async {
    final pin = await _store.readPin();
    _setState(pin == null ? LockState.needsSetup : LockState.locked);
    _ticker ??= Timer.periodic(const Duration(seconds: 15), (_) => checkInactivity());
  }

  /// Legt die erste PIN fest und erzeugt den Wiederherstellungscode.
  Future<String> setupPin(String pin) async {
    _requireValidPin(pin);
    await _store.writePin(await _hasher.hash(pin));
    await _clearFailures();
    final code = await _issueRecoveryCode();
    _pendingRecoveryCode = code;
    notifyListeners();
    return code;
  }

  /// Der Nutzer hat den neuen Code gesichert. Danach ist die App entsperrt.
  void confirmRecoveryCodeSaved() {
    _pendingRecoveryCode = null;
    _lastActivity = _now();
    _setState(LockState.unlocked);
  }

  Future<UnlockResult> unlock(String pin) async {
    final now = _now();
    final blockedUntil = await _store.readLockoutUntil();
    if (blockedUntil != null && now.isBefore(blockedUntil)) {
      return UnlockBlocked(blockedUntil);
    }

    final stored = await _store.readPin();
    if (stored == null) {
      _setState(LockState.needsSetup);
      return const UnlockWrongPin(0, null);
    }

    if (await _hasher.verify(pin, stored)) {
      await _clearFailures();
      _lastActivity = _now();
      _setState(LockState.unlocked);
      return const UnlockSuccess();
    }

    final failed = await _store.readFailedAttempts() + 1;
    await _store.writeFailedAttempts(failed);
    final wait = lockoutFor(failed);
    final retryAfter = wait == Duration.zero ? null : now.add(wait);
    await _store.writeLockoutUntil(retryAfter);
    return UnlockWrongPin(failed, retryAfter);
  }

  /// Wartezeit nach [failedAttempts] Fehlversuchen: ab dem 5. Versuch
  /// 30 Sekunden, danach jeweils doppelt so lang, höchstens 1 Stunde.
  static Duration lockoutFor(int failedAttempts) {
    final exponent = failedAttempts - freeAttempts - 1;
    if (exponent < 0) return Duration.zero;
    final seconds = baseLockout.inSeconds * math.pow(2, math.min(exponent, 16));
    return Duration(seconds: math.min(seconds.toInt(), maxLockout.inSeconds));
  }

  /// Setzt die PIN mit dem Wiederherstellungscode zurück.
  ///
  /// Gibt den neuen Code zurück oder `null`, wenn der Code nicht passt.
  Future<String?> resetWithRecoveryCode(String code, String newPin) async {
    _requireValidPin(newPin);
    final normalized = RecoveryCode.normalize(code);
    final storedHash = await _store.readRecoveryHash();
    if (normalized == null || storedHash == null) return null;
    if (!constantTimeEquals(await _sha256(normalized), base64Decode(storedHash))) {
      return null;
    }
    await _store.writePin(await _hasher.hash(newPin));
    await _clearFailures();
    final next = await _issueRecoveryCode();
    _pendingRecoveryCode = next;
    notifyListeners();
    return next;
  }

  /// Ersetzt den Wiederherstellungscode. Nur im entsperrten Zustand.
  Future<String> regenerateRecoveryCode() async {
    if (_state != LockState.unlocked) {
      throw StateError('Nur im entsperrten Zustand möglich.');
    }
    return _issueRecoveryCode();
  }

  /// Bei jeder Eingabe aufrufen (Tippen, Klicken, Tastatur).
  void registerActivity() {
    if (_state == LockState.unlocked) _lastActivity = _now();
  }

  /// Sperrt, wenn seit der letzten Eingabe [timeout] vergangen ist.
  void checkInactivity() {
    if (_state == LockState.unlocked && _now().difference(_lastActivity) >= timeout) {
      lockNow();
    }
  }

  /// Beim Zurückkehren aus dem Hintergrund aufrufen.
  void onForeground() => checkInactivity();

  void lockNow() {
    if (_state == LockState.unlocked) _setState(LockState.locked);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<String> _issueRecoveryCode() async {
    final code = RecoveryCode.generate();
    final hash = await _sha256(RecoveryCode.normalize(code)!);
    await _store.writeRecoveryHash(base64Encode(hash));
    return code;
  }

  Future<void> _clearFailures() async {
    await _store.writeFailedAttempts(0);
    await _store.writeLockoutUntil(null);
  }

  static Future<List<int>> _sha256(String value) async =>
      (await Sha256().hash(utf8.encode(value))).bytes;

  static void _requireValidPin(String pin) {
    if (!PinHasher.isValidPin(pin)) {
      throw ArgumentError('Die PIN muss aus 6 bis 12 Ziffern bestehen.');
    }
  }

  void _setState(LockState next) {
    if (_state == next) return;
    _state = next;
    notifyListeners();
  }
}
